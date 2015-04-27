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
	    document.getElementById('OOTagInput').oninput = function () { updateButtonText('OO'); };
	    document.getElementById('PTagInput').oninput = function () { updateButtonText('P'); };
	    document.getElementById('OORegister').onclick = function () { register('OO'); };
	    document.getElementById('OOUnregister').onclick = function () { unregister('OO'); };
	    document.getElementById('OOGet').onclick = function () { getRegistrations('OO'); };
	    document.getElementById('PRegister').onclick = function () { register('P'); };
	    document.getElementById('PUnregister').onclick = function () { unregister('P'); };
	    document.getElementById('PGet').onclick = function () { getRegistrations('P'); };
	    window.addEventListener('message', function (event) {
		if (event.data.type === 'one-off') {
		    console.log('Sync Event ' + event.data.tag);
		}
		if (event.data.type === 'one-off-success') {
		    console.log('Unregistering ' + event.data.tag);
		}
		if (event.data.type === 'one-off-fail') {
		    console.log('Failed to sync ' + event.data.tag);
		}
		if (event.data.type === 'periodic'){
		    console.log('Periodic Sync Event ' + event.data.tag);
		    console.log('Reregistering ' + event.data.tag + ' with minPeriod ' + event.data.minPeriod);
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

function register (prefix) {
    var tag = document.getElementById(prefix + 'TagInput').value;
    // When registering one-off syncs, these properties have no effect
    var minPeriod = document.getElementById('minPeriod').value;
    var networkState = document.getElementById('networkState').value;
    var powerState = document.getElementById('powerState').value;
    navigator.serviceWorker.ready.then(function (swreg) {
	var manager = prefix === 'OO' ? swreg.sync : swreg.periodicSync;
	manager.register({
			    tag: tag,
			    minPeriod: minPeriod,
			    networkState: networkState,
			    powerState: powerState
			}).then(
	function(reg) {
	    console.log('Registered ' + reg.tag);
	}, function (err) {
	    console.log(err);
	});
	document.getElementById(prefix + 'TagInput').value = '';
	updateButtonText(prefix);
    });
}

function unregister (prefix) {
    var tag = document.getElementById(prefix + 'TagInput').value;
    navigator.serviceWorker.ready.then(function (swreg) {
	var manager = prefix === 'OO' ? swreg.sync : swreg.periodicSync;
	if (tag !== '') {
	    manager.getRegistration(tag).then(function (reg) {
		console.log('Unregistering ' + reg.tag);
		reg.unregister();
	    }, function (err) {
		console.log(err);
	    });
	} else {
	    manager.getRegistrations().then(function(regs) {
		if (regs.length === 0) {
		    console.log('No registrations to unregister');
		}
		regs.forEach(function(reg) {
		    console.log('Unregistering ' + reg.tag);
		    reg.unregister();
		});
	    });
	}
	document.getElementById(prefix + 'TagInput').value = '';
	updateButtonText(prefix);
    });
}

function getRegistrations (prefix) {
    var tag = document.getElementById(prefix + 'TagInput').value;
    navigator.serviceWorker.ready.then(function (swreg) {
	var manager = prefix === 'OO' ? swreg.sync : swreg.periodicSync;
	if (tag !== '') {
	    manager.getRegistration(tag).then(function (reg) {
		console.log(tag + ': ' + objectToString(reg));
	    }, function (err) {
		console.log(err);
	    });
	} else {
	    manager.getRegistrations().then(function (regs) {
		if (regs.length === 0) {
		    console.log('No registrations to get');
		}
		regs.forEach(function (reg) {
		    console.log(reg.tag + ': ' + objectToString(reg));
		});
	    });
	}
	document.getElementById(prefix + 'TagInput').value = '';
	updateButtonText(prefix);
    });
}

function newLog (arg) {
    var textArea = document.getElementById('console');
    textArea.value = timestamp() + ': ' + arg + '\n' + textArea.value;
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
	return '' + (num < 10 ? '0' : '') + num;
    }
    return '' + y + ':' + z(mo) + ':' + z(d) + ':' + z(h) + ':' + z(mi) + ':' + z(s) + ':' + (ms < 100 ? '0' : '') + (ms < 10 ? '0' : '') + ms;
}

function objectToString (object) {
    var toPrint = '';
    for (var propertyName in object) {
	if (typeof object[propertyName] === 'function') {
	    continue;
	}
	if (propertyName[0] === '_') {
	    continue;
	}
	toPrint = toPrint + '\n\t' + propertyName + ': ' + object[propertyName];
    }
    return toPrint;
}

function updateButtonText (prefix) {
    if (document.getElementById(prefix + 'TagInput').value === '') {
	document.getElementById(prefix + 'Unregister').textContent = 'Unregister All';
	document.getElementById(prefix + 'Get').textContent = 'Get Registrations';
    } else {
	document.getElementById(prefix + 'Unregister').textContent = 'Unregister';
	document.getElementById(prefix + 'Get').textContent = 'Get Registration';
    }
}

app.initialize();
