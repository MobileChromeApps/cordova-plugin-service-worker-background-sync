/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

Object.defineProperty(this, 'onsync', {
    configurable: false,
    enumerable: true,
    get: eventGetter('sync'),
    set: eventSetter('sync')
});

function SyncRegistration() {}

SyncRegistration.prototype.unregister = function() {
    CDVBackgroundSync_unregisterSync(this.id);
};

function SyncEvent() {
    ExtendableEvent.call(this, 'sync');
    this.registration = new SyncRegistration();
}

SyncEvent.prototype = Object.create(ExtendableEvent.prototype);
SyncEvent.constructor = SyncEvent;

FireSyncEvent = function(data) {
    var ev = new SyncEvent();
    ev.registration.id = data.id;
    ev.registration.minDelay = data.minDelay;
    ev.registration.maxDelay = data.maxDelay;
    ev.registration.minPeriod = data.minPeriod;
    ev.registration.minRequiredNetwork = data.minRequiredNetwork;
    ev.registration.allowOnBattery = data.allowOnBattery;
    ev.registration.idleRequired = data.idleRequired;
    dispatchEvent(ev);
    if(Array.isArray(ev._promises)) {
	return Promise.all(ev._promises).then(function(){
		sendSyncResponse(0, data.id);
	    },function(){
		sendSyncResponse(2, data.id);
	    });
    } else {
	sendSyncResponse(1, data.id);
	return Promise.resolve();
    }
};
