# Cordova Background Sync
Background Sync enables service worker applications to perform actions when certain conditions are achieved. For example, if you want your app to delay an action until a device has a wifi connection, you can use background sync to accomplish this. Here is an [explainer document](https://github.com/slightlyoff/BackgroundSync/blob/master/explainer.md) that goes into more detail about the purpose and usage of background sync.

## Plugin Status
Supported Platforms: iOS

## Installation
To add this plugin to your project, you can use the following cordova cli command
```
cordova plugin add https://github.com/MobileChromeApps/cordova-plugin-service-worker-background-sync.git
```

or, to install from npm:
```
cordova plugin add cordova-plugin-service-worker-background-sync
```

To remove this plugin, use the following command
```
cordova plugin rm cordova-plugin-service-worker-background-sync
```

Note: For background sync to work properly, you must first install the cordova [service worker plugin](https://github.com/MobileChromeApps/cordova-plugin-service-worker) before installing the background sync plugin.

## Preferences
You can specify custom plugin preferences in your project's config.xml. This is similar to how you specify your service worker script.

```xml
<preference name="minperiod" value="2000"></preference>         // Default: 1 hour
<preference name="syncpushback" value="1200"></preference>      // Default: 5 minutes
<preference name="syncmaxwaittime" value="5000"></preference>   // Default: 2 hours
```
All three times are given in miliseconds.
- `minperiod` specifies the minimum amount of time between repetitions of a periodic sync. Registration of a periodic sync will fail if the `minPeriod` property of the registration is less than this preference value. In the background sync spec, this value is known as `minPossiblePeriod` and is accessible in JavaScript as a property of the `PeriodicSyncManager`.
- `syncpushback` is the minimum amount of time a viable one-off or periodic sync will wait after failing before being reassessed.
- `syncmaxwaittime` is the maximum amount of time past the expiration of its minimum period that a periodic sync event will wait to be batched with other periodic sync events. This can prevent a periodic sync meant to happen daily from waiting for a periodic sync scheduled to take place weekly.

## Examples
Here are a few examples that outline the basic usage of background sync.
### Getting Service Worker Registration
```javascript
navigator.serviceWorker.ready.then(function (serviceWorkerRegistration) {  
    ... //Most of your background sync related code should go in here
}
```
### Checking Permission
In the iOS implementation of background sync, permission defaults to granted. However, the user can disable background refresh capabilities manually. If permission is denied, sync events can still be executed in the foreground, but no sync events will be executed while the app is idle or in the background.
```javascript
serviceWorkerRegistration.sync.permissionState().then(function(permissionState) {
    if (permissionState === "granted") {
        // We have permission to use background sync!
    }
    if (permissionState === "denied") {
        // We don't have permission to use background sync,
        // You can try and prompt the user to turn iOS's background referesh back on
    }
});
```
### Registering Sync Events
You can register sync events from both the page and the service worker context. Check out [this explainer](https://github.com/slightlyoff/BackgroundSync/blob/master/explainer.md) for details about the registration options.

#### For One-off Sync Events
```javascript
serviceWorkerRegistration.sync.register(
{
    tag: "exampleSync"  // A name used for retrieving or updating sync events, default: empty string
}).then(function() { // Success
     // A sync event was successfully registered
},
function() { // Failure
     // There was a problem while registering a sync event
});
```
#### For Periodic Sync Events
```javascript
serviceWorkerRegistration.periodicSync.register(
{
    tag: "examplePeriodicSync",     // A name used for retrieving or updating sync events, default: empty string
    minPeriod: 50000,               // Delay between sync events repetition
    networkState: "avoid-cellular", // The minimum required network type for your sync event
    powerState: "avoid-draining"    // Whether or not to fire sync events while on battery
}).then(function() { // Success
     // A sync event was successfully registered
},
function() { // Failure
     // There was a problem while registering a sync event
});
```

### Looking Up Sync Event Registrations
```javascript
// Get all sync event registrations
serviceWorkerRegistration.sync.getRegistrations().then(function(regs){
    regs.forEach(function(reg) {
        // Do something with the registrations
        ...
  
        // You can also unregister sync events
        reg.unregister();
    });
});

serviceWorkerRegistration.periodicSync.getRegistrations().then(function(regs){
    regs.forEach(function(reg) {
        // Do something with the registrations
        ...
  
        // You can also unregister sync events
        reg.unregister();
    });
});
```
```javascript
// Get a specific sync event registration by its Tag
serviceWorkerRegistration.sync.getRegistration("exampleSync").then(function(reg) {
    // Do something with the registration
    console.log(reg.minDelay);
},
function(err) {
    // This id hasn't been registered
    console.log(err);
});

serviceWorkerRegistration.periodicSync.getRegistration("examplePeriodicSync").then(function(reg) {
    // Do something with the registration
    console.log(reg.minDelay);
},
function(err) {
    // This id hasn't been registered
    console.log(err);
});
```
### Handling Sync Events
All sync events will be dispatched to the same ```onsync``` event handler in your service worker script. All periodic sync events will be dispatched to the same ```onperiodicsync``` event handler. These event handlers are passed an event object which has a registration property that contains all of the registration options of the sync registration that triggered this event.
#### One-off Sync Event
```javascript
this.onsync = function(event) {
    if (event.registration.id === "exampleSync") {
        event.waitUntil(new Promise(function(resolve, reject) {
            var asyncCallback = function () {
                // This is asynchronous
                resolve();
            }
            someAsyncFunction(event.registration.id, asyncCallback);
            // One-off sync events are automatically unregistered after completion
        }));
    }
};
```
#### Periodic Sync Event
```javascript
this.onperiodicsync = function(event) {
    if (event.registration.id === "examplePeriodicSync") {
        event.waitUntil(new Promise(function(resolve, reject) {
            var asyncCallback = function () {
                // This is asynchronous
                resolve();
            }
            someAsyncFunction(event.registration.id, asyncCallback);
            if (somethingHappened()) {
                // You can unregister a periodic sync from within its event handler
                // Otherwise, the sync event will be rescheduled after completion
                event.registration.unregister();
            }
        }));
    }
};
```
When you need to perform an asynchronous action inside the sync event handler, use ```event.waitUntil```. If a sync event is dispatched while your app is in the background, ```event.waitUntil``` will preserve your service worker until the promise it was given has been settled. If the promise is resolved, then the sync event is unregistered (unless it is periodic). If the promise is rejected, then the sync event is rescheduled with a pushback.

iOS limits background execution runtime to 30 seconds. So even when using ```event.waitUntil``` you should be aware that your process will be terminated if it takes too long.

## Sample App
To see this plugin in action, execute the CreateBackgroundSyncDemo script in a directory of your choice or run the following commands to create the sample app
```bash
cordova create BackgroundSyncDemo io.cordova.backgroundsyncdemo BackgroundSyncDemo
cd BackgroundSyncDemo
cordova platform add ios
cordova plugin add cordova-plugin-service-worker
cordova plugin add cordova-plugin-service-worker-background-sync
mv 'plugins/cordova-plugin-service-worker-background-sync/sample/config.xml' 'config.xml'
mv 'plugins/cordova-plugin-service-worker-background-sync/sample/www/sw.js' 'www/sw.js'
mv 'plugins/cordova-plugin-service-worker-background-sync/sample/www/index.html' 'www/index.html'
mv 'plugins/cordova-plugin-service-worker-background-sync/sample/www/js/index.js' 'www/js/index.js'
mv 'plugins/cordova-plugin-service-worker-background-sync/sample/www/css/index.css' 'www/css/index.css'
cordova prepare
```

## 1.0.1 (April 30, 2015)
* Updated installation instructions

## 1.0.0 (April 29, 2015)
* Initial release
