var exec = require('cordova/exec');
var serviceWorker = require('org.apache.cordova.serviceworker.ServiceWorker');

//List of all current SyncManager Registrations. Kept outside of object so that it is not exposed
var networkStatus;
var isIdle = false;

// Checks to see if the criteria have been met for this registration
// Currently Supported Options:
// id, minDelay, minRequiredNetwork, idleRequired
// Todo: allowOnBattery, maxDelay, minPeriod
var checkSyncRegistration = function(registration) {
    console.log(registration);
    if(registration.maxDelay != 0 && ((new Date()).getTime() - registration.maxDelay > registration.time)) {
	exec(null, null, "BackgroundSync", "unregister", [registration.id]);
	return false;
    }
    if(registration.idleRequired && !isIdle) {
	return false;
    }
    if(registration.hasBeenExecuted) {
	if ((new Date()).getTime() - registration.minPeriod < registration.time) {
	    return false;
	}
    } else if ((new Date()).getTime() - registration.minDelay < registration.time) {
	return false;
    }
    if (registration.minRequiredNetwork > networkStatus) {
	return false;
    }
    return true;
}

// Function to be called Asynchronously to resolve registrations
var resolveRegistrations = function(connectionType) {
    //Update the connection
    networkStatus = connectionType;
    var inner = function(regs) {
	var bEventDispatched = false;
	for(var i = 0; i < regs.length; i++) {
	    if (checkSyncRegistration(regs[i])) {
		exec(null, null, "BackgroundSync", "dispatchSyncEvent", [regs[i]]);
		bEventDispatched = true;
		/*if (regs[i].minPeriod != 0) {
		    regs[i].hasBeenExecuted = true;
		    regs[i].time = (new Date()).getTime();
		}*/
	    }
	}
    }
    exec(inner, null, "BackgroundSync", "getRegistrations", []);
}

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
}

var SyncManager = {
    registerFetch: function(callback) {
	console.log("Registering BackgroundFetch");
	exec(callback, null, "BackgroundSync", "registerFetch", []);
    },
    updateNetworkStatus: function() {
	//TODO: Add hostname as parameter for getNetworkStatus to ensure connection
	exec(resolveRegistrations, null, "BackgroundSync", "getNetworkStatus", []);
    },
    //Go through all the current registrations. If their requirements are met, resolve their promises
    syncCheck: function(message) {
	console.log("syncCheck");
	if(message === "idle") {
	    isIdle = true;
	} else {
	    isIdle = false;
	}
	//Check the network status, will automatically call resolveRegistrations();
	SyncManager.updateNetworkStatus();
    },
    register: function(SyncRegistrationOptions) {
	console.log("Registering onSync");
	var options = cloneOptions(SyncRegistrationOptions);
	return new Promise(function(resolve,reject) {
	    var innerSuccess = function() {
		//add this registration to the list to check with a new promise
		console.log("Adding to Sync List");
		exec(SyncManager.syncCheck, null, "BackgroundSync", "register", [options]);
		resolve(options);
	    };
	    var innerFail = function() {
		reject(options); 
	    };

	    // Check that this registration id does not already exist in the registration list
	    exec(innerSuccess, innerFail, "BackgroundSync", "checkUniqueId", [options.id])
	});
    },
    getRegistrations: function() {
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
}

navigator.serviceWorker.ready.then(function(serviceWorkerRegistration) {
    serviceWorkerRegistration.syncManager = SyncManager;
    exec(SyncManager.syncCheck, null, "BackgroundSync", "registerFetch", []);
    exec(null, null, "BackgroundSync", "unregisterSetup", []);
    
    //If there are any registrations at startup, check them
    exec(SyncManager.syncCheck, null, "BackgroundSync", "getRegistrations", []);
});
 
module.exports = SyncManager;
