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
    if (registration.maxDelay != 0 && ((new Date()).getTime() - registration.maxDelay > registration.time)) {
	exec(null, null, "BackgroundSync", "unregister", [registration.id]);
	return false;
    }
    if (registration.idleRequired && !isIdle) {
	return false;
    }
    if (registration.hasBeenExecuted) {
	if ((new Date()).getTime() - registration.minPeriod < registration.time) {
	    return false;
	}
    } else if ((new Date()).getTime() - registration.minDelay < registration.time) {
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
    var inner = function(regs) {
	regs.forEach(function(reg) {
	    if (checkSyncRegistration(reg)) {
		exec(null, null, "BackgroundSync", "dispatchSyncEvent", [reg]);
	    }
	});
	exec(scheduleForegroundSync, null, "BackgroundSync", "getBestForegroundSyncTime", []);
    }
    exec(inner, null, "BackgroundSync", "getRegistrations", []);
};

// We use this function so there are no side effects if the original options reference is modified
// and to make sure that all of the settings are within their defined limits
var cloneOptions = function(toClone) {
    var options = new SyncRegistration();
    if (toClone.id == null) {
	// Use Timestamp as unique UUID
	options.id = "k" + (new Date()).getTime();
    } else {
	options.id = toClone.id;
    }
    if (toClone.minDelay != null) {
	options.minDelay = toClone.minDelay;
    }
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
    console.log("syncCheck");
    if (message === "idle") {
	isIdle = true;
    } else {
	isIdle = false;
    }
    //Check the network status and then resolve registrations
    exec(resolveRegistrations, null, "BackgroundSync", "getNetworkAndBatteryStatus", []);
};

var scheduleForegroundSync = function(time) {
    if (timeoutTracker != null) {
	clearTimeout(timeoutTracker);
    }
    timeoutTracker = setTimeout(function() {
	exec(null, syncCheck, "BackgroundSync", "checkIfIdle", []);
    }, time - (new Date()).getTime());
    console.log("Scheduling Foreground Sync for: " + time);
};

SyncManager = function() {
    return this;
};

SyncManager.prototype.register = function(SyncRegistrationOptions) {
    var options = cloneOptions(SyncRegistrationOptions);
    return new Promise(function(resolve,reject) {
	var innerSuccess = function() {
	    var innerContinue = function() {
		// Find the time for the next foreground sync
		exec(scheduleForegroundSync, null, "BackgroundSync", "getBestForegroundSyncTime", []);
		resolve(options);
	    };
	    exec(innerContinue, null, "BackgroundSync", "register", [options]);
	    console.log("Registering " + options.id);
	};
	var innerFail = function() {
	    console.log("Failed to register " + options.id);
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
	    resolve(regs)
	}
	var innerFail = function(regs) {
	    resolve(null);
	}
	exec(innerSuccess, innerFail, "BackgroundSync", "getRegistrations", []);
    });
}

navigator.serviceWorker.ready.then(function(serviceWorkerRegistration) {
    serviceWorkerRegistration.syncManager = new SyncManager();
    exec(syncCheck, null, "BackgroundSync", "initBackgroundSync", []);
    
    //If there are any registrations at startup, check them
    exec(syncCheck, null, "BackgroundSync", "getRegistrations", []);
});
 
module.exports = SyncManager;
