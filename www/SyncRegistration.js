var exec = require('cordova/exec');
var SyncManager = require('./SyncManager');

var SyncNetworkType = {
    any: -1,
    offline: 0,
    online: 1,
    non_mobile: 2
};

function SyncRegistration() {
    this.id = "";
    this.minDelay = 0;
    this.maxDelay = 0;
    this.minPeriod = 0;
    this.minRequiredNetwork = SyncNetworkType.online;
    this.allowOnBattery = true;
    this.idleRequired = false;
}

Object.freeze(SyncNetworkType);

module.exports = SyncRegistration;
module.exports.SyncNetworkType = SyncNetworkType;
