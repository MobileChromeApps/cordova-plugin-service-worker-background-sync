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

var networkStatus;
var isCharging;
var isIdle = false;
var timeoutTracker = null;

// Checks to see if the criteria have been met for this registration
// Currently Supported Options:
// id, minDelay, minRequiredNetwork, idleRequired, maxDelay, minPeriod, allowOnBattery
function checkSyncRegistration(registration) {
    if (registration.maxDelay !== 0 && (Date.now() - registration.maxDelay > registration.time)) {
	exec(null, null, "BackgroundSync", "unregister", [registration.id]);
	return false;
    }
    if (registration.idleRequired && !isIdle) {
	return false;
    }
    if (Date.now() - registration.minDelay < registration.time) {
	return false;
    }
    if (registration.minRequiredNetwork > networkStatus) {
	return false;
    }
    if (!isCharging && !registration.allowOnBattery) {
	return false;
    }
    return true;
}

function resolveRegistrations(statusVars) {
    //Update the connection
    networkStatus = statusVars[0];
    isCharging = statusVars[1];
    var success = function(regs) {
	regs.forEach(function(reg) {
	    if (checkSyncRegistration(reg)) {
		exec(null, null, "BackgroundSync", "dispatchSyncEvent", [reg]);
	    }
	});
    };
    var failure = function(message) {
	//If there are no registrations, return completion handler on background fetch
	exec(null, null, "BackgroundSync", "markNoDataCompletion", []);
    };
    exec(success, failure, "BackgroundSync", "getRegistrations", []);
}

// We use this function so there are no side effects if the original options reference is modified
// and to make sure that all of the settings are within their defined limits
function cloneOptions(toClone) {
    if (typeof toClone === 'undefined') {
	toClone = {};
    }
    var options = new SyncRegistration();
    options.id = toClone.id;
    options.minDelay = toClone.minDelay || options.minDelay;
    options.maxDelay = toClone.maxDelay || options.maxDelay;
    options.minPeriod = toClone.minPeriod || options.minPeriod;
    options.minRequiredNetwork = toClone.minRequiredNetwork || options.minRequiredNetwork;
    if (typeof toClone.allowOnBattery !== 'undefined') {
	options.allowOnBattery = toClone.allowOnBattery;
    }
    options.idleRequired = toClone.idleRequired || options.idleRequired;
    // Timestamp the registration
    options.time = Date.now();
    return options;
}

function syncCheck(message) {
    isIdle = (message === "idle");
    //Check the network status and then resolve registrations
    exec(resolveRegistrations, null, "BackgroundSync", "getNetworkAndBatteryStatus", []);
}

function scheduleForegroundSync(time) {
    if (timeoutTracker !== null) {
	clearTimeout(timeoutTracker);
    }
    timeoutTracker = setTimeout(function() {
	exec(null, syncCheck, "BackgroundSync", "checkIfIdle", []);
    }, time - Date.now());
}

function nativeToJSReg(reg) {
    var newReg = new SyncRegistration();
    for (var key in reg) {
        newReg[key] = reg[key];
    }
    return newReg;
}

function SyncManager() {}

SyncManager.prototype.register = function(syncRegistrationOptions) {
    return new Promise(function(resolve,reject) {
	var options = cloneOptions(syncRegistrationOptions);
	var success = function() {
	    var innerSuccess = function(time) {
		scheduleForegroundSync(time);
		resolve(options);
	    };
	    // Find the time for the next foreground sync
	    exec(innerSuccess, null, "BackgroundSync", "getBestForegroundSyncTime", []);
	};
	// register does not dispatch an error
	exec(success, null, "BackgroundSync", "cordovaRegister", [options]);
    });
};

SyncManager.prototype.getRegistrations = function() {
    return new Promise(function(resolve, reject) {
	var success = function(regs) {
	    var newRegs = regs.map(nativeToJSReg);
	    resolve(newRegs);
	};
	// getRegistrations does not fail, it returns an empty array when there are no registrations
	exec(success, null, "BackgroundSync", "getRegistrations", []);
    });
};

SyncManager.prototype.getRegistration = function(regId) {
    return new Promise(function(resolve, reject) {
	var success = function(reg) {
	    reg = nativeToJSReg(reg);
	    resolve(reg);
	};
	exec(success, reject, "BackgroundSync", "getRegistration", [regId]);
    });
};

SyncManager.prototype.hasPermission = function() {
    return new Promise(function(resolve, reject) {
	var success = function (message) {
	    if (message === "granted") {
		resolve(SyncPermissionStatus.granted);
	    } else {
		resolve(SyncPermissionStatus.denied);
	    }
	};
	exec(success, null, "BackgroundSync", "hasPermission", []);
    });
};

navigator.serviceWorker.ready.then(function(serviceWorkerRegistration) {
    serviceWorkerRegistration.syncManager = new SyncManager();
    exec(syncCheck, scheduleForegroundSync, "BackgroundSync", "initBackgroundSync", []);
});
 
module.exports = SyncManager;
