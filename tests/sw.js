this.onsync = function(event) {
    event.waitUntil(new Promise(function(resolve, reject) {
	var message = {
			tag: event.registration.tag || "syncEvent"
		      };
	client.postMessage(message);
	resolve(true);
    }));
};

this.onperiodicsync = function(event) {
    console.log("Sw script onperiodicsync was invoked");
    event.waitUntil(new Promise(function(resolve, reject) {
	var message = {};
	message.tag = event.registration.tag;
	message.minPeriod = event.registration.minPeriod;
	message.networkState = event.registration.networkState;
	message.powerState = event.registration.powerState;
	client.postMessage(message);
	resolve(true);
    }));
};
