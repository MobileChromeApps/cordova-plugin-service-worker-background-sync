var exec = require('cordova/exec');
var syncManager = require('./SyncManager');

SyncPermissionStatus = {
    default: 0,
    denied: 1,
    granted: 2
};

SyncNetworkType = {
    networkAny: -1,
    networkOffline: 0,
    networkOnline: 1,
    networkNonMobile: 2
};

Object.freeze(SyncPermissionStatus);
Object.freeze(SyncNetworkType);

module.exports = {
    SyncPermissionStatus: SyncPermissionStatus,
    SyncNetworkType: SyncNetworkType
};
