var exec = require('cordova/exec');
var serviceWorker = require('org.apache.cordova.serviceworker.ServiceWorker');

//List of all current SyncManager Registrations. Kept outside of object so that it is not exposed
var SyncRegistrations = [];
var toDelete = [];
var networkStatus;
var isIdle = false;

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

// Called after all simulataneous sync events have terminated
var removeRegistrations = function(){
    for(var j = 0; j < toDelete.length; j++){
	//find the registration by id and mark it for deletion. Deletion only takes place after all simultaneous sync events have resolved
	for(var i = 0; i < SyncRegistrations.length; i++){
	    if(SyncRegistrations[i].id == toDelete[j]) {
		console.log("Deleting" + toDelete[j]);
		SyncRegistrations.splice(i, 1);
		break;
	    }	
	}
    }
    toDelete = [];
}

// Function to be called Asynchronously to resolve registrations
var resolveRegistrations = function(connectionType){
    //Update the connection
    networkStatus = connectionType;
    var toDispatch = [];
    for(var i = 0; i < SyncRegistrations.length; i++){
	if (checkSyncRegistration(SyncRegistrations[i])) {
	    //toDispatch.push(SyncRegistrations[i]);
	    exec(null, null, "BackgroundSync", "dispatchSyncEvent", [SyncRegistrations[i]]);
	    if (SyncRegistrations[i].minPeriod != 0){
		//SyncRegistrations[i].promise = new Promise(function(resolve, reject){
		//SyncRegistrations[i].resolve = resolve;
		SyncRegistrations[i].hasBeenExecuted = true;
		SyncRegistrations[i].time = (new Date()).getTime();
	    } else {
	    // If this registration has been resolved and will not repeat, then remove it
		//SyncRegistrations.splice(i, 1);
	    }
	}
    }
    
    //For completionType: 0 = NewData, 1 = NoData, 2 = Failed
    var completionType = 1;

    if(toDispatch.length > 0) {
	exec(null, null, "BackgroundSync", "dispatchSyncEvent", [toDispatch]);
	completionType = 0;
    }

    return exec(removeRegistrations, null, "BackgroundSync", "setContentAvailable", [completionType]);
}

// We use this function so there are no side effects if the original options reference is modified
// and to make sure that all of the settings are within their defined limits
var cloneOptions = function(toClone){
    var options = new SyncRegistration();
    if (toClone.id == null) {
	//TODO: Generate random Uuid and make sure it is unique 
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
	var options = cloneOptions(SyncRegistrationOptions);
	// If the criteria are met, then we can resolve this promise now
	if (checkSyncRegistration(options)){
	    console.log("Immediate Sync");
	    return Promise.resolve();
	} else {
	    //Otherwise add this registration to the list to check with a new promise
	    console.log("Adding to Sync List");
	    SyncRegistrations.push(options);
	    console.log(SyncRegistrations);
	    return Promise.resolve(options);
	}
    },
    unregister: function(registrationID) {
    	console.log("Unregistering " + registrationID);
	//mark registrationID for deletion
	toDelete.push(registrationID);
    },
    getRegistrations: function(){
	console.log(SyncRegistrations);
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
    exec(SyncManager.unregister, null, "BackgroundSync", "unregisterSetup", []);
});
 
module.exports = SyncManager;
