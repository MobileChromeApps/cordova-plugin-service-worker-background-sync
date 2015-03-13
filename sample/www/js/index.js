/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
var app = {
    // Application Constructor
    initialize: function() {
        this.bindEvents();
    },
    // Bind Event Listeners
    //
    // Bind any events that are required on startup. Common events are:
    // 'load', 'deviceready', 'offline', and 'online'.
    bindEvents: function() {
        document.addEventListener('deviceready', this.onDeviceReady, false);
    },
    // deviceready Event Handler
    //
    // The scope of 'this' is the event. In order to call the 'receivedEvent'
    // function, we must explicitly call 'app.receivedEvent(...);'
    onDeviceReady: function() {
        app.receivedEvent('deviceready');
	navigator.serviceWorker.ready.then(function(swreg) {
	    var buttons = document.getElementsByClassName("btn");
	    var onclickf = function() {
		var id = this.id;
		var minNetworkRequired = id[id.length-1];
		var minDelay = Number(id.substring(3,5)) * 1000;
		var maxDelay = 0;
		if(id[id.length-2] !== "s") {
		    maxDelay = Number(id.substring(8, 10)) * 1000;
		}
		console.log("minRequiredNetwork: " + minNetworkRequired + ", minDelay: " + minDelay + ", maxDelay: " + maxDelay);
		swreg.syncManager.register({minDelay: minDelay, maxDelay: maxDelay, minRequiredNetwork: minNetworkRequired});
	    };
	    for(var i = 0; i < buttons.length; i++) {
		buttons[i].addEventListener("click", onclickf);
	    }
	    document.getElementById("syncOnCharging").addEventListener("click", function() {
		swreg.syncManager.register({minRequiredNetwork: 0, allowOnBattery: false});
	    });
	    document.getElementById("syncOnIdle").addEventListener("click", function() {
		swreg.syncManager.register({minRequiredNetwork: 0, idleRequired: true});
	    });
	    document.getElementById("customSync").addEventListener("click", function() {
		document.getElementById("mainPage").className = "page transition left";
		document.getElementById("customSyncPage").className = "page transition center";
	    });
	    document.getElementById("registerCustomSync").addEventListener("click", function() {
		document.getElementById("mainPage").className = "page transition center";
		document.getElementById("customSyncPage").className = "page transition right";
		registerCustomSync(swreg);
		resetCustomSyncPage();
	    });
	    document.getElementById("backCustomSync").addEventListener("click", function() {
		document.getElementById("mainPage").className = "page transition center";
		document.getElementById("customSyncPage").className = "page transition right";
		resetCustomSyncPage();
	    });
	    window.addEventListener('message', function(event) {
		console.log("received message from service worker");
		var message = event.data;
		var id = message.name;
		var b = new Notification(id);
	    });
	});
    },
    // Update DOM on a Received Event
    receivedEvent: function(id) {
        var parentElement = document.getElementById(id);
        var listeningElement = parentElement.querySelector('.listening');
        var receivedElement = parentElement.querySelector('.received');

        listeningElement.setAttribute('style', 'display:none;');
        receivedElement.setAttribute('style', 'display:block;');

        console.log('Received Event: ' + id);
    }
};

var registerCustomSync = function(swreg) {
    var id = document.getElementById("idInput").value;
    var minDelay = document.getElementById("minDelayInput").value;
    var maxDelay = document.getElementById("maxDelayInput").value;
    var minPeriod = document.getElementById("minPeriodInput").value;
    var minRequiredNetwork = document.getElementById("minRequiredNetworkInput").value;
    var allowOnBattery = document.getElementById("allowOnBatteryInput").checked;
    var idleRequired = document.getElementById("idleRequiredInput").checked;
    swreg.syncManager.register({
				id: id,
				minDelay: minDelay,
				maxDelay: maxDelay,
				minPeriod: minPeriod,
				minRequiredNetwork: minRequiredNetwork,
				allowOnBattery: allowOnBattery,
				idleRequired: idleRequired
			       }).then(function() {console.log("Success");}, function() {alert("Failed to Register Sync");});
};

var resetCustomSyncPage = function() {
    document.getElementById("idInput").value = "";
    document.getElementById("minDelayInput").value = 0;
    document.getElementById("maxDelayInput").value = 0;
    document.getElementById("minPeriodInput").value = 0;
    document.getElementById("minRequiredNetworkInput").value = 0;
    document.getElementById("allowOnBatteryInput").checked = true;
    document.getElementById("idleRequiredInput").checked = false;
};

app.initialize();
