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
cordova plugin rm org.apache.cordova.background-sync
```

##Sample App
To see this plugin in action, execute the CreateBackgroundSyncDemo script in a directory of your choice or run the following commands to create the sample app
```bash
cordova create BackgroundSyncDemo io.cordova.backgroundsyncdemo BackgroundSyncDemo
cd BackgroundSyncDemo
cordova platform add ios
cordova plugin add https://github.com/mwoghiren/cordova-plugin-serviceworker.git
cordova plugin add https://github.com/imintz/cordova-plugin-background-sync.git
cordova plugin add https://github.com/imintz/cordova-plugin-notification.git
mv 'plugins/org.apache.cordova.backgroundsync/sample/config.xml' 'config.xml'
mv 'plugins/org.apache.cordova.backgroundsync/sample/www/sw.js' 'www/sw.js'
mv 'plugins/org.apache.cordova.backgroundsync/sample/www/index.html' 'www/index.html'
mv 'plugins/org.apache.cordova.backgroundsync/sample/www/js/index.js' 'www/js/index.js'
mv 'plugins/org.apache.cordova.backgroundsync/sample/www/css/index.css' 'www/css/index.css'
cordova prepare
