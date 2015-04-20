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

Object.defineProperty(this, 'onperiodicsync', {
    configurable: false,
    enumerable: true,
    get: eventGetter('periodicsync'),
    set: eventSetter('periodicsync')
});

function SyncEvent() {
    ExtendableEvent.call(this, 'sync');
    this.registration = new SyncRegistration();
}

function PeriodicSyncEvent() {
    ExtendableEvent.call(this, 'periodicsync');
    this.registration = new PeriodicSyncRegistration();
}

SyncEvent.prototype = Object.create(ExtendableEvent.prototype);
SyncEvent.constructor = SyncEvent;

PeriodicSyncEvent.prototype = Object.create(ExtendableEvent.prototype);
PeriodicSyncEvent.constructor = PeriodicSyncEvent;

function FireSyncEvent(data) {
    var ev = new SyncEvent();
    ev.registration.tag = data.tag;
    dispatchEvent(ev);
    if(Array.isArray(ev._promises)) {
	Promise.all(ev._promises).then(function(){
		sendSyncResponse(0, data.tag);
	    },function(){
		sendSyncResponse(2, data.tag);
	    });
    } else {
	sendSyncResponse(1, data.tag);
    }
}

function FirePeriodicSyncEvent(data) {
    var ev = new PeriodicSyncEvent();
    ev.registration.tag = data.tag;
    ev.registration.minPeriod = data.minPeriod;
    ev.registration.networkState = data.networkState;
    ev.registration.powerState = data.powerState;
    dispatchEvent(ev);
    if(Array.isArray(ev._promises)) {
    Promise.all(ev._promises).then(function(){
		sendPeriodicSyncResponse(0, data.tag);
	    },function(){
		sendPeriodicSyncResponse(2, data.tag);
	    });
    } else {
	sendPeriodicSyncResponse(1, data.tag);
    }
}
