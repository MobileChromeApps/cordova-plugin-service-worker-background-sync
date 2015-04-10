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
static NSString * PERIODIC_REGISTRATION_LIST_STORAGE_KEY = @"CDVBackgroundSync_periodicRegistrationList";
static const NSInteger MAX_BATCH_WAIT_TIME = 1000*60*30;

static UIBackgroundFetchResult fetchResult = UIBackgroundFetchResultNoData;

static NSInteger dispatchedSyncs = 0;
static NSInteger completedSyncs = 0;

@interface CDVBackgroundSync : CDVPlugin {}

typedef void(^Completion)(UIBackgroundFetchResult);

@property (nonatomic, copy) NSString *syncCheckCallback;
@property (nonatomic, copy) Completion completionHandler;
@property (nonatomic, strong) CDVServiceWorker *serviceWorker;
@property (nonatomic, strong) NSMutableDictionary *registrationList;
@property (nonatomic, strong) NSMutableDictionary *periodicRegistrationList;
@end

static CDVBackgroundSync *backgroundSync;

@implementation CDVBackgroundSync

@synthesize syncCheckCallback; //Success: Initiate sync check, Failure: scheduleForegroundSync
@synthesize completionHandler;
@synthesize serviceWorker;
@synthesize registrationList;
@synthesize periodicRegistrationList;

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
        [result setKeepCallback:@(YES)];
        [self.commandDelegate sendPluginResult:result callbackId:syncCheckCallback];
    }
}

+ (void)validateTag:(NSString**)tag
{
    //Take null id and turn into empty string
    if (*tag == (id)[NSNull null] || *tag == nil || [*tag isEqualToString:@"undefined"]) {
        *tag = @"";
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
}

- (void)register:(NSDictionary *)registration
{
    NSString *tag = registration[@"tag"];
    [CDVBackgroundSync validateTag:&tag];
    [self unregisterSyncByTag: tag];
    if (registrationList == nil) {
        registrationList = [NSMutableDictionary dictionaryWithObject:registration forKey:tag];
    } else {
        registrationList[tag] = registration;
    }
    NSLog(@"Registering %@", tag);
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
    serviceWorker.context[@"CDVBackgroundSync_getRegistrations"] = ^(JSValue *callback) {
        if (weakSelf.registrationList != nil && [weakSelf.registrationList count] != 0) {
            [callback callWithArguments:@[[weakSelf.registrationList allValues]]];
        } else {
            [callback callWithArguments:@[@[]]];
        }
    };
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
    serviceWorker.context[@"CDVBackgroundSync_getRegistration"] = ^(JSValue *tag, JSValue *successCallback, JSValue *failureCallback) {
        if (weakSelf.registrationList[[tag toString]]) {
            [successCallback callWithArguments:@[weakSelf.registrationList[[tag toString]]]];
        } else {
            [failureCallback callWithArguments:@[@"Could not find %@", [tag toString]]];
        }
    };
}

- (void)setupUnregister
{
    __weak CDVBackgroundSync* weakSelf = self;
    
    // Set up service worker unregister event
    serviceWorker.context[@"CDVBackgroundSync_unregisterSync"] = ^(JSValue *registrationId) {
        [weakSelf unregisterSyncByTag:[registrationId toString]];
    };
}

- (void)unregister:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[self unregisterSyncByTag:[command argumentAtIndex:0]]];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (BOOL)unregisterSyncByTag:(NSString*)tag
{
    [CDVBackgroundSync validateTag:&tag];
    if (registrationList[tag]) {
        NSLog(@"Unregistering %@", tag);
        [registrationList removeObjectForKey:tag];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
        return YES;
    } else {
        NSLog(@"Could not find %@ to unregister", tag);
        return NO;
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
    serviceWorker.context[@"sendSyncResponse"] = ^(JSValue *responseType, JSValue *jsTag) {
        NSString *tag = [jsTag toString];
        [CDVBackgroundSync validateTag:&tag];
        completedSyncs++;
        switch ([responseType toInt32]) {
            case 0:
                if (fetchResult != UIBackgroundFetchResultFailed) {
                    fetchResult = UIBackgroundFetchResultNewData;
                }
                [weakSelf unregisterSyncByTag:tag];
                break;
            case 2:
                NSLog(@"Failed to get data");
                fetchResult = UIBackgroundFetchResultFailed;
            default:
                //TODO: Create Pushback
                break;
        }
        
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
            
            //If we have no more registrations left, turn off background fetch
            if ([weakSelf.registrationList count] == 0) {
                [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalNever];
            }
        }

    };
}

- (void)setupPeriodicSyncResponse
{
    //create weak reference to self in order to prevent retain cycle in block
    __weak CDVBackgroundSync* weakSelf = self;
    
    //Indicate to OS success or failure and unregister syncs that have been successfully executed and are not periodic
    serviceWorker.context[@"sendSyncResponse"] = ^(JSValue *responseType, JSValue *jsTag) {
        NSString *tag = [jsTag toString];
        [CDVBackgroundSync validateTag:&tag];
        completedSyncs++;
        
        switch ([responseType toInt32]) {
            case 0:
                if (fetchResult != UIBackgroundFetchResultFailed) {
                    fetchResult = UIBackgroundFetchResultNewData;
                }
                //TODO: reschedule
                break;
            case 2:
                NSLog(@"Failed to get data");
                fetchResult = UIBackgroundFetchResultFailed;
            default:
                // TODO: Pushback
                break;
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
        // Dispatch all one off sync events
        [self dispatchSyncEvents];
    } else {
        NSLog(@"Lost Connection");
    }
}

- (void)fetchNewDataWithCompletionHandler:(Completion)handler
{
    // Force update reachability status because otherwise network status won't be updated when in background
    CDVConnection *connection = [self.commandDelegate getCommandInstance:@"NetworkStatus"];
    [connection performSelector:@selector(updateReachability:) withObject:connection.internetReach];
    // This should never happen, but just in case there are no registrations and a sync event is initiated
    if (![registrationList count] && ![periodicRegistrationList count]) {
        handler(UIBackgroundFetchResultNoData);
        return;
    }
    
    NSLog(@"Fetching");
    self.completionHandler = handler;
    if ([self getNetworkStatus]) {
        [self dispatchSyncEvents];
    } else {
        fetchResult = UIBackgroundFetchResultFailed;
    }
    [self evaluatePeriodicSyncEvents];
    
    // If there is no connection during a background fetch but there exist one off registrations
    if (![periodicRegistrationList count] && ![self getNetworkStatus]) {
        NSLog(@"Failed to sync");
        self.completionHandler(UIBackgroundFetchResultFailed);
        self.completionHandler = nil;
    }
}

- (void)application:(UIApplication*)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    [backgroundSync fetchNewDataWithCompletionHandler:completionHandler];
}

- (void)dispatchSyncEvents
{
    for (NSDictionary *registration in [registrationList allValues]) {
        //Increment the counter of dispatched syncs
        dispatchedSyncs++;
        
        // If we need all of the object properties
        NSError *error;
        NSData *json = [NSJSONSerialization dataWithJSONObject:registration options:0 error:&error];
        NSString *dispatchCode = [NSString stringWithFormat:@"FireSyncEvent(%@);", [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
        [serviceWorker.context performSelectorOnMainThread:@selector(evaluateScript:) withObject:dispatchCode waitUntilDone:NO];
    }
}

- (void)evaluatePeriodicSyncEvents
{
    
}

- (void)dispatchPeriodicSyncEvent:(NSDictionary *)registration
{
    //Increment the counter of dispatched syncs
    dispatchedSyncs++;
    
    // If we need all of the object properties
    NSError *error;
    NSData *json = [NSJSONSerialization dataWithJSONObject:registration options:0 error:&error];
    NSString *dispatchCode = [NSString stringWithFormat:@"FirePeriodicSyncEvent(%@);", [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
    [serviceWorker.context performSelectorOnMainThread:@selector(evaluateScript:) withObject:dispatchCode waitUntilDone:NO];
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
    // TODO: Recall connection updateReachability so that the connection status is updated when in background
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
                [result setKeepCallback:@(YES)];
                [self.commandDelegate sendPluginResult:result callbackId:syncCheckCallback];
            } else {
                CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:bestTime];
                [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
            }
        }
    });
}
@end

