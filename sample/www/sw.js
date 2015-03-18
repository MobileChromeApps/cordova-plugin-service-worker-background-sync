this.onsync = function(event) {
    event.waitUntil(new Promise(function(resolve, reject) {
	var title = event.registration.id || "Sync Event";
	var notification = new Notification(title);
	resolve(true);
    }));
};
