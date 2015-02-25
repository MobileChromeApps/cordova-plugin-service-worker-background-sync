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

@implementation CDVBackgroundSync

@synthesize syncCheckCallback;
@synthesize completionHandler;
@synthesize serviceWorker;
@synthesize registrationList;

- (void)registerFetch:(CDVInvokedUrlCommand*)command
{
    
    self.syncCheckCallback = command.callbackId;
    
    NSLog(@"register %@", syncCheckCallback);
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [result setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:result callbackId:syncCheckCallback];
    
}

- (void)register:(CDVInvokedUrlCommand*)command
{
    
    if(registrationList == nil) {
        //registrationList = [NSMutableArray arrayWithObject:[command argumentAtIndex:0]];
        registrationList = [NSMutableDictionary dictionaryWithObject:[command argumentAtIndex:0] forKey:[[command argumentAtIndex:0] objectForKey:@"id"]];
    } else {
        //[registrationList addObject:[command argumentAtIndex:0]];
        [registrationList setObject:[command argumentAtIndex:0] forKey:[[command argumentAtIndex:0] objectForKey:@"id"]];
    }
    
    //Save the list
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:registrationList forKey:@"registrationList"];
    [defaults synchronize];
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    
}

- (void)checkUniqueId:(CDVInvokedUrlCommand*)command
{
    NSString* regId = [command argumentAtIndex:0];
    
    if ([registrationList objectForKey:regId] == nil){
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"This ID has already been registered."];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
    
}

- (void)recoverRegistrations:(CDVInvokedUrlCommand*)command
{
    // If we have pre-existing registrations, give them to the javascript side
    if(registrationList != nil && [registrationList count] != 0){
        //CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:registrationList];
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:[registrationList allValues]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No Preexisting Registrations"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)getRegistrations:(CDVInvokedUrlCommand*)command
{
    // If we have pre-existing registrations, give them to the javascript side
    if(registrationList != nil && [registrationList count] != 0){
        //CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:registrationList];
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:[registrationList allValues]];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    } else {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"No Preexisting Registrations"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    }
}

- (void)unregisterSetup:(CDVInvokedUrlCommand*)command
{
    //create weak reference to self in order to prevent retain cycle in block
    __weak CDVBackgroundSync* weakSelf = self;
    
    // Set up service worker unregister event
    serviceWorker.context[@"unregisterSync"] = ^(JSValue *registrationId) {
        NSLog(@"Unregistering %@", registrationId);
        NSString *regId = [registrationId toString];
        
        [weakSelf.registrationList removeObjectForKey:regId];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:weakSelf.registrationList forKey:@"registrationList"];
        [defaults synchronize];
    };
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [result setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)setContentAvailable:(CDVInvokedUrlCommand*)command
{
    NSLog(@"setContentAvailable");
    self.completionHandler((UIBackgroundFetchResult)[[command arguments] objectAtIndex:0]);
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void)fetchNewDataWithCompletionHandler:(Completion)handler
{
    NSLog(@"Fetching");
    
    self.completionHandler = handler;
    if (self.syncCheckCallback) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
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
    
    //NSString *dispatchCode = [NSString stringWithFormat:@"FireSyncEvent(Kamino.parse('%@'));", message];
    [serviceWorker.context evaluateScript:dispatchCode];
}

- (NetworkStatus)getNetworkStatus
{
    Reachability* reach = [Reachability reachabilityForInternetConnection];
    [reach startNotifier];
    
    return [reach currentReachabilityStatus];
}

- (void)getNetworkStatus:(CDVInvokedUrlCommand*)command
{
    Reachability* reach = [Reachability reachabilityForInternetConnection];
    [reach startNotifier];
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:[reach currentReachabilityStatus]];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    
}

@end

