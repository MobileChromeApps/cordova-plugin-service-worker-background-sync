 Object.defineProperty(this, 'onsync', {
    configurable: false,
    enumerable: true,
    get: eventGetter('sync'),
    set: eventSetter('sync')
});

function Registration() {
}

Registration.prototype.unregister = function() {
    unregisterSync(this.id);
};

function SyncEvent() {
    this.registration = new Registration();
}f

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
    if (Array.isArray(ev.promises)) {
	return Promise.all(ev.promises).then(function(){
		sendSyncResponse(0, data.id);
	    },function(){
		sendSyncResponse(2, data.id);
	    });
    } else {
	sendSyncResponse(1, data.id);
	return Promise.resolve();
    }
};
