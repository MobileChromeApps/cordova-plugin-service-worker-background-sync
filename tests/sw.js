this.onsync = function(event) {
    event.waitUntil(new Promise(function(resolve, reject) {
	var message = {
			name: event.registration.id || "syncEvent",
			minDelay: event.registration.minDelay
		      };
	client.postMessage(message);
	resolve(true);
    }));
};
