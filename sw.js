this.onsync = function(event) {
    event.waitUntil(new Promise(function(resolve, reject) {
	var message = {};
	message.tag = event.registration.tag;
	message.type = "one-off";
	client.postMessage(message);
	resolve(true);
    }));
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

self.oninstall = function(event) {
    console.log(event);
};
