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

static NSString * const MIN_POSSIBLE_PERIOD = @"minperiod";
static NSString * const PUSHBACK = @"syncpushback";
static NSString * const MAX_WAIT_TIME = @"syncmaxwaittime";
static NSString * const REGISTRATION_LIST_STORAGE_KEY = @"CDVBackgroundSync_registrationList";
static NSString * const PERIODIC_REGISTRATION_LIST_STORAGE_KEY = @"CDVBackgroundSync_periodicRegistrationList";

static UIBackgroundFetchResult fetchResult = UIBackgroundFetchResultNoData;

static NSInteger dispatchedSyncs = 0;
static NSInteger completedSyncs = 0;

static NSInteger minPossiblePeriod;
static NSInteger pushback; // Pushback set for 10 minutes
static NSInteger maxWaitTime;

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
    registrationList = [CDVBackgroundSync prepareStoredList:[defaults objectForKey:REGISTRATION_LIST_STORAGE_KEY]];
    periodicRegistrationList = [CDVBackgroundSync prepareStoredList:[defaults objectForKey:PERIODIC_REGISTRATION_LIST_STORAGE_KEY]];
    if ([periodicRegistrationList count] + [registrationList count]) {
        [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    }
    [self scheduleSync];
}

- (void)pluginInitialize
{
    [self restoreRegistrations];
    self.serviceWorker = [self.commandDelegate getCommandInstance:@"ServiceWorker"];
    [self setupSyncResponse];
    [self setupPeriodicSyncResponse];
    [self setupUnregister];
    [self setupBackgroundFetchHandler];
    [self setupServiceWorkerRegister];
    [self setupServiceWorkerGetRegistrations];
    [self setupServiceWorkerGetRegistration];
    //Get Min Possible Period setting
    minPossiblePeriod = [[[self commandDelegate] settings][MIN_POSSIBLE_PERIOD] integerValue];
    minPossiblePeriod = minPossiblePeriod > 1000 ? minPossiblePeriod : 1000*60*60; // If no minPossible period is given, set the default to one hour
    pushback = [[[self commandDelegate] settings][PUSHBACK] integerValue];
    pushback = pushback > 1000 ? pushback : 1000*60*5;
    maxWaitTime = [[[self commandDelegate] settings][MAX_WAIT_TIME] integerValue];
    maxWaitTime = maxWaitTime > 1000 ? maxWaitTime : 2*3600000;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkCheckCallback) name:kReachabilityChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateCallback) name:UIDeviceBatteryStateDidChangeNotification object:nil];
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
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
    if ([registrationList count]) {
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

+ (NSMutableDictionary*)prepareStoredList:(NSDictionary*)dictionary
{
    NSMutableDictionary *toPrepare = [NSMutableDictionary dictionaryWithDictionary:dictionary];
    NSMutableDictionary *prepared = [NSMutableDictionary dictionary];
    for (NSString *key in toPrepare) {
        prepared[key] = [toPrepare[key] mutableCopy];
    }
    return prepared;
}

- (void)getMinPossiblePeriod:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:minPossiblePeriod];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)cordovaRegister:(CDVInvokedUrlCommand*)command
{
    if ([[command argumentAtIndex:1] isEqualToString:@"periodic"] && [[command argumentAtIndex:0][@"minPeriod"] integerValue] < minPossiblePeriod) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid minPeriod"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }
    NSMutableDictionary *list = [[command argumentAtIndex:1] isEqualToString:@"periodic"] ? periodicRegistrationList : registrationList;
    [self register:[command argumentAtIndex:0] inList:&list];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)setupServiceWorkerRegister
{
    __weak CDVBackgroundSync* weakSelf = self;
    serviceWorker.context[@"CDVBackgroundSync_register"] = ^(JSValue *registration, JSValue *syncType, JSValue *successCallback, JSValue *failureCallback) {
        if ([[syncType toString] isEqualToString:@"periodic"] && [[registration toDictionary][@"minPeriod"] integerValue] < minPossiblePeriod) {
            [failureCallback callWithArguments:nil];
            return;
        }
        NSMutableDictionary *list = [[syncType toString] isEqualToString:@"periodic"] ? weakSelf.periodicRegistrationList : weakSelf.registrationList;
        [weakSelf register:[registration toDictionary] inList:&list];
        [successCallback callWithArguments:nil];
    };
}

- (void)register:(NSDictionary *)registration inList:(NSMutableDictionary**)list
{
    NSString *tag = registration[@"tag"];
    [CDVBackgroundSync validateTag:&tag];
    [self unregisterSyncByTag: tag fromRegistrationList:*list];
    (*list)[tag] = [NSMutableDictionary dictionaryWithDictionary:registration];
    NSLog(@"Registering %@", tag);
    //Save the list
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *storageKey = *list == registrationList ? REGISTRATION_LIST_STORAGE_KEY : PERIODIC_REGISTRATION_LIST_STORAGE_KEY;
    [defaults setObject:*list forKey:storageKey];
    [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    if (*list == registrationList && [self getNetworkStatus]) {
        [self fireSyncEventForRegistration:registration];
        return;
    }
    if (*list == periodicRegistrationList) {
        [self scheduleSync];
    }
}

- (void)getRegistrations:(CDVInvokedUrlCommand*)command
{
    NSMutableDictionary *list = [[command argumentAtIndex:0] isEqualToString:@"periodic"] ? periodicRegistrationList : registrationList;
    if (list == nil) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:@[]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:[list allValues]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)setupServiceWorkerGetRegistrations
{
    __weak CDVBackgroundSync* weakSelf = self;
    serviceWorker.context[@"CDVBackgroundSync_getRegistrations"] = ^(JSValue *syncType, JSValue *callback) {
        NSMutableDictionary *list = [[syncType toString] isEqualToString:@"periodic"] ? weakSelf.periodicRegistrationList : weakSelf.registrationList;
        if (list != nil && [list count]) {
            [callback callWithArguments:@[[list allValues]]];
        } else {
            [callback callWithArguments:@[@[]]];
        }
    };
}

- (void)getRegistration:(CDVInvokedUrlCommand*)command
{
    NSString *tag = [command argumentAtIndex:0];
    NSMutableDictionary *list = [[command argumentAtIndex:1] isEqualToString:@"periodic"] ? periodicRegistrationList : registrationList;
    if (list[tag]) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:list[tag]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[NSString stringWithFormat:@"Could not find %@", tag]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)setupServiceWorkerGetRegistration
{
    __weak CDVBackgroundSync* weakSelf = self;
    serviceWorker.context[@"CDVBackgroundSync_getRegistration"] = ^(JSValue *tag, JSValue* syncType, JSValue *successCallback, JSValue *failureCallback) {
        NSMutableDictionary *list = [[syncType toString] isEqualToString:@"periodic"] ? weakSelf.periodicRegistrationList : weakSelf.registrationList;
        if (list[[tag toString]]) {
            [successCallback callWithArguments:@[list[[tag toString]]]];
        } else {
            [failureCallback callWithArguments:@[@"Could not find %@", [tag toString]]];
        }
    };
}

- (void)setupUnregister
{
    __weak CDVBackgroundSync* weakSelf = self;
    
    // Set up service worker unregister event
    serviceWorker.context[@"CDVBackgroundSync_unregisterSync"] = ^(JSValue *tag, JSValue *syncType) {
        NSMutableDictionary *list = [[syncType toString] isEqualToString:@"periodic"] ? weakSelf.periodicRegistrationList : weakSelf.registrationList;
        [weakSelf unregisterSyncByTag:[tag toString] fromRegistrationList:list];

    };
}

- (void)unregister:(CDVInvokedUrlCommand*)command
{
    NSMutableDictionary *list = [[command argumentAtIndex:1] isEqualToString:@"periodic"] ? periodicRegistrationList : registrationList;
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[self unregisterSyncByTag:[command argumentAtIndex:0] fromRegistrationList:list]];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (BOOL)unregisterSyncByTag:(NSString*)tag fromRegistrationList:(NSMutableDictionary*)list
{
    [CDVBackgroundSync validateTag:&tag];
    if (list[tag]) {
        NSLog(@"Unregistering %@", tag);
        [list removeObjectForKey:tag];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *storageKey = list == registrationList ? REGISTRATION_LIST_STORAGE_KEY : PERIODIC_REGISTRATION_LIST_STORAGE_KEY;
        [defaults setObject:list forKey:storageKey];
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
                [weakSelf unregisterSyncByTag:tag fromRegistrationList:weakSelf.registrationList];
                break;
            case 2:
                NSLog(@"Failed to get data");
                fetchResult = UIBackgroundFetchResultFailed;
            default:
                // Push back the failed registration
                if (![weakSelf.periodicRegistrationList count]) {
                    [weakSelf performSelector:@selector(foregroundSync) withObject:nil afterDelay:pushback/1000];
                }
                break;
        }
        if (completedSyncs == dispatchedSyncs) {
            // Reset the sync count
            completedSyncs = 0;
            dispatchedSyncs = 0;
            fetchResult = UIBackgroundFetchResultNoData;
            
            //If we have no more registrations left, turn off background fetch
            if (![weakSelf.registrationList count] && ![weakSelf.periodicRegistrationList count]) {
                [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalNever];
            }
            if (weakSelf.completionHandler != nil) {
                NSLog(@"Executing Completion Handler");
                weakSelf.completionHandler(fetchResult);
                weakSelf.completionHandler = nil;
            }
        }

    };
}

- (void)setupPeriodicSyncResponse
{
    //create weak reference to self in order to prevent retain cycle in block
    __weak CDVBackgroundSync* weakSelf = self;
    
    //Indicate to OS success or failure and unregister syncs that have been successfully executed and are not periodic
    serviceWorker.context[@"sendPeriodicSyncResponse"] = ^(JSValue *responseType, JSValue *jsTag) {
        NSString *tag = [jsTag toString];
        [CDVBackgroundSync validateTag:&tag];
        completedSyncs++;
        switch ([responseType toInt32]) {
            case 0:
                if (fetchResult != UIBackgroundFetchResultFailed) {
                    fetchResult = UIBackgroundFetchResultNewData;
                }
                //Reschedule the sync by retimestamping
                weakSelf.periodicRegistrationList[tag][@"_timestamp"] = @([NSDate date].timeIntervalSince1970 * 1000);
                break;
            case 2:
                NSLog(@"Failed to get data");
                fetchResult = UIBackgroundFetchResultFailed;
            default:
                // Pushback failed sync by retimestamping with not current time, but with original timestamp + pushback time
                weakSelf.periodicRegistrationList[tag][@"_timestamp"] = @([weakSelf.periodicRegistrationList[tag][@"_timestamp"] integerValue] + pushback);
                break;
        }
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:weakSelf.periodicRegistrationList forKey:PERIODIC_REGISTRATION_LIST_STORAGE_KEY];

        // Make sure we received all the syncs before determining completion
        if (completedSyncs == dispatchedSyncs) {
            // Reset the sync count
            completedSyncs = 0;
            dispatchedSyncs = 0;

            fetchResult = UIBackgroundFetchResultNoData;
            
            //If we have no more registrations left, turn off background fetch
            if (![weakSelf.registrationList count] && ![weakSelf.periodicRegistrationList count]) {
                [[UIApplication sharedApplication] setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalNever];
            }
            [weakSelf scheduleSync];
            NSLog(@"Rescheduling %@", tag);
            if (weakSelf.completionHandler != nil) {
                NSLog(@"Executing Completion Handler");
                weakSelf.completionHandler(fetchResult);
                weakSelf.completionHandler = nil;
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
        [self scheduleSync];
    } else {
        NSLog(@"Lost Connection");
    }
}

- (void)evaluateSyncs
{
    // Force update reachability status because otherwise network status won't be updated when in background
    CDVConnection *connection = [self.commandDelegate getCommandInstance:@"NetworkStatus"];
    [connection performSelector:@selector(updateReachability:) withObject:connection.internetReach];    // Very much declared in CDVConnection
    // This should never happen, but just in case there are no registrations and a sync event is initiated
    if (![registrationList count] && ![periodicRegistrationList count]) {
        if (completionHandler) {
            self.completionHandler(UIBackgroundFetchResultNoData);
        }
        return;
    }
    NSLog(@"Fetching");
    if ([self getNetworkStatus]) {
        [self dispatchSyncEvents];
    } else if ([registrationList count]) {
        fetchResult = UIBackgroundFetchResultFailed;
    }
    [self evaluatePeriodicSyncRegistrations];
    
    // If there is no connection during a background fetch but there exist one off registrations
    if (![periodicRegistrationList count] && ![self getNetworkStatus]) {
        NSLog(@"Failed to sync");
        self.completionHandler(UIBackgroundFetchResultFailed);
        self.completionHandler = nil;
    }
}

- (void)application:(UIApplication*)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    backgroundSync.completionHandler = completionHandler;
    [backgroundSync evaluateSyncs];
}

- (void)dispatchSyncEvents
{
    for (NSDictionary *registration in [registrationList allValues]) {
        //Increment the counter of dispatched syncs
        [self fireSyncEventForRegistration:registration];
    }
}

- (void)fireSyncEventForRegistration:(NSDictionary*)registration
{
    dispatchedSyncs++;
    NSError *error;
    NSData *json = [NSJSONSerialization dataWithJSONObject:registration options:0 error:&error];
    NSString *dispatchCode = [NSString stringWithFormat:@"FireSyncEvent(%@);", [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
    [serviceWorker.context performSelectorOnMainThread:@selector(evaluateScript:) withObject:dispatchCode waitUntilDone:NO];
}

- (void)evaluatePeriodicSyncRegistrations
{
    for (NSDictionary *registration in [periodicRegistrationList allValues]) {
        if ([registration[@"_timestamp"] integerValue] + [registration[@"minPeriod"] integerValue] > [NSDate date].timeIntervalSince1970 * 1000) {
            continue;
        }
        NSInteger networkStatus = [self getNetworkStatus];
        if (([registration[@"networkState"] isEqualToString:@"online"] && networkStatus < 1) || [registration[@"networkState"] isEqualToString:@"avoid-cellular"] && networkStatus < 2) {
            continue;
        }
        if ([registration[@"powerState"] isEqualToString:@"avoid-draining"] && ![self isCharging]) {
            continue;
        }
        [self dispatchPeriodicSyncEvent:registration];
    }
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
    return [[UIDevice currentDevice] batteryState] == UIDeviceBatteryStateCharging || [[UIDevice currentDevice] batteryState] == UIDeviceBatteryStateFull;
}

- (void)batteryStateCallback
{
    if ([[UIDevice currentDevice] batteryState] == UIDeviceBatteryStateCharging) {
        // Device has been plugged in
        [self scheduleSync];
    } else {
        // Device has been unplugged
    }
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

- (void)foregroundSync
{
    // Prevent duplicate "evaluateSyncs" calls that might happen during background fetch event
    if (!completionHandler) {
        [self evaluateSyncs];
    }
}

- (void)scheduleSync
{
    if (!periodicRegistrationList || ![periodicRegistrationList count]) {
        return;
    }
    double delay = 0;
    double min = 0;
    for (NSDictionary *registration in [periodicRegistrationList allValues]) {
        double possibleMin = [registration[@"_timestamp"] doubleValue] + [registration[@"minPeriod"] doubleValue];
        if (!min || possibleMin < min) {
            min = possibleMin;
        }
    }
    double bestTime = 0;
    for (NSDictionary *registration in [periodicRegistrationList allValues]) {
        double possibleBestTime = [registration[@"_timestamp"] doubleValue] + [registration[@"minPeriod"] doubleValue];
        if (possibleBestTime < min + maxWaitTime && possibleBestTime > bestTime) {
            bestTime = possibleBestTime;
        }
    }
    if (bestTime) {
        delay = ceil(bestTime/1000.0 - [NSDate date].timeIntervalSince1970);
    }
    NSLog(@"Delay: %@", @(delay));
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(foregroundSync) object:nil];
    [self performSelector:@selector(foregroundSync) withObject:nil afterDelay:delay];
}
@end
