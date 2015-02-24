var exec = require('cordova/exec');
var serviceWorker = require('org.apache.cordova.serviceworker.ServiceWorker');

//List of all current SyncManager Registrations. Kept outside of object so that it is not exposed
var SyncRegistrations = [];
var networkStatus;
var isIdle = false;

var connectionCallback = function(connectionType){
    /*Connection Types:
     * 0: No connection
     * 1: WWAN
     * 2: Wifi
    **/
    networkStatus = connectionType;
    console.log("Connection Type: " + connectionType);
};

// Checks to see if the criteria have been met for this registration
// Currently Supported Options:
// id, minDelay, minRequiredNetwork, minPeriod
// Todo: idleRequired, allowOnBattery, maxDelay
var checkSyncRegistration = function(registration){
    console.log(registration);
    if(registration.idleRequired && !isIdle) {
	return false;
    }
    if(registration.hasBeenExecuted){
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
var resolveRegistrations = function(connectionType){
    //Update the connection
    networkStatus = connectionType;
    
    var hasAnythingSynced = false;

    for(var i = 0; i < SyncRegistrations.length; i++){
	if (checkSyncRegistration(SyncRegistrations[i])) {
	    SyncRegistrations[i].resolve();
	    hasAnythingSynced = true;
	    if (SyncRegistrations[i].minPeriod != 0){
		SyncRegistrations[i].promise = new Promise(function(resolve, reject){
		SyncRegistrations[i].resolve = resolve;
	    });
		SyncRegistrations[i].hasBeenExecuted = true;
		SyncRegistrations[i].time = (new Date()).getTime();
	    } else {
	    // If this registration has been resolved and will not repeat, then remove it
	    SyncRegistrations.splice(i, 1);
	    }
	}
    }

    //For completionType: 0 = NewData, 1 = NoData, 2 = Failed
    var completionType = 0;
    return exec(null, null, "BackgroundSync", "setContentAvailable", [completionType]);
}

var SyncManager = {
    registerFetch: function(callback){
	console.log("Registering BackgroundFetch");
	exec(callback, null, "BackgroundSync", "registerFetch", []);
    },
    updateNetworkStatus: function(){
	//TODO: Add hostname as parameter for getNetworkStatus to ensure connection
	exec(resolveRegistrations, null, "BackgroundSync", "getNetworkStatus", []);
    },
    register: function(SyncRegistrationOptions){
	console.log("Registering onSync");
	//TODO: If SyncRegistrationOptions.id == null, generate UUID
	
	if(SyncRegistrationOptions.minPeriod == null) {
	    SyncRegistrationOptions.minPeriod = 0;
	}
	// Timestamp the registration
	SyncRegistrationOptions.time = (new Date()).getTime();

	// If the criteria are met, then we can resolve this promise now
	if (checkSyncRegistration(SyncRegistrationOptions)){
	    console.log("Immediate Sync");
	    return Promise.resolve();
	} else {
	    //Otherwise add this registration to the list to check with a new promise
	    console.log("Adding to Sync List");
	    var resolveStore;
	    var promise = new Promise(function(resolve, reject){
		resolveStore = resolve;
	    });
	    SyncRegistrationOptions.promise = promise;
	    SyncRegistrationOptions.resolve = resolveStore;
	    SyncRegistrations.push(SyncRegistrationOptions);
	    console.log(SyncRegistrations);
	    return promise;
	}
    },
    unregister: function(registrationID) {
	//find the registration by id
	for(var i = 0; i < SyncRegistrations.length; i++){
	    if(SyncRegistrations[i].id == registrationID) {
		SyncRegistrations.splice(i, 1);
		return Promise.resolve(true);
	    }	
	}
	return Promise.resolve(false);
	//TODO: implement SyncRegistrations as hashmap for faster lookup and deletion
    },
    getRegistrations: function(){
	return new Promise(function(resolve, reject){
	    resolve(SyncRegistrations);
	});
    },
    //Go through all the current registrations. If their requirements are met, resolve their promises
    syncCheck: function(message){
    	console.log("syncCheck");
	isIdle = message;
	
	//Check the network status, will automatically call resolveRegistrations();
	SyncManager.updateNetworkStatus();
    }
}

navigator.serviceWorker.ready.then(function(serviceWorkerRegistration){
    serviceWorkerRegistration.syncManager = SyncManager;
    exec(SyncManager.syncCheck, null, "BackgroundSync", "registerFetch", []);
});
 
module.exports = SyncManager;
