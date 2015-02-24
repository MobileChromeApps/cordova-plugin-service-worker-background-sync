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

@implementation CDVBackgroundSync

@synthesize callback;
@synthesize completionHandler;

- (void)registerFetch:(CDVInvokedUrlCommand*)command
{
    self.callback = command.callbackId;
    
    NSLog(@"register %@", callback);
    
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [result setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:result callbackId:callback];
    
}

- (void)register:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_NO_RESULT];
    [result setKeepCallback:[NSNumber numberWithBool:YES]];
    [self.commandDelegate sendPluginResult:result callbackId:callback];
}

- (void)setContentAvailable:(CDVInvokedUrlCommand*)command
{
    NSLog(@"setContentAvailable");
    self.completionHandler((UIBackgroundFetchResult)[[command arguments] objectAtIndex:0]);
}

- (void)fetchNewDataWithCompletionHandler:(Completion)handler
{
    NSLog(@"Fetching");
    
    self.completionHandler = handler;
    if (self.callback) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:YES];
        [result setKeepCallback:[NSNumber numberWithBool:YES]];
        [self.commandDelegate sendPluginResult:result callbackId:callback];
    }
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

