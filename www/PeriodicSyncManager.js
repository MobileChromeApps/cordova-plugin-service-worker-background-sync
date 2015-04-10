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

var exec = require('cordova/exec');
var serviceWorker = require('org.apache.cordova.serviceworker.ServiceWorker');

function PeriodicSyncManager() {}

PeriodicSyncManager.prototype.register = function(syncRegistrationOptions) {
    return new Promise(function(resolve,reject) {
	function success() {
	    resolve(new PeriodicSyncRegistration(syncRegistrationOptions));
	}
	// register dispatches an error when minPeriod is less than minPossiblePeriod
	exec(success, reject, "BackgroundSync", "cordovaRegister", [new PeriodicSyncRegistration(syncRegistrationOptions), "periodic"]);
    });
};

PeriodicSyncManager.prototype.getRegistration = function(tag) {
    return new Promise(function(resolve, reject) {
	tag = tag || "";
	function success(reg) {
	    resolve(new PeriodicSyncRegistration(reg));
	}
	exec(success, reject, "BackgroundSync", "getRegistration", [tag, "periodic"]);
    });
};

PeriodicSyncManager.prototype.getRegistrations = function() {
    return new Promise(function(resolve, reject) {
	function success(regs) {
	    var newRegs = regs.map(function (reg) { return new PeriodicSyncRegistration(reg); });
	    resolve(newRegs);
	}
	// getRegistrations does not fail, it returns an empty array when there are no registrations
	exec(success, null, "BackgroundSync", "getRegistrations", ["periodic"]);
    });
};

PeriodicSyncManager.prototype.permissionState = function() {
    return new Promise(function(resolve, reject) {
	function success(message) {
	    if (message === "granted") {
		resolve(SyncPermissionState.granted);
	    } else {
		resolve(SyncPermissionState.denied);
	    }
	}
	exec(success, null, "BackgroundSync", "hasPermission", []);
    });
};

navigator.serviceWorker.ready.then(function(serviceWorkerRegistration) {
    serviceWorkerRegistration.periodicSync = new PeriodicSyncManager();
});
 
module.exports = PeriodicSyncManager;
