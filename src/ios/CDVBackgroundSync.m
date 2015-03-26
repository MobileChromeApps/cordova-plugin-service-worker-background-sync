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
#import <objc/runtime.h>

NSString * REGISTRATION_LIST_STORAGE_KEY;
const NSInteger MAX_BATCH_WAIT_TIME = 1000*60*30;

UIBackgroundFetchResult fetchResult = UIBackgroundFetchResultNoData;

NSNumber *dispatchedSyncs;
NSNumber *completedSyncs;

CDVBackgroundSync *backgroundSync;

@implementation CDVBackgroundSync

@synthesize syncCheckCallback; //Success: Initiate sync check, Failure: scheduleForegroundSync
@synthesize completionHandler;
@synthesize serviceWorker;
@synthesize registrationList;

-(void)restoreRegistrations
{
    REGISTRATION_LIST_STORAGE_KEY = [NSString stringWithFormat:@"%@/%@", @"CDVBackgroundSync_registrationList_", [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"]];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *restored = [[defaults objectForKey:REGISTRATION_LIST_STORAGE_KEY] mutableCopy];
    if (restored != nil) {
        registrationList = restored;
    }
}

- (void)pluginInitialize
{
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    [self restoreRegistrations];
    self.serviceWorker = [(CDVViewController*)self.viewController getCommandInstance:@"ServiceWorker"];
    [self syncResponseSetup];
    [self unregisterSetup];
    [self networkCheckSetup];
    [self initBackgroundFetchHandler];
    [self setupServiceWorkerRegister];
    [self setupServiceWorkerGetRegistrations];
}

- (void)initBackgroundFetchHandler
{
    backgroundSync = self;
    if ([[[UIApplication sharedApplication] delegate] respondsToSelector:@selector(application:performFetchWithCompletionHandler:)]) {
        Method original, swizzled;
        original = class_getInstanceMethod([self class], @selector(application:performFetchWithCompletionHandler:));
        swizzled = class_getInstanceMethod([[[UIApplication sharedApplication] delegate] class], @selector(application:performFetchWithCompletionHandler:));
        method_exchangeImplementations(original, swizzled);
    } else {
        class_addMethod([[[UIApplication sharedApplication] delegate] class], @selector(application:performFetchWithCompletionHandler:), class_getMethodImplementation([self class], @selector(application:performFetchWithCompletionHandler:)), nil);
    }
}

- (void)initBackgroundSync:(CDVInvokedUrlCommand*)command
{
    self.syncCheckCallback = command.callbackId;
    CDVPluginResult *result;
    if ([registrationList count] == 0) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    } else {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"notIdle"];
    }
    [result setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:result callbackId:syncCheckCallback];
}

- (void)validateId:(NSString**)regId
{
    //Take null id and turn into empty string
    if (*regId == (id)[NSNull null] || *regId == nil || [*regId isEqualToString:@"undefined"]) {
        *regId = @"";
    }
}

- (void)cordovaRegister:(CDVInvokedUrlCommand*)command
{
    [self register:[command argumentAtIndex:0]];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)setupServiceWorkerRegister
{
    __weak CDVBackgroundSync* weakSelf = self;
    serviceWorker.context[@"CDVBackgroundSync_register"] = ^(JSValue *registration, JSValue *callback) {
        [weakSelf register:registration.toDictionary];
        [callback callWithArguments:nil];
    };
    serviceWorker.context[@"CDVBackgroundSync_getBestForegroundSyncTime"] = ^() {
        [weakSelf getBestForegroundSyncTime:nil];
    };
}

- (void)register:(NSDictionary *)syncRegistration
{
    NSString *regId = [syncRegistration objectForKey:@"id"];
    [self validateId:&regId];
    [self unregisterSyncById: regId];
    if (registrationList == nil) {
        registrationList = [NSMutableDictionary dictionaryWithObject:syncRegistration forKey:regId];
    } else {
        [registrationList setObject:syncRegistration forKey:regId];
    }
    NSLog(@"Registering %@", regId);
    //Save the list
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
    [defaults synchronize];
}

- (void)getRegistrations:(CDVInvokedUrlCommand*)command
{
    if (registrationList != nil && [registrationList count] != 0) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:[registrationList allValues]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No Preexisting Registrations"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)setupServiceWorkerGetRegistrations
{
    __weak CDVBackgroundSync* weakSelf = self;
    serviceWorker.context[@"CDVBackgroundSync_getRegistrations"] = ^(JSValue *successCallback, JSValue *failureCallback) {
        if (weakSelf.registrationList != nil && [weakSelf.registrationList count] != 0) {
            [successCallback callWithArguments:[NSArray arrayWithObject:[weakSelf.registrationList allValues]]];
        } else {
            [failureCallback callWithArguments:[NSArray arrayWithObject:@"No Registrations"]];
        }
    };
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

- (void)getRegistration:(CDVInvokedUrlCommand*)command
{
    NSString *id = [command argumentAtIndex:0];
    if (registrationList != nil && [registrationList count] != 0) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:[registrationList objectForKey:id]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No Preexisting Registrations"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)unregisterSetup
{
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
    [self validateId:&id];
    if ([registrationList objectForKey:id]) {
        NSLog(@"Unregistering %@", id);
        [registrationList removeObjectForKey:id];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
        [defaults synchronize];
    } else {
        NSLog(@"Could not find %@ to unregister", id);
    }
}

- (void)markNoDataCompletion:(CDVInvokedUrlCommand*)command
{
    if (completionHandler != nil) {
        NSLog(@"Executing No Data Completion Handler");
        completionHandler(UIBackgroundFetchResultNoData);
        completionHandler = nil;
    }
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)syncResponseSetup
{
    //create weak reference to self in order to prevent retain cycle in block
    __weak CDVBackgroundSync* weakSelf = self;
    
    //Indicate to OS success or failure and unregister syncs that have been successfully executed and are not periodic
    serviceWorker.context[@"sendSyncResponse"] = ^(JSValue *responseType, JSValue *rId) {
        NSString *regId = rId.toString;
        [weakSelf validateId:&regId];
        if (completedSyncs == nil) {
            completedSyncs = [NSNumber numberWithInteger:0];
        }
        completedSyncs = @(completedSyncs.integerValue + 1);
        
        //Response Type: 0 = New Data, 1 = No Data, 2 = Failed to Fetch
        if ([responseType toInt32] == 0) {
            if (fetchResult != UIBackgroundFetchResultFailed) {
                fetchResult = UIBackgroundFetchResultNewData;
            }
            NSNumber* minPeriod = [[weakSelf.registrationList objectForKey:regId] valueForKey:@"minPeriod"];
            if (minPeriod.integerValue == 0) {
                [weakSelf unregisterSyncById:regId];
            } else {
                NSMutableDictionary *registration = [[[NSMutableDictionary alloc] initWithDictionary:[weakSelf.registrationList objectForKey:regId]] mutableCopy];
                NSLog(@"Reregistering %@", regId);
                NSNumber *minPeriod = [[weakSelf.registrationList objectForKey:regId] valueForKey:@"minPeriod"];
                // If the event is periodic, then replace its minDelay with its minPeriod and reTimestamp it
                [registration setValue:minPeriod forKey:@"minDelay"];
                NSNumber *time = [NSNumber numberWithDouble:[NSDate date].timeIntervalSince1970];
                time = @(time.doubleValue * 1000);
                [registration setValue:time forKey:@"time"];
                
                // Add replace the old registration with the updated one
                [weakSelf.registrationList setObject:registration forKey:regId];
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:weakSelf.registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
                [defaults synchronize];
            }
        } else {
            //Create a backoff by re-time stamping the registration
            NSLog(@"Pushing Back");
            NSNumber *time = [NSNumber numberWithDouble:[NSDate date].timeIntervalSince1970];
            time = @(time.doubleValue * 1000);
            [[weakSelf.registrationList objectForKey:regId] setValue:time forKey:@"time"];
            NSNumber *minDelay = [[weakSelf.registrationList objectForKey:regId] valueForKey:@"minDelay"];
            if (minDelay.doubleValue < 5000) {
                minDelay = [NSNumber numberWithDouble:5000];
            }
            minDelay = @(minDelay.doubleValue * 2);
            [[weakSelf.registrationList objectForKey:regId] setValue:minDelay forKey:@"minDelay"];
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:weakSelf.registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
            [defaults synchronize];
            if ([responseType toInt32] == 2) {
                NSLog(@"Failed to get data");
                fetchResult = UIBackgroundFetchResultFailed;
            }
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
            [weakSelf getBestForegroundSyncTime:nil];
        }
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

- (void)application:(UIApplication*)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    [backgroundSync fetchNewDataWithCompletionHandler:completionHandler];
}

- (void)dispatchSyncEvent:(CDVInvokedUrlCommand*)command
{
    //Increment the counter of dispatched syncs
    if (dispatchedSyncs == nil) {
        dispatchedSyncs = [NSNumber numberWithInteger:0];
    }
    dispatchedSyncs = @(dispatchedSyncs.integerValue + 1);
    
    NSString *message = [command argumentAtIndex:0];
    
    // If we need all of the object properties
    NSError *error;
    NSData *json = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
    NSString *dispatchCode = [NSString stringWithFormat:@"FireSyncEvent(JSON.parse('%@'));", [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
    [serviceWorker.context performSelectorOnMainThread:@selector(evaluateScript:) withObject:dispatchCode waitUntilDone:NO];
    
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
        NSNumber *bestTime = [NSNumber numberWithInt:0];
        NSNumber *time;
        NSNumber *maxDelay;
        NSNumber *minDelay;
        NSNumber *min;
        NSDictionary *registration;
        BOOL haveMax = NO;
        if (registrations.count == 0) {
            NSLog(@"No Registrations to Schedule");
            if (command != nil) {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No Registrations to Schedule"];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }
            return;
        }
        // Get the latest time without having a sync registration expire , also get minimum registration dispatch time
        for (registration in registrations) {
            NSNumber *minRequiredNetwork = [registration valueForKey:@"minRequiredNetwork"];
            NSNumber *allowOnBattery = [registration valueForKey:@"allowOnBattery"];
            NSNumber *idleRequired = [registration valueForKey:@"idleRequired"];
            if ([self getNetworkStatus] >= minRequiredNetwork.integerValue && (allowOnBattery.intValue || [self isCharging]) && !idleRequired.intValue) {
                time = [registration valueForKey:@"time"];
                maxDelay = [registration valueForKey:@"maxDelay"];
                minDelay = [registration valueForKey:@"minDelay"];
                if ((((time.integerValue + maxDelay.integerValue) < latestTime.integerValue) || latestTime == nil) && (maxDelay.integerValue != 0)) {
                    haveMax = YES;
                    latestTime = @(time.integerValue + maxDelay.integerValue);
                }
                if (min == nil || time.integerValue + minDelay.integerValue < min.integerValue) {
                    min = @(time.integerValue + minDelay.integerValue);
                }
            }
        }
        
        // Find the time at which we have met the maximum min delays without exceding latestTime
        for (registration in registrations) {
            NSNumber *minRequiredNetwork = [registration valueForKey:@"minRequiredNetwork"];
            NSNumber *allowOnBattery = [registration valueForKey:@"allowOnBattery"];
            NSNumber *idleRequired = [registration valueForKey:@"idleRequired"];
            if ([self getNetworkStatus] >= minRequiredNetwork.integerValue && (allowOnBattery.intValue || [self isCharging]) && !idleRequired.intValue) {
                time = [registration valueForKey:@"time"];
                minDelay = [registration valueForKey:@"minDelay"];
                if ((!haveMax || (time.integerValue + minDelay.integerValue < latestTime.integerValue)) && time.integerValue + minDelay.integerValue > bestTime.integerValue) {
                    //Ensure no super long wait due to outliers by only including times within the threshold from the current minimum
                    if ((time.integerValue + minDelay.integerValue - min.integerValue) <= MAX_BATCH_WAIT_TIME) {
                            bestTime = @(time.integerValue + minDelay.integerValue);
                    }
                }
            }
        }
        if (bestTime == 0) {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No viable registration to schedule"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        } else {
            if (command == nil) {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDouble:[bestTime integerValue]];
                [result setKeepCallback:[NSNumber numberWithBool:YES]];
                [self.commandDelegate sendPluginResult:result callbackId:syncCheckCallback];
            } else {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:[bestTime integerValue]];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }
        }
    });
}
@end

