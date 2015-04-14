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
	clobberlog();
	navigator.serviceWorker.ready.then(function(swreg) {
	    document.getElementById("OOBtn").onclick = function () {
		var tag = document.getElementById("OOTagInput").value;
		swreg.sync.register({tag: tag}).then(function(reg) {
		    console.log("Registered " + reg.tag);
		}, function (err) {
		    console.log(err);
		});
	    };
	    document.getElementById("PBtn").onclick = function () {
		var tag = document.getElementById("PTagInput").value;
		var minPeriod = document.getElementById("minPeriod").value;
		var networkState = document.getElementById("networkState").value;
		var powerState = document.getElementById("powerState").value;
		swreg.periodicSync.register({
						tag: tag,
						minPeriod: minPeriod,
						networkState: networkState,
						powerState: powerState
					    }).then(
			function(reg) {
			    console.log("Registered " + reg.tag);
			}, function (err) {
			    console.log(err);
			});
	    };
	    document.getElementById("PUnregisterAll").onclick = function () {
		swreg.periodicSync.getRegistrations().then(function(regs) {
		    regs.forEach(function(reg) {
			console.log("Unregistering " + reg.tag);
			reg.unregister();
		    });
		});
	    };
	    window.addEventListener('message', function (event) {
		if (event.data.type === "one-off") {
		    console.log("Sync Event " + event.data.tag);
		    console.log("Unregistering " + event.data.tag);
		} else {
		    console.log("Periodic Sync Event " + event.data.tag);
		    console.log("Reregistering " + event.data.tag + " with minPeriod " + event.data.minPeriod);
		}
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

function newLog (arg) {
    var textArea = document.getElementById("console");
    textArea.value = timestamp() + ": " + arg + '\n' + textArea.value;
}

function clobberlog (arg) {
    var oldLog = Function.prototype.bind.call(console.log, console);
    console.log = function (arg) {
	oldLog(arg);
	newLog(arg);
    };
}

function timestamp () {
    var date = new Date();
    var ms = date.getMilliseconds();
    var s = date.getSeconds();
    var mi = date.getMinutes();
    var h = date.getHours();
    var d = date.getDate();
    var mo = date.getMonth() + 1;
    var y = date.getFullYear();
    function z (num) {
	return "" + (num < 10 ? "0" : "") + num;
    }
    return "" + y + ":" + z(mo) + ":" + z(d) + ":" + z(h) + ":" + z(mi) + ":" + z(s) + ":" + (ms < 100 ? "0" : "") + (ms < 10 ? "0" : "") + ms;
}

app.initialize();
