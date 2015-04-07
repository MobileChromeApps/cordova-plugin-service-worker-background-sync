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
#import "CDVConnection.h"
#import <JavaScriptCore/JavaScriptCore.h>
#import <objc/runtime.h>
#import "CDVServiceWorker.h"

static NSString * REGISTRATION_LIST_STORAGE_KEY = @"CDVBackgroundSync_registrationList";
static const NSInteger MAX_BATCH_WAIT_TIME = 1000*60*30;

static UIBackgroundFetchResult fetchResult = UIBackgroundFetchResultNoData;

static NSInteger *dispatchedSyncs;
static NSInteger *completedSyncs;

@interface CDVBackgroundSync : CDVPlugin {}

typedef void(^Completion)(UIBackgroundFetchResult);

@property (nonatomic, copy) NSString *syncCheckCallback;
@property (nonatomic, copy) Completion completionHandler;
@property (nonatomic, strong) CDVServiceWorker *serviceWorker;
@property (nonatomic, strong) NSMutableDictionary *registrationList;
@end

static CDVBackgroundSync *backgroundSync;

@implementation CDVBackgroundSync

@synthesize syncCheckCallback; //Success: Initiate sync check, Failure: scheduleForegroundSync
@synthesize completionHandler;
@synthesize serviceWorker;
@synthesize registrationList;

-(void)restoreRegistrations
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *restored = [[defaults objectForKey:REGISTRATION_LIST_STORAGE_KEY] mutableCopy];
    if (restored != nil) {
        registrationList = restored;
        if ([registrationList count] != 0) {
            [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
        }
    }
}

- (void)pluginInitialize
{
    [self restoreRegistrations];
    self.serviceWorker = [self.commandDelegate getCommandInstance:@"ServiceWorker"];
    [self setupSyncResponse];
    [self setupUnregister];
    [self setupBackgroundFetchHandler];
    [self setupServiceWorkerRegister];
    [self setupServiceWorkerGetRegistrations];
    [self setupServiceWorkerGetRegistration];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkCheckCallback) name:kReachabilityChangedNotification object:nil];
}

- (void)setupBackgroundFetchHandler
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

- (void)setupBackgroundSync:(CDVInvokedUrlCommand*)command
{
    self.syncCheckCallback = command.callbackId;
    CDVPluginResult *result;
    if ([registrationList count] != 0) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"notIdle"];
        [result setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:result callbackId:syncCheckCallback];
    }
}

+ (void)validateId:(NSString**)regId
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
        [weakSelf register:[registration toDictionary]];
        [callback callWithArguments:nil];
    };
    serviceWorker.context[@"CDVBackgroundSync_getBestForegroundSyncTime"] = ^() {
        [weakSelf computeBestForegroundSyncTime:nil];
    };
}

- (void)register:(NSDictionary *)syncRegistration
{
    NSString *regId = syncRegistration[@"id"];
    [CDVBackgroundSync validateId:&regId];
    [self unregisterSyncById: regId];
    if (registrationList == nil) {
        registrationList = [NSMutableDictionary dictionaryWithObject:syncRegistration forKey:regId];
    } else {
        registrationList[regId] = syncRegistration;
    }
    NSLog(@"Registering %@", regId);
    //Save the list
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
}

- (void)getRegistrations:(CDVInvokedUrlCommand*)command
{
    if (registrationList == nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:@[]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:[registrationList allValues]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)setupServiceWorkerGetRegistrations
{
    __weak CDVBackgroundSync* weakSelf = self;
    serviceWorker.context[@"CDVBackgroundSync_getRegistrations"] = ^(JSValue *successCallback, JSValue *failureCallback) {
        if (weakSelf.registrationList != nil && [weakSelf.registrationList count] != 0) {
            [successCallback callWithArguments:@[[weakSelf.registrationList allValues]]];
        } else {
            [failureCallback callWithArguments:@[@"No Registrations"]];
        }
    };
}

- (void)callIfNotIdle:(CDVInvokedUrlCommand*)command
{
    if (completionHandler == nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"notIdle"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)getRegistration:(CDVInvokedUrlCommand*)command
{
    NSString *id = [command argumentAtIndex:0];
    if (registrationList[id]) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:registrationList[id]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"Could not find %@", id]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)setupServiceWorkerGetRegistration
{
    __weak CDVBackgroundSync* weakSelf = self;
    serviceWorker.context[@"CDVBackgroundSync_getRegistration"] = ^(JSValue *id, JSValue *successCallback, JSValue *failureCallback) {
        if (weakSelf.registrationList[[id toString]]) {
            [successCallback callWithArguments:@[weakSelf.registrationList[[id toString]]]];
        } else {
            [failureCallback callWithArguments:@[@"Could not find %@", [id toString]]];
        }
    };
}

- (void)setupUnregister
{
    __weak CDVBackgroundSync* weakSelf = self;
    
    // Set up service worker unregister event
    serviceWorker.context[@"CDVBackgroundSync_unregisterSync"] = ^(JSValue *registrationId) {
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
    [CDVBackgroundSync validateId:&id];
    if (registrationList[id]) {
        NSLog(@"Unregistering %@", id);
        [registrationList removeObjectForKey:id];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
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

- (void)setupSyncResponse
{
    //create weak reference to self in order to prevent retain cycle in block
    __weak CDVBackgroundSync* weakSelf = self;
    
    //Indicate to OS success or failure and unregister syncs that have been successfully executed and are not periodic
    serviceWorker.context[@"sendSyncResponse"] = ^(JSValue *responseType, JSValue *rId) {
        NSString *regId = [rId toString];
        [CDVBackgroundSync validateId:&regId];
        if (completedSyncs == nil) {
            completedSyncs = 0;
        }
        completedSyncs = completedSyncs + 1;
        
        //Response Type: 0 = New Data, 1 = No Data, 2 = Failed to Fetch
        if ([responseType toInt32] == 0) {
            if (fetchResult != UIBackgroundFetchResultFailed) {
                fetchResult = UIBackgroundFetchResultNewData;
            }
            NSNumber* minPeriod = weakSelf.registrationList[regId][@"minPeriod"];
            if (minPeriod.integerValue == 0) {
                [weakSelf unregisterSyncById:regId];
            } else {
                NSMutableDictionary *registration = [[[NSMutableDictionary alloc] initWithDictionary:weakSelf.registrationList[regId]] mutableCopy];
                NSLog(@"Reregistering %@", regId);
                NSNumber *minPeriod = weakSelf.registrationList[regId][@"minPeriod"];
                // If the event is periodic, then replace its minDelay with its minPeriod and reTimestamp it
                registration[@"minDelay"] = minPeriod;
                registration[@"time"] = @([NSDate date].timeIntervalSince1970 * 1000);
                
                // Add replace the old registration with the updated one
                weakSelf.registrationList[regId] = registration;
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:weakSelf.registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
            }
        } else {
            //Create a backoff by re-time stamping the registration
            NSLog(@"Pushing Back");
            NSNumber *time = @([NSNumber numberWithDouble:[NSDate date].timeIntervalSince1970].doubleValue * 1000);
            weakSelf.registrationList[regId][@"time"] = time;
            NSNumber *minDelay = weakSelf.registrationList[regId][@"minDelay"];
            if (minDelay.doubleValue < 5000) {
                minDelay = [NSNumber numberWithDouble:5000];
            }
            minDelay = @(minDelay.doubleValue * 2);
            weakSelf.registrationList[regId][@"minDelay"] = minDelay;
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:weakSelf.registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
            if ([responseType toInt32] == 2) {
                NSLog(@"Failed to get data");
                fetchResult = UIBackgroundFetchResultFailed;
            }
        }
        
        // Make sure we received all the syncs before determining completion
        if (completedSyncs == dispatchedSyncs) {
            if (weakSelf.completionHandler != nil) {
                NSLog(@"Executing Completion Handler");
                weakSelf.completionHandler(fetchResult);
                weakSelf.completionHandler = nil;
            }
            
            // Reset the sync count
            completedSyncs = 0;
            dispatchedSyncs = 0;
            fetchResult = UIBackgroundFetchResultNoData;
            [weakSelf computeBestForegroundSyncTime:nil];

            //If we have no more registrations left, turn off background fetch
            if ([weakSelf.registrationList count] == 0) {
                [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalNever];
            }
        }
    };
}

- (void)networkCheckCallback
{
    if ([self getNetworkStatus])
    {
        NSLog(@"Regained network");
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"notIdle"];
        [result setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:result callbackId:syncCheckCallback];
    } else {
        NSLog(@"Lost Connection");
    }
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
        dispatchedSyncs = 0;
    }
    dispatchedSyncs = dispatchedSyncs + 1;
    
    NSDictionary *message = [command argumentAtIndex:0];
    
    // If we need all of the object properties
    NSError *error;
    NSData *json = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
    NSString *dispatchCode = [NSString stringWithFormat:@"FireSyncEvent(%@);", [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
    [serviceWorker.context performSelectorOnMainThread:@selector(evaluateScript:) withObject:dispatchCode waitUntilDone:NO];
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)getNetworkAndBatteryStatus:(CDVInvokedUrlCommand*)command
{
    NSInteger networkStatus = [self getNetworkStatus];
    BOOL isCharging = [self isCharging];
    NSArray *toReturn = @[@(networkStatus),@(isCharging)];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:toReturn];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (NSInteger)getNetworkStatus
{
    CDVConnection *connection = [self.commandDelegate getCommandInstance:@"NetworkStatus"];
    if ([connection.connectionType isEqualToString:@"wifi"]) {
        return 2;
    } else if ([connection.connectionType isEqualToString:@"cellular"]) {
        return 1;
    } else {
        return 0;
    }
}

- (BOOL)isCharging
{
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    BOOL toReturn = [[UIDevice currentDevice] batteryState] == UIDeviceBatteryStateCharging;
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:NO];
    return toReturn;
}

- (void)hasPermission:(CDVInvokedUrlCommand*)command
{
    if ([[UIApplication sharedApplication] backgroundRefreshStatus] == UIBackgroundRefreshStatusAvailable) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"granted"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"denied"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)computeBestForegroundSyncTime:(CDVInvokedUrlCommand*)command
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        NSArray* registrations = [registrationList allValues];
        NSInteger latestTime = 0;
        NSInteger bestTime = 0;
        NSInteger time = 0;
        NSInteger maxDelay = 0;
        NSInteger minDelay = 0;
        NSInteger min = 0;
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
            NSInteger minRequiredNetwork = [registration[@"minRequiredNetwork"] integerValue];
            NSInteger allowOnBattery = [registration[@"allowOnBattery"] integerValue];
            NSInteger idleRequired = [registration[@"idleRequired"] integerValue];
            if ([self getNetworkStatus] >= minRequiredNetwork && (allowOnBattery || [self isCharging]) && !idleRequired) {
                time = [registration[@"time"] integerValue];
                maxDelay = [registration[@"maxDelay"] integerValue];
                minDelay = [registration[@"minDelay"] integerValue];
                if ((((time + maxDelay) < latestTime) || !latestTime) && maxDelay) {
                    haveMax = YES;
                    latestTime = time + maxDelay;
                }
                if (!min || ((time + minDelay) < min)) {
                    min = time + minDelay;
                }
            }
        }
        
        // Find the time at which we have met the maximum min delays without exceding latestTime
        for (registration in registrations) {
            NSInteger minRequiredNetwork = [registration[@"minRequiredNetwork"] integerValue];
            NSInteger allowOnBattery = [registration[@"allowOnBattery"] integerValue];
            NSInteger idleRequired = [registration[@"idleRequired"] integerValue];
            if ([self getNetworkStatus] >= minRequiredNetwork && (allowOnBattery || [self isCharging]) && !idleRequired) {
                time = [registration[@"time"] integerValue];
                minDelay = [registration[@"minDelay"] integerValue];
                if ((!haveMax || (time + minDelay < latestTime)) && ((time + minDelay) > bestTime)) {
                    //Ensure no super long wait due to outliers by only including times within the threshold from the current minimum
                    if ((time + minDelay - min) <= MAX_BATCH_WAIT_TIME) {
                            bestTime = time + minDelay;
                    }
                }
            }
        }
        if (!bestTime) {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No viable registration to schedule"];
            [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        } else {
            // Command is nil when getBestForegroundSyncTime is called from native after all dispatched sync events have been resolved
            if (command == nil) {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDouble:bestTime];
                [result setKeepCallback:[NSNumber numberWithBool:YES]];
                [self.commandDelegate sendPluginResult:result callbackId:syncCheckCallback];
            } else {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:bestTime];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }
        }
    });
}
@end

