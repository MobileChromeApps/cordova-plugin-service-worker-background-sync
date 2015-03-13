var exec = require('cordova/exec');
var serviceWorker = require('org.apache.cordova.serviceworker.ServiceWorker');

var networkStatus;
var isCharging;
var isIdle = false;
var timeoutTracker = null;
var idCounter = Date.now();

// Checks to see if the criteria have been met for this registration
// Currently Supported Options:
// id, minDelay, minRequiredNetwork, idleRequired, maxDelay, minPeriod, allowOnBattery
var checkSyncRegistration = function(registration) {
    if (registration.maxDelay > 0 && ((Date.now() - registration.maxDelay > registration.time)) {
	exec(null, null, "BackgroundSync", "unregister", [registration.id]);
	return false;
    }
    if (registration.idleRequired && !isIdle) {
	return false;
    }
    if ((Date.now() - registration.minDelay < registration.time) {
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
	exec(scheduleForegroundSync, null, "BackgroundSync", "getBestForegroundSyncTime", []);
    };
    var failure = function(message) {
	//If there are no registrations, return completion handler on background fetch
	exec(null, null, "BackgroundSync", "markNoDataCompletion", []);
    }
    exec(success, failure, "BackgroundSync", "getRegistrations", []);
};

// We use this function so there are no side effects if the original options reference is modified
// and to make sure that all of the settings are within their defined limits
var cloneOptions = function(toClone) {
    var options = new SyncRegistration();
    options.id = toClone.id || ("k" + idCounter++);
    options.minDelay = toClone.minDelay || options.minDelay;
    if (toClone.maxDelay != null) {
	options.maxDelay = toClone.maxDelay;
    }
    if (toClone.minPeriod != null) {
	options.minPeriod = toClone.minPeriod;
    }
    if (toClone.minRequiredNetwork != null && toClone.minRequiredNetwork >= -1 && toClone.minRequiredNetwork <= 2) {
	options.minRequiredNetwork = toClone.minRequiredNetwork;
    }
    if (toClone.allowOnBattery != null) {
	options.allowOnBattery = toClone.allowOnBattery;
    }
    if (toClone.idleRequired != null) {
	options.idleRequired = toClone.idleRequired;
    }
    // Timestamp the registration
    options.time = (new Date()).getTime();
    return options;
};

var syncCheck = function(message) {
    isIdle = (message === "idle");
    //Check the network status and then resolve registrations
    exec(resolveRegistrations, null, "BackgroundSync", "getNetworkAndBatteryStatus", []);
};

var scheduleForegroundSync = function(time) {
    if (timeoutTracker != null) {
	clearTimeout(timeoutTracker);
    }
    timeoutTracker = setTimeout(function() {
	exec(null, syncCheck, "BackgroundSync", "checkIfIdle", []);
    }, time - (Date.now());
};

function SyncManager() {
}

SyncManager.prototype.register = function(syncRegistrationOptions) {
    var options = cloneOptions(syncRegistrationOptions);
    return new Promise(function(resolve,reject) {
	var innerSuccess = function() {
	    var innerContinue = function() {
		// Find the time for the next foreground sync
		exec(scheduleForegroundSync, innerFail, "BackgroundSync", "getBestForegroundSyncTime", []);
		resolve(options);
	    };
	    exec(innerContinue, innerFail, "BackgroundSync", "register", [options]);
	};
	var innerFail = function() {
	    reject(options); 
	};

	// Check that this registration id does not already exist in the registration list
	exec(innerSuccess, innerFail, "BackgroundSync", "checkUniqueId", [options.id])
    });
};

SyncManager.prototype.getRegistrations = function() {
    return new Promise(function(resolve, reject) {
	var innerSuccess = function(regs) {
	    regs.forEach(function(reg) {
		reg.unregister = function() {
		    cordova.exec(null, null, "BackgroundSync", "unregister", [reg.id]);
		};
	    });
	    resolve(regs);
	}
	var innerFail = function(regs) {
	    resolve(null);  // reject?
	}
	exec(innerSuccess, innerFail, "BackgroundSync", "getRegistrations", []);
    });
}

serviceWorker.ready.then(function(serviceWorkerRegistration) {
    serviceWorkerRegistration.syncManager = new SyncManager();
    exec(syncCheck, null, "BackgroundSync", "initBackgroundSync", []);
    
    //If there are any registrations at startup, check them
    exec(syncCheck, null, "BackgroundSync", "getRegistrations", []);
});
 
module.exports = SyncManager;
