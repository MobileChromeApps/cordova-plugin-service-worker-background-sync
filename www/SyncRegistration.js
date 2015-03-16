var exec = require('cordova/exec');
var SyncManager = require('./SyncManager');

function SyncRegistration() {
    this.id = "";
    this.minDelay = 0;
    this.maxDelay = 0;
    this.minPeriod = 0;
    this.minRequiredNetwork = SyncNetworkType.online;
    this.allowOnBattery = true;
    this.idleRequired = false;
}

module.exports = SyncRegistration;
