/*
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 *
 */

 exports.defineAutoTests = function () {

    describe('Background Sync (SyncManagers)', function () {
	it('service worker registration should have a SyncManager', function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.sync).toBeDefined();
		done();
	    });
	});
	it('service worker registration should have a PeriodicSyncManager', function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.periodicSync).toBeDefined();
		done();
	    });
	});
    });

    describe('Check SyncManager API', function () {
	it('sync.register() exists as a function', function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.sync.register).toBeDefined();
		expect(typeof swreg.sync.register == 'function').toBe(true);
		done();
	    });
	});
	it('sync.getRegistration() exists as a function', function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.sync.getRegistration).toBeDefined();
		expect(typeof swreg.sync.getRegistration == 'function').toBe(true);
		done();
	    });
	});
	it('sync.getRegistrations() exists as a function', function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.sync.getRegistrations).toBeDefined();
		expect(typeof swreg.sync.getRegistrations == 'function').toBe(true);
		done();
	    });
	});
	it('sync.permissionState() exists as a function', function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.sync.permissionState).toBeDefined();
		expect(typeof swreg.sync.permissionState == 'function').toBe(true);
		done();
	    });
	});
    });
    describe('Check PeriodicSyncManager API', function () {
	it('periodicSync.register() exists as a function', function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.periodicSync.register).toBeDefined();
		expect(typeof swreg.periodicSync.register == 'function').toBe(true);
		done();
	    });
	});
	it('periodicSync.getRegistration() exists as a function', function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.periodicSync.getRegistration).toBeDefined();
		expect(typeof swreg.periodicSync.getRegistration == 'function').toBe(true);
		done();
	    });
	});
	it('periodicSync.getRegistrations() exists as a function', function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.periodicSync.getRegistrations).toBeDefined();
		expect(typeof swreg.periodicSync.getRegistrations == 'function').toBe(true);
		done();
	    });
	});
	it('periodicSync.permissionState() exists as a function', function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.periodicSync.permissionState).toBeDefined();
		expect(typeof swreg.periodicSync.permissionState == 'function').toBe(true);
		done();
	    });
	});
	it('periodicSync.minPossiblePeriod exists as a number', function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.periodicSync.minPossiblePeriod).toBeDefined();
		expect(swreg.periodicSync.minPossiblePeriod).toEqual(jasmine.any(Number));
		done();
	    });
	});
    });

    describe('Check SyncManager Functionality', function () {
	var messageCallback;
	var swreg;
	var clearAllRegs = function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		swreg.sync.getRegistrations().then(function (regs) {
		    regs.forEach(function(reg) {
			reg.unregister();
		    });
		    done();
		},
		function (err) {
		    done();
		});
	    });
	};
	navigator.serviceWorker.ready.then(function (reg) {
	    swreg = reg;
	});
	beforeEach(function(done) {
	    clearAllRegs(done);
	});
	afterEach(function(done) {
	    clearAllRegs(done);
	    window.removeEventListener('message', messageCallback);
	});

	it('sync.permissionState returns granted', function (done) {
	    swreg.sync.permissionState().then(function (status) {
		expect(status).toEqual('granted');
		done();
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
	it('getRegistrations resolves empty list when nothing has been registered', function (done) {
	    swreg.sync.getRegistrations().then(function (regs) {
		expect(regs.length).toEqual(0);
		done();
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
	it('getRegistration rejects on empty list', function (done) {
	    swreg.sync.getRegistration('nonexistent').then(function () {
		expect(false).toBe(true);
		done();
	    },
	    function () {
		done();
	    });
	});
	it('empty registration creates instant sync', function (done) {
	    messageCallback = function() {
		done();
	    };
	    window.addEventListener('message', messageCallback);
	    swreg.sync.register().then(function () {
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
    });

    describe('Check PeriodicSyncManager Functionality', function () {
	var messageCallback;
	var swreg;
	var clearAllRegs = function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		swreg.periodicSync.getRegistrations().then(function (regs) {
		    regs.forEach(function(reg) {
			reg.unregister();
		    });
		    done();
		},
		function (err) {
		    done();
		});
	    });
	};
	navigator.serviceWorker.ready.then(function (reg) {
	    swreg = reg;
	});
	beforeEach(function(done) {
	    clearAllRegs(done);
	});
	afterEach(function(done) {
	    clearAllRegs(done);
	    window.removeEventListener('message', messageCallback);
	});

	it('periodicSync.permissionState returns granted', function (done) {
	    swreg.periodicSync.permissionState().then(function (status) {
		expect(status).toEqual('granted');
		done();
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
	it('getRegistrations with empty list', function (done) {
	    swreg.periodicSync.getRegistrations().then(function (regs) {
		expect(regs.length).toEqual(0);
		done();
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
	it('getRegistration rejects on empty list', function (done) {
	    swreg.periodicSync.getRegistration('nonexistent').then(function () {
		expect(false).toBe(true);
		done();
	    },
	    function () {
		done();
	    });
	});
	it('getRegistration rejects for nonexistent tag', function (done) {
	    swreg.periodicSync.register({tag:'exists', minPeriod: 10000000}).then(function () {
		swreg.periodicSync.getRegistration('nonexistent').then(function () {
		    expect(false).toBe(true);
		    done();
		},
		function () {
		    done();
		});
	    },
	    function () {
		expect(false).toBe(true);
		done();
	    });
	});
	it('Registing empty periodicSync should reject for lack of minPeriod', function (done) {
	    swreg.periodicSync.register().then(function() {
		expect(false).toBe(true);
		done();
	    }, function (err) {
		expect(err).toEqual('Invalid minPeriod');
		done();
	    });
	});
	it('register and getRegistrations with one element', function (done) {
	    swreg.periodicSync.register({'minPeriod':500000000}).then(function (regs) {
		swreg.periodicSync.getRegistrations().then(function (regs) {
		    expect(regs.length).toBe(1);
		    done();
		},
		function (err) {
		    expect(false).toBe(true);
		    done();
		});
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
	it('registrations received from getRegistrations .unregister()', function (done) {
	    swreg.periodicSync.register({'minPeriod':500000000}).then(function () {
		swreg.periodicSync.getRegistrations().then(function (regs) {
		    expect(regs.length).toBe(1);
		    regs.forEach(function(reg) {
			reg.unregister();
		    });
		    done();
		},
		function (err) {
		    expect(false).toBe(true);
		    done();
		});
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
	it('getRegistration resolves correct single registration', function (done) {
	    swreg.periodicSync.register({tag:'1', minPeriod: 10000000}).then(function () {
		swreg.periodicSync.register({tag:'2', minPeriod:100000000, networkState:'any', powerState:'avoid-draining'}).then(function () {
		    swreg.periodicSync.register({tag:'3', minPeriod: 10000000}).then(function () {
			swreg.periodicSync.getRegistrations().then(function (regs) {
			    expect(regs.length).toEqual(3);
			    swreg.periodicSync.getRegistration('2').then(function (reg) {
				expect(reg.tag).toEqual('2');
				expect(reg.minPeriod).toEqual(100000000);
				expect(reg.powerState).toEqual('avoid-draining');
				expect(reg.networkState).toEqual('any');
				done();
			    },
			    function () {
				expect(false).toBe(true);
				done();
			    });
			},
			function () {
			    expect(false).toBe(true);
			    done();
			});
		    },
		    function () {
			expect(false).toBe(true);
			done();
		    });
		},
		function () {
		    expect(false).toBe(true);
		    done();
		});
	    },
	    function () {
		expect(false).toBe(true);
		done();
	    });
	});
	it('same tag registrations get overwritten', function (done) {
	    messageCallback = function(event) {
		expect(event.data.tag).toEqual('test');
		expect(event.data.minPeriod).toEqual(2000);
		done();
	    };
	    window.addEventListener('message', messageCallback);
	    swreg.periodicSync.register({tag:'test', minPeriod:500000000}).then(function () {
		swreg.periodicSync.register({tag:'test', minPeriod:2000}).then(function () {
		    swreg.periodicSync.getRegistrations().then(function(regs) {
			expect(regs.length).toEqual(1);
		    },
		    function (err) {
			expect(false).toBe(true);
			done();
		    });
		},
		function (err) {
		    expect(false).toBe(true);
		    done();
		});
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
	it('empty tag registrations get overwritten', function (done) {
	    messageCallback = function(event) {
		expect(event.data.tag).toEqual('');
		expect(event.data.minPeriod).toEqual(2000);
		done();
	    };
	    window.addEventListener('message', messageCallback);
	    swreg.periodicSync.register({minPeriod:5000000000}).then(function () {
		swreg.periodicSync.register({minPeriod:2000}).then(function () {
		    swreg.periodicSync.getRegistrations().then(function(regs) {
			expect(regs.length).toEqual(1);
		    },
		    function (err) {
			expect(false).toBe(true);
			done();
		    });
		},
		function (err) {
		    expect(false).toBe(true);
		    done();
		});
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
    });

    describe('Verify Syncing and Batching', function () {
	var originalTimeout;
	var messageCallback;
	var swreg;
	var clearAllRegs = function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		swreg.periodicSync.getRegistrations().then(function (regs) {
		    regs.forEach(function(reg) {
			reg.unregister();
		    });
		    done();
		},
		function (err) {
		    done();
		});
	    });
	};
	navigator.serviceWorker.ready.then(function (reg) {
	    swreg = reg;
	});
	beforeEach(function(done) {
	    originalTimeout = jasmine.DEFAULT_TIMEOUT_INTERVAL;
	    jasmine.DEFAULT_TIMEOUT_INTERVAL = 10000;
	    clearAllRegs(done);
	});
	afterEach(function(done) {
	    jasmine.DEFAULT_TIMEOUT_INTERVAL = originalTimeout;
	    clearAllRegs(done);
	    window.removeEventListener('message', messageCallback);
	});
	it('batch short period periodicSync with longer period periodicSync', function (done) {
	    var periodicSyncCount = 0;
	    var instantDispatchTime;
	    messageCallback = function(event) {
		periodicSyncCount++;
		if (event.data.tag === 'short') {
		    expect(Date.now() - instantDispatchTime).toBeGreaterThan(2999);
		}
		if (event.data.tag === 'long') {
		    expect(periodicSyncCount).toEqual(2);
		    done();
		}
	    };
	    window.addEventListener('message', messageCallback);
	    instantDispatchTime = Date.now();
	    swreg.periodicSync.register({tag:'short', minPeriod:2000}).then(function () {
		swreg.periodicSync.register({tag:'long', minPeriod:3000}).then(function () {
		    swreg.periodicSync.getRegistrations().then(function (regs) {
			expect(regs.length).toEqual(2);
		    },
		    function () {
			expect(false).toBe(true);
		    });
		},
		function () {
		    expect(false).toBe(true);
		});
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
	it('short period periodicSync should fire without waiting for long period sync outside threshold', function (done) {
	    var periodicSyncCount = 0;
	    messageCallback = function(event) {
		periodicSyncCount++;
		expect(event.data.tag).toEqual('short');
		expect(periodicSyncCount).toEqual(1);
		done();
	    };
	    window.addEventListener('message', messageCallback);
	    swreg.periodicSync.register({tag:'long', minPeriod:24*3600*1000}).then(function (reg) {
		swreg.periodicSync.register({tag:'short', minPeriod:2000}).then(function () {
		    swreg.periodicSync.getRegistrations().then(function(regs) {
			expect(regs.length).toEqual(2);
		    });
		},
		function () {
		    expect(false).toBe(true);
		});
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
	it('periodic periodicSync reschedules with correct minPeriod', function (done) {
	    var periodicSyncCount = 0;
	    var initTime;
	    messageCallback = function(event) {
		periodicSyncCount++;
		if (periodicSyncCount == 1) {
		    expect(Date.now() - initTime).toBeLessThan(3100);
		    initTime = Date.now();
		}
		if (periodicSyncCount > 1) {
		    expect(Date.now() - initTime).toBeGreaterThan(3000);
		    initTime = Date.now();
		}
		if (periodicSyncCount == 3) {
		    swreg.periodicSync.getRegistrations().then(function (regs) {
			expect(regs.length).toEqual(1);
			done();
		    },
		    function () {
			expect(false).toBe(true);
			done();
		    });
		}
	    };
	    window.addEventListener('message', messageCallback);
	    initTime = Date.now();
	    swreg.periodicSync.register({tag:'periodic', minPeriod: 2222}).then(function (reg) {
		swreg.periodicSync.getRegistrations().then(function (regs) {
		    expect(regs.length).toEqual(1);
		},
		function () {
		    expect(false).toBe(true);
		});
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
    });
 };

 /* Manual Tests */

exports.defineManualTests = function (contentEl, createActionButton) {

};
