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

function PeriodicSyncManager() {
    var that = this;
    if (typeof cordova !== 'undefined') {
	cordova.exec(function(data) { that.minPossiblePeriod = data; }, null, 'BackgroundSync', 'getMinPossiblePeriod', []);
    }
}

PeriodicSyncManager.prototype.register = function(syncRegistrationOptions) {
    return new Promise(function(resolve,reject) {
	syncRegistrationOptions = syncRegistrationOptions || {};
	function success() {
	    resolve(new PeriodicSyncRegistration(syncRegistrationOptions));
	}
	if (typeof cordova !== 'undefined') {
	    // register dispatches an error when minPeriod is less than minPossiblePeriod
	    cordova.exec(success, reject, 'BackgroundSync', 'cordovaRegister', [new PeriodicSyncRegistration(syncRegistrationOptions), 'periodic']);
	} else {
	    CDVBackgroundSync_register(new PeriodicSyncRegistration(syncRegistrationOptions), 'periodic', success, reject);
	}
    });
};

PeriodicSyncManager.prototype.getRegistration = function(tag) {
    return new Promise(function(resolve, reject) {
	tag = tag || '';
	function success(reg) {
	    resolve(new PeriodicSyncRegistration(reg));
	}
	if (typeof cordova !== 'undefined') {
	    cordova.exec(success, reject, 'BackgroundSync', 'getRegistration', [tag, 'periodic']);
	} else {
	    CDVBackgroundSync_getRegistration(tag, 'periodic', success, reject);
	}
    });
};

PeriodicSyncManager.prototype.getRegistrations = function() {
    return new Promise(function(resolve, reject) {
	function callback(regs) {
	    var newRegs = regs.map(function (reg) { return new PeriodicSyncRegistration(reg); });
	    resolve(newRegs);
	}
	if (typeof cordova !== 'undefined') {
	    // getRegistrations does not fail, it returns an empty array when there are no registrations
	    cordova.exec(callback, null, 'BackgroundSync', 'getRegistrations', ['periodic']);
	} else {
	    CDVBackgroundSync_getRegistrations('periodic', callback);
	}
    });
};

PeriodicSyncManager.prototype.permissionState = function() {
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
	serviceWorkerRegistration.periodicSync = new PeriodicSyncManager();
    });
    module.exports = PeriodicSyncManager;
} else {
    self.periodicSync = new PeriodicSyncManager();
}
