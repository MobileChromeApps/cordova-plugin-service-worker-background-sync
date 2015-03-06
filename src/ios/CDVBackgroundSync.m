/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import <Cordova/CDV.h>
#import "CDVBackgroundSync.h"
#import "Reachability.h"
#import <JavaScriptCore/JavaScriptCore.h>

NSString * const REGISTRATION_LIST_STORAGE_KEY = @"CDVBackgroundSync_registrationList";
NSString * const REGISTRATION_LIST_MIN_STORAGE_KEY = @"CDVBackgroundSync_registrationListMin";
const NSInteger MAX_BATCH_WAIT_TIME = 1000*60*30;

UIBackgroundFetchResult fetchResult = UIBackgroundFetchResultNoData;

NSNumber *min;
NSNumber *dispatchedSyncs;
NSNumber *completedSyncs;

@implementation CDVBackgroundSync

@synthesize syncCheckCallback;
@synthesize completionHandler;
@synthesize serviceWorker;
@synthesize registrationList;

-(void)restoreRegistrations
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *restored = [[defaults objectForKey:REGISTRATION_LIST_STORAGE_KEY] mutableCopy];
    if (restored != nil) {
        registrationList = restored;
    }
    NSNumber *restoredMin = [defaults objectForKey:REGISTRATION_LIST_MIN_STORAGE_KEY];
    if (restoredMin != nil) {
        min = restoredMin;
    }
}

- (void)initBackgroundSync:(CDVInvokedUrlCommand*)command
{
    //TODO: Find a better place to run this setup
    [self syncResponseSetup];
    [self unregisterSetup];
    [self networkCheckSetup];
    
    self.syncCheckCallback = command.callbackId;
    NSLog(@"register %@", syncCheckCallback);
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [result setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:result callbackId:syncCheckCallback];
}

- (void)register:(CDVInvokedUrlCommand*)command
{
    if (registrationList == nil) {
        registrationList = [NSMutableDictionary dictionaryWithObject:[command argumentAtIndex:0] forKey:[[command argumentAtIndex:0] objectForKey:@"id"]];
    } else {
        [registrationList setObject:[command argumentAtIndex:0] forKey:[[command argumentAtIndex:0] objectForKey:@"id"]];
    }
    NSLog(@"Registering %@", [[command argumentAtIndex:0] objectForKey:@"id"]);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        //Recalculate min
        [self setMin];
        
        //Save the list
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
        [defaults synchronize];
    });
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)checkUniqueId:(CDVInvokedUrlCommand*)command
{
    NSString* regId = [command argumentAtIndex:0];
    if ([registrationList objectForKey:regId] == nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"This ID has already been registered."];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)checkIfIdle:(CDVInvokedUrlCommand*)command
{
    if (completionHandler != nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"notIdle"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)getRegistrations:(CDVInvokedUrlCommand*)command
{
    // If we have pre-existing registrations, give them to the javascript side
    if (registrationList != nil && [registrationList count] != 0) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:[registrationList allValues]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No Preexisting Registrations"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)unregisterSetup
{
    //create weak reference to self in order to prevent retain cycle in block
    __weak CDVBackgroundSync* weakSelf = self;
    
    // Set up service worker unregister event
    serviceWorker.context[@"unregisterSync"] = ^(JSValue *registrationId) {
        [weakSelf unregisterSyncById:[registrationId toString]];
    };
}

- (void)unregister:(CDVInvokedUrlCommand*)command
{
    [self unregisterSyncById:[command argumentAtIndex:0]];
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)unregisterSyncById:(NSString*)id
{
    if ([registrationList objectForKey:id]) {
        NSLog(@"Unregistering %@", id);
        [registrationList removeObjectForKey:id];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            //Recalculate min
            [self setMin];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
            [defaults synchronize];
        });
    } else {
        NSLog(@"Could not find %@ to unregister", id);
    }
}

- (void)markNoDataCompletion:(CDVInvokedUrlCommand*)command
{
    if (completionHandler != nil) {
        completionHandler(UIBackgroundFetchResultNoData);
    }
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)syncResponseSetup
{
    //create weak reference to self in order to prevent retain cycle in block
    __weak CDVBackgroundSync* weakSelf = self;
    
    //Indicate to OS success or failure and unregister syncs that have been successfully executed and are not periodic
    serviceWorker.context[@"sendSyncResponse"] = ^(JSValue *responseType, JSValue *regId) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
            if (completedSyncs == nil) {
                completedSyncs = [NSNumber numberWithInteger:0];
            }
            completedSyncs = @(completedSyncs.integerValue + 1);

            //Response Type: 0 = New Data, 1 = No Data, 2 = Failed to Fetch
            if ([responseType toInt32] == 0) {
                if (fetchResult != UIBackgroundFetchResultFailed) {
                    fetchResult = UIBackgroundFetchResultNewData;
                }
                NSNumber* minPeriod = [[weakSelf.registrationList objectForKey:[regId toString]] valueForKey:@"minPeriod"];
                if (minPeriod.integerValue == 0) {
                    [weakSelf unregisterSyncById:[regId toString]];
                } else {
                    NSMutableDictionary *registration = [[[NSMutableDictionary alloc] initWithDictionary:[weakSelf.registrationList objectForKey:[regId toString]]] mutableCopy];
                    NSLog(@"Reregistering %@", [registration valueForKey:@"id"]);
                    NSNumber *minPeriod = [[weakSelf.registrationList objectForKey:[regId toString]] valueForKey:@"minPeriod"];
                    // If the event is periodic, then replace its minDelay with its minPeriod and reTimestamp it
                    [registration setValue:minPeriod forKey:@"minDelay"];
                    NSNumber *time = [NSNumber numberWithDouble:[NSDate date].timeIntervalSince1970];
                    time = @(time.doubleValue * 1000);
                    [registration setValue:time forKey:@"time"];

                    // Add replace the old registration with the updated one
                    [weakSelf.registrationList setObject:registration forKey:[regId toString]];
                    //Recalculate min
                    [weakSelf setMin];
                    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                    [defaults setObject:weakSelf.registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
                    [defaults synchronize];
                }
            } else if ([responseType toInt32] == 1) {
                NSLog(@"Got no data");
            } else if ([responseType toInt32] == 2) {
                NSLog(@"Failed to get data");
                fetchResult = UIBackgroundFetchResultFailed;

                //Create a backoff by re-time stamping the registration
                NSNumber *time = [NSNumber numberWithDouble:[NSDate date].timeIntervalSince1970];
                time = @(time.doubleValue * 1000);
                [[weakSelf.registrationList objectForKey:[regId toString]] setValue:time forKey:@"time"];
                // Recalculate min
                [weakSelf setMin];
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:weakSelf.registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
                [defaults synchronize];
            }
            
            // Make sure we received all the syncs before determining completion
            if (completedSyncs.integerValue == dispatchedSyncs.integerValue) {
                if (weakSelf.completionHandler != nil) {
                    NSLog(@"Executing Completion Handler");
                    weakSelf.completionHandler(fetchResult);
                    weakSelf.completionHandler = nil;
                }

                // Reset the sync count
                completedSyncs = [NSNumber numberWithInteger:0];
                dispatchedSyncs = [NSNumber numberWithInteger:0];
                fetchResult = UIBackgroundFetchResultNoData;
            }
        });
    };
}

- (void)networkCheckSetup
{
    Reachability* reach = [Reachability reachabilityForInternetConnection];
    reach.reachableBlock = ^(Reachability*reach)
    {
        NSLog(@"Regained network");
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"notIdle"];
        [result setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:result callbackId:syncCheckCallback];
    };
    reach.unreachableBlock = ^(Reachability*reach) {
        NSLog(@"Lost Connection");
    };
    [reach startNotifier];
}

- (void)fetchNewDataWithCompletionHandler:(Completion)handler
{
    NSLog(@"Fetching");
    self.completionHandler = handler;
    if (self.syncCheckCallback) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"idle"];
        [result setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:result callbackId:syncCheckCallback];
    }
}

- (void)dispatchSyncEvent:(CDVInvokedUrlCommand*)command
{
    //Increment the counter of dispatched syncs
    if (dispatchedSyncs == nil) {
        dispatchedSyncs = [NSNumber numberWithInteger:0];
    }
    dispatchedSyncs = @(dispatchedSyncs.integerValue + 1);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        //[[self.serviceWorker context] evaluateScript:@"dispatchEvent(new ExtendableEvent('sync'));"];
        NSString *message = [command argumentAtIndex:0];
        
        // If we need all of the object properties
        NSError *error;
        NSData *json = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
        NSString *dispatchCode = [NSString stringWithFormat:@"FireSyncEvent(JSON.parse('%@'));", [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
        [serviceWorker.context evaluateScript:dispatchCode];
    });
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)getNetworkAndBatteryStatus:(CDVInvokedUrlCommand*)command
{
    NetworkStatus networkStatus = [self getNetworkStatus];
    BOOL isCharging = [self isCharging];
    NSArray *toReturn = [NSArray arrayWithObjects:@(networkStatus),@(isCharging),nil];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:toReturn];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (NetworkStatus)getNetworkStatus
{
    Reachability* reach = [Reachability reachabilityForInternetConnection];
    [reach startNotifier];
    return [reach currentReachabilityStatus];
}

- (BOOL)isCharging
{
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    if ([[UIDevice currentDevice] batteryState] == UIDeviceBatteryStateCharging) {
        return YES;
    }
    return NO;
}

- (void)getBestForegroundSyncTime:(CDVInvokedUrlCommand*)command
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSArray* registrations = [registrationList allValues];
        NSNumber *latestTime;
        NSNumber *bestTime = 0;
        NSNumber *time;
        NSNumber *maxDelay;
        NSNumber *minDelay;
        NSDictionary *registration;
        BOOL haveMax = NO;
        if (registrations.count == 0) {
            NSLog(@"No Registrations to Schedule");
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No Registrations to Schedule"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            return;
        }
        // Get the latest time without having a sync registration expire
        for (registration in registrations) {
            time = [registration valueForKey:@"time"];
            maxDelay = [registration valueForKey:@"maxDelay"];
            if ((((time.integerValue + maxDelay.integerValue) < latestTime.integerValue) || latestTime == nil) && (maxDelay.integerValue != 0)) {
                haveMax = YES;
                latestTime = @(time.integerValue + maxDelay.integerValue);
            }
        }
        // If a sync is scheduled for as soon as the app launches, this method may run before min is restored, a null min causes an exception
        // TODO: solve this race condition
        [self setMin];

        // Find the time at which we have met the maximum min delays without exceding latestTime
        for (registration in registrations) {
            time = [registration valueForKey:@"time"];
            minDelay = [registration valueForKey:@"minDelay"];
            if ((!haveMax || (time.integerValue + minDelay.integerValue < latestTime.integerValue)) && time.integerValue + minDelay.integerValue > bestTime.integerValue) {
                //Ensure no super long wait due to outliers by only including times within the threshold from the current minimum
                if ((time.integerValue + minDelay.integerValue - min.integerValue) <= MAX_BATCH_WAIT_TIME) {
                    //Also ensure we're not taking into account registrations that require internet when we are not connected, or are not allowed on battery when we are not charging
                    NSNumber *minRequiredNetwork = [registration valueForKey:@"minRequiredNetwork"];
                    BOOL allowOnBattery = [registration valueForKey:@"allowOnBattery"];
                    if ([self getNetworkStatus] >= minRequiredNetwork.integerValue && (allowOnBattery || [self isCharging])) {
                        bestTime = @(time.integerValue + minDelay.integerValue);
                    }
                }
            }
        }
        if (bestTime == 0) {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No viable registration to schedule"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:[bestTime integerValue]];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        }
    });
}

-(void)setMin
{
    if ([registrationList count] == 0) {
        min = nil;
        return;
    }
    NSArray *registrations = [[registrationList allValues] copy];
    NSDictionary *registration;
    NSNumber *time = [registrations[0] valueForKey:@"time"];
    NSNumber *minDelay = [registrations[0] valueForKey:@"minDelay"];
    NSNumber *tempMin = @(time.integerValue + minDelay.integerValue);
    for (registration in registrations) {
        time = [registration valueForKey:@"time"];
        minDelay = [registration valueForKey:@"minDelay"];
        if ((time.integerValue + minDelay.integerValue) < tempMin.integerValue) {
            tempMin = @(time.integerValue + minDelay.integerValue);
        }
    }
    min = @(tempMin.integerValue);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:min forKey:REGISTRATION_LIST_MIN_STORAGE_KEY];
    [defaults synchronize];
}
@end

