function registerServiceWorker() {
    if (navigator.serviceWorker) {
      navigator.serviceWorker.register('sw.js',{scope:'/cordova-plugin-background-sync/'}).then(function(registration) {
	// Registration was successful
	console.log('ServiceWorker registration successful with scope: ', registration.scope);
	document.dispatchEvent(new Event('deviceready'));
      }).catch(function(err) {
	// registration failed :(
	console.log('ServiceWorker registration failed: ', err);
      });
    }
}

