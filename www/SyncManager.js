var exec = require('cordova/exec');
var serviceWorker = require('org.apache.cordova.serviceworker.ServiceWorker');

var networkStatus;
var isCharging;
var isIdle = false;
var timeoutTracker = null;

// Checks to see if the criteria have been met for this registration
// Currently Supported Options:
// id, minDelay, minRequiredNetwork, idleRequired, maxDelay, minPeriod, allowOnBattery
var checkSyncRegistration = function(registration) {
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
};

var resolveRegistrations = function(statusVars) {
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
};

// We use this function so there are no side effects if the original options reference is modified
// and to make sure that all of the settings are within their defined limits
var cloneOptions = function(toClone) {
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

var syncCheck = function(message) {
    isIdle = (message === "idle");
    //Check the network status and then resolve registrations
    exec(resolveRegistrations, null, "BackgroundSync", "getNetworkAndBatteryStatus", []);
};

var scheduleForegroundSync = function(time) {
    if (timeoutTracker !== null) {
	clearTimeout(timeoutTracker);
    }
    timeoutTracker = setTimeout(function() {
	exec(null, syncCheck, "BackgroundSync", "checkIfIdle", []);
    }, time - Date.now());
};

SyncManager = function() {};

SyncManager.prototype.register = function(syncRegistrationOptions) {
    return new Promise(function(resolve,reject) {
	var options = cloneOptions(syncRegistrationOptions);
	var success = function() {
	    var innerSuccess = function(time) {
		scheduleForegroundSync(time);
		resolve(options);
	    };
	    // Find the time for the next foreground sync
	    exec(innerSuccess, fail, "BackgroundSync", "getBestForegroundSyncTime", []);
	};
	var fail = function() {
	    reject(options); 
	};
	// register does not dispatch an error
	exec(success, fail, "BackgroundSync", "cordovaRegister", [options]);
    });
};

SyncManager.prototype.getRegistrations = function() {
    return new Promise(function(resolve, reject) {
	var success = function(regs) {
	    regs.forEach(function(reg) {
		reg.unregister = function() {
		    cordova.exec(null, null, "BackgroundSync", "unregister", [reg.id]);
		};
	    });
	    resolve(regs);
	};
	var failure = function(err) {
	    reject(err);
	};
	exec(success, failure, "BackgroundSync", "getRegistrations", []);
    });
};

SyncManager.prototype.getRegistration = function(regId) {
    return new Promise(function(resolve, reject) {
	var success = function(reg) {
	    reg.unregister = function() {
		cordova.exec(null, null, "BackgroundSync", "unregister", [reg.id]);
	    };
	    resolve(reg);
	};
	var failure = function(err) {
	    reject(err);
	};
	exec(success, failure, "BackgroundSync", "getRegistration", [regId]);
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
