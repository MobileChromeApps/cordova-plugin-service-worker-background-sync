this.onsync = function(event) {
    var promise = new Promise(function(resolve, reject) {
	if (event.registration.tag === 'fail') {
	    reject();
	}
	var message = {};
	message.tag = event.registration.tag;
	message.type = "one-off";
	client.postMessage(message);
	resolve(true);
    });
    promise.then(function() {
	var message = {};
	message.tag = event.registration.tag;
	message.type = "one-off-success";
	client.postMessage(message);
    }, function() {
	var message = {};
	message.tag = event.registration.tag;
	message.type = "one-off-fail";
	client.postMessage(message);
    });
    event.waitUntil(promise);
};

this.onperiodicsync = function(event) {
    event.waitUntil(new Promise(function(resolve, reject) {
	var message = {};
	message.tag = event.registration.tag;
	message.minPeriod = event.registration.minPeriod;
	message.networkState = event.registration.networkState;
	message.powerState = event.registration.powerState;
	message.type = "periodic";
	client.postMessage(message);
	resolve(true);
    }));
};
