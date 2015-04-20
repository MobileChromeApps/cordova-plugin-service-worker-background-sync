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

function SyncManager() {}

SyncManager.prototype.register = function(syncRegistrationOptions) {
    return new Promise(function(resolve,reject) {
	function callback() {
	    resolve(new SyncRegistration(syncRegistrationOptions));
	}
	if (typeof cordova !== 'undefined') {
	    // register does not dispatch an error
	    cordova.exec(callback, null, 'BackgroundSync', 'cordovaRegister', [new SyncRegistration(syncRegistrationOptions)]);
	} else {
	    CDVBackgroundSync_register(new SyncRegistration(syncRegistrationOptions), 'one-off', callback, null);
	}
    });
};

SyncManager.prototype.getRegistration = function(tag) {
    return new Promise(function(resolve, reject) {
	tag = tag || '';
	function success(reg) {
	    resolve(new SyncRegistration(reg));
	}
	if (typeof cordova !== 'undefined') {
	    cordova.exec(success, reject, 'BackgroundSync', 'getRegistration', [tag]);
	} else {
	    CDVBackgroundSync_getRegistration(tag, 'one-off', success, reject);
	}
    });
};

SyncManager.prototype.getRegistrations = function() {
    return new Promise(function(resolve, reject) {
	function callback(regs) {
	    var newRegs = regs.map(function (reg) { return new SyncRegistration(reg); });
	    resolve(newRegs);
	}
	if (typeof cordova !== 'undefined') {
	    // getRegistrations does not fail, it returns an empty array when there are no registrations
	    cordova.exec(callback, null, 'BackgroundSync', 'getRegistrations', []);
	} else {
	    CDVBackgroundSync_getRegistrations('one-off', callback);
	}
    });
};

SyncManager.prototype.permissionState = function() {
    return new Promise(function(resolve, reject) {
	if (typeof cordova !== 'undefined') {
	    cordova.exec(resolve, null, 'BackgroundSync', 'hasPermission', []);
	} else {
	    //TODO: service worker equivalent
	}
    });
};

if (typeof cordova !== 'undefined') {
    navigator.serviceWorker.ready.then(function(serviceWorkerRegistration) {
	serviceWorkerRegistration.sync = new SyncManager();
	cordova.exec(null, null, 'BackgroundSync', 'setupBackgroundSync', []);
    });
    module.exports = SyncManager;
} else {
    self.sync = new SyncManager();
}
