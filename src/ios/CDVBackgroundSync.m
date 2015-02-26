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

NSString * const REGISTRATION_LIST_STORAGE_KEY = @"registrationList";

@implementation CDVBackgroundSync

@synthesize syncCheckCallback;
@synthesize completionHandler;
@synthesize serviceWorker;
@synthesize registrationList;

-(void)restoreRegistrations
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *restored = [defaults objectForKey:REGISTRATION_LIST_STORAGE_KEY];
    if (restored != nil) {
        registrationList = restored;
    }
}

- (void)initBackgroundSync:(CDVInvokedUrlCommand*)command
{
    //TODO: Find a better place to run this setup
    [self syncResponseSetup];
    [self unregisterSetup];
    
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
    //Save the list
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
    [defaults synchronize];
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
        NSLog(@"Unregistering %@", registrationId);
        NSString *regId = [registrationId toString];
        
        [weakSelf.registrationList removeObjectForKey:regId];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:weakSelf.registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
        [defaults synchronize];
    };
}

- (void)unregister:(CDVInvokedUrlCommand*)command
{
    NSLog(@"Unregistered %@ without syncing", [command argumentAtIndex:0]);
    [registrationList removeObjectForKey:[command argumentAtIndex:0]];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:registrationList forKey:REGISTRATION_LIST_STORAGE_KEY];
    [defaults synchronize];
}

- (void)syncResponseSetup
{
    //create weak reference to self in order to prevent retain cycle in block
    __weak CDVBackgroundSync* weakSelf = self;
    
    serviceWorker.context[@"sendSyncResponse"] = ^(JSValue *responseType) {
        
        //Response Type: 0 = New Data, 1 = No Data, 2 = Failed to Fetch
        if (weakSelf.completionHandler) {
            if ([responseType toInt32] == 0) {
                NSLog(@"Got new data");
                weakSelf.completionHandler(UIBackgroundFetchResultNewData);
            } else if ([responseType toInt32] == 1) {
                NSLog(@"Got no data");
                weakSelf.completionHandler(UIBackgroundFetchResultNoData);
            } else if ([responseType toInt32] == 2) {
                NSLog(@"Failed to get data");
                weakSelf.completionHandler(UIBackgroundFetchResultFailed);
            }
            weakSelf.completionHandler = nil;
        }
    };
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
    //[[self.serviceWorker context] evaluateScript:@"dispatchEvent(new ExtendableEvent('sync'));"];
    NSString *message = [command argumentAtIndex:0];
    
    // If we need all of the object properties
    NSError *error;
    NSData *json = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
    NSString *dispatchCode = [NSString stringWithFormat:@"FireSyncEvent(JSON.parse('%@'));", [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding]];
    [serviceWorker.context evaluateScript:dispatchCode];
}

- (void)getNetworkStatus:(CDVInvokedUrlCommand*)command
{
    Reachability* reach = [Reachability reachabilityForInternetConnection];
    [reach startNotifier];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:[reach currentReachabilityStatus]];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}
@end

