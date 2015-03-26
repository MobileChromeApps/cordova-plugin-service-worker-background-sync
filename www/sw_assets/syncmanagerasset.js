SyncPermissionStatus = {
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
	    CDVBackgroundSync_getBestForegroundSyncTime();
	    resolve(options);
	};
	CDVBackgroundSync_register(options, success);
    });
};
syncManager.getRegistrations = function () {
    return new Promise(function(resolve, reject) {
	var success = function(regs) {
	    regs.forEach(function(reg) {
		reg.unregister = function() {
		    unregisterSync(reg.id);
		};
	    });
	    resolve(regs);
	};
	var failure = function(err) {
	    reject(err);
	};
	CDVBackgroundSync_getRegistrations(success, failure);
    });
};
