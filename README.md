#Cordova Background Sync
Background Sync enables service worker applications to perform actions when certain conditions are achieved. For example, if you want your app to delay an action until a device has a wifi connection, you can use background sync to accomplish this. Here is an [explainer document](https://github.com/slightlyoff/BackgroundSync/blob/master/explainer.md) that goes into more detail about the purpose and usage of background sync.

##Plugin Status
Supported Platforms: iOS

##Installation
To add this plugin to your project, use the following command in your project directory
```
cordova plugin add https://github.com/imintz/cordova-plugin-background-sync.git
```
To remove this plugin, use the following command
```
cordova plugin rm cordova-plugin-background-sync
```

##Examples
Here are a few examples that outline the basic usage of background sync.
###Getting Service Worker Registration
```javascript
navigator.serviceWorker.ready.then(function (serviceWorkerRegistration) {  
    ... //Most of your background sync related code should go in here
}
```
###Checking Permission
In the iOS implementation of background sync, permission defaults to granted. However, the user can disable background refresh capabilities manually. If permission is denied, sync events can still be executed in the foreground, but no sync events will be executed while the app is idle or in the background.
```javascript
serviceWorkerRegistration.syncManager.hasPermission().then(function(permissionStatus) {
    if (permissionStatus == SyncPermissionStatus.granted) {
        // We have permission to use background sync!
    }
    if (permissionStatus == SyncPermissionStatus.denied) {
        // We don't have permission to use background sync,
        // You can try and prompt the user to turn iOS's background referesh back on
    }
});
```
###Registering Sync Events
You can register sync events from both the page and the service worker context. Check out [this explainer](https://github.com/slightlyoff/BackgroundSync/blob/master/explainer.md) for details about the registration options.
```javascript
serviceWorkerRegistration.syncManager.register(
{
    id: "exampleSync",                                   // default: empty string
    minDelay: 60 * 60 * 1000,                             // default: 0
    maxDelay: 0,                                          // default: 0
    minPeriod: 12 * 60 * 60 * 1000,                       // default: 0
    minRequiredNetwork: SyncNetworkType.networkNonMobile, // default: "network-online"
    allowOnBattery: true,                                 // default: true
    idleRequired: false                                   // default: false
}).then(function() { // Success
     // A sync event was successfully registered
},
function() { // Failure
     // There was a problem while registering a sync event
});
```
###Looking Up Sync Event Registrations
```javascript
// Get all sync event registrations
serviceWorkerRegistration.syncManager.getRegistrations().then(function(regs){
    regs.forEach(function(reg) {
        // Do something with the registrations
        ...
  
        // You can also unregister sync events
        reg.unregister();
    });
});
```
```javascript
// Get a specific sync event registration by Id
serviceWorkerRegistration.syncManager.getRegistration("exampleSync").then(function(reg) {
    // Do something with the registration
    console.log(reg.minDelay);
},
function(err) {
    // This id hasn't been registered
    console.log(err);
});
```
###Handling Sync Events
All sync events will be dispatched to the same ```onsync``` event handler in your service worker script. The event handler is passed an event object which has a registration property that contains all of the registration options of the sync registration that triggered this event.
```javascript
this.onsync = function(event) {
    if (event.registration.id === "exampleSync") {
        event.waitUntil(new Promise(function(resolve, reject) {
            var asyncCallback = function () {
                // This is asynchronous
                resolve();
            }
            someAsyncFunction(event.registration.id, asyncCallback);
        }));
    }
};
```
When you need to perform an asynchronous action inside the sync event handler, use ```event.waitUntil```. If a sync event is dispatched while your app is in the background, ```event.waitUntil``` will preserve your service worker until the promise it was given has been settled. If the promise is resolved, then the sync event is unregistered (unless it is periodic). If the promise is rejected, then the sync event is rescheduled with a pushback.

iOS limits background execution runtime to 30 seconds. So even when using ```event.waitUntil``` you should be aware that your process will be terminated if it takes too long.

##Sample App
To see this plugin in action, execute the CreateBackgroundSyncDemo script in a directory of your choice or run the following commands to create the sample app
```bash
cordova create BackgroundSyncDemo io.cordova.backgroundsyncdemo BackgroundSyncDemo
cd BackgroundSyncDemo
cordova platform add ios
cordova plugin add https://github.com/MobileChromeApps/cordova-plugin-serviceworker.git
cordova plugin add https://github.com/imintz/cordova-plugin-background-sync.git
cordova plugin add https://github.com/imintz/cordova-plugin-notification.git
mv 'plugins/cordova-plugin-background-sync/sample/config.xml' 'config.xml'
mv 'plugins/cordova-plugin-background-sync/sample/www/sw.js' 'www/sw.js'
mv 'plugins/cordova-plugin-background-sync/sample/www/index.html' 'www/index.html'
mv 'plugins/cordova-plugin-background-sync/sample/www/js/index.js' 'www/js/index.js'
mv 'plugins/cordova-plugin-background-sync/sample/www/css/index.css' 'www/css/index.css'
cordova prepare
```
