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

SyncPermissionState = {
    default: 0,
    denied: 1,
    granted: 2
};

SyncNetworkType = {
    networkAny: -1,
    networkOffline: 0,
    networkOnline: 1,
    networkNonMobile: 2
};

Object.freeze(SyncPermissionStatus);
Object.freeze(SyncNetworkType);
function SyncRegistration() {
    this.id = "";
    this.minDelay = 0;
    this.maxDelay = 0;
    this.minPeriod = 0;
    this.minRequiredNetwork = SyncNetworkType.online;
    this.allowOnBattery = true;
    this.idleRequired = false;
}

var CDVBackgroundSync_cloneOptions = function(toClone) {
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
};

if (typeof syncManager == 'undefined') {
    syncManager = {};
}
syncManager.register = function (syncRegistrationOptions) {
    return new Promise(function(resolve, reject) {
	var options = CDVBackgroundSync_cloneOptions(syncRegistrationOptions);
	var success = function () {
	    resolve(options);
	};
	CDVBackgroundSync_register(options, success);
    });
};
syncManager.getRegistrations = function () {
    return new Promise(function(resolve, reject) {
	var callback = function(regs) {
	    regs.forEach(function(reg) {
		reg.unregister = function() {
		    unregisterSync(reg.id);
		};
	    });
	    resolve(regs);
	};
	CDVBackgroundSync_getRegistrations(callback);
    });
};
syncManager.getRegistration = function (id) {
    return new Promise(function(resolve, reject) {
	var success = function(reg) {
	    reg.unregister = function() {
		unregisterSync(reg.id);
	    };
	    resolve(reg);
	};
	CDVBackgroundSync_getRegistration(id, success, reject);
    });
};
