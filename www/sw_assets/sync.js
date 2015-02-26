 Object.defineProperty(this, 'onsync', {
    configurable: false,
    enumerable: true,
    get: eventGetter('sync'),
    set: eventSetter('sync')
});

Registration = function() {
    return this;
};

Registration.prototype.unregister = function() {
    unregisterSync(this.id);
};

SyncEvent = function() {
    this.registration = new Registration();
    return this;
};

SyncEvent.prototype = new ExtendableEvent('sync');

FireSyncEvent = function(data) {
    var ev = new SyncEvent();
    ev.registration.id = data.id;
    /*
    ev.registration.minDelay = data.minDelay;
    ev.registration.maxDelay = data.maxDelay;
    ev.registration.minPeriod = data.minPeriod;
    ev.registration.minRequiredNetwork = data.minRequiredNetwork;
    ev.registration.allowOnBattery = data.allowOnBattery;
    ev.registration.idleRequired = data.idleRequired;*/
    dispatchEvent(ev);
    if(ev.promises instanceof Array) {
	return Promise.all(ev.promises).then(function(){
		sendSyncResponse(0);
	    },function(){
		sendSyncResponse(2);
	    });
    } else {
	sendSyncResponse(1);
	return Promise.resolve();
    }
};
