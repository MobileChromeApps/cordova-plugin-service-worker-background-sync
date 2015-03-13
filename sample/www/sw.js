this.onsync = function(event) {
    event.waitUntil(new Promise(function(resolve, reject) {
	var message = { name: 'syncEvent',
			data: {
			    name: event.registration.id
			}
		    };
	client.postMessage(message);
	resolve(true);
    }));
};
