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

    describe('Background Sync (syncManager)', function () {
	it("service worker registration should have a syncManager", function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.syncManager).toBeDefined();
		done();
	    });
	});
    });

    describe('Check Sync Manager API', function () {
	it(".register() exists as a function", function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.syncManager.register).toBeDefined();
		expect(typeof swreg.syncManager.register == 'function').toBe(true);
		done();
	    });
	});
	it(".getRegistrations() exists as a function", function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.syncManager.getRegistrations).toBeDefined();
		expect(typeof swreg.syncManager.getRegistrations == 'function').toBe(true);
		done();
	    });
	});
	it(".hasPermission() exists as a function", function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		expect(swreg.syncManager.hasPermission).toBeDefined();
		expect(typeof swreg.syncManager.hasPermission == 'function').toBe(true);
		done();
	    });
	});
    });

    describe('Check Sync Manager Functionality', function () {
	var messageCallback;
	var swreg;
	var clearAllRegs = function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		swreg.syncManager.getRegistrations().then(function (regs) {
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

	it("hasPermission returns granted", function (done) {
	    swreg.syncManager.hasPermission().then(function (status) {
		expect(status).toBeTruthy();
		expect(status).toEqual(2);
		done();
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
	it("getRegistrations with empty list", function (done) {
	    swreg.syncManager.getRegistrations().then(function (regs) {
		expect(false).toBe(true);
		done();
	    },
	    function (err) {
		done();
	    });
	});
	it("register and getRegistrations with one element", function (done) {
	    swreg.syncManager.register({"minDelay":50000}).then(function (regs) {
		swreg.syncManager.getRegistrations().then(function (regs) {
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
	it("registrations received from getRegistrations .unregister()", function (done) {
	    swreg.syncManager.register({"minDelay":50000}).then(function () {
		swreg.syncManager.getRegistrations().then(function (regs) {
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
	it("getRegistration resolves correct single registration", function (done) {
	    swreg.syncManager.register({id:"1", minDelay: 1000}).then(function () {
		swreg.syncManager.register({id:"2", minDelay: 1000, maxDelay: 2000, allowOnBattery: false, idleRequired: true}).then(function () {
		    swreg.syncManager.register({id:"3", minDelay: 1000}).then(function () {
			swreg.syncManager.getRegistrations().then(function (regs) {
			    expect(regs.length).toEqual(3);
			    swreg.syncManager.getRegistration('2').then(function (reg) {
				expect(reg.id).toEqual("2");
				expect(reg.maxDelay).toEqual(2000);
				expect(reg.minDelay).toEqual(1000);
				expect(reg.allowOnBattery).toBeFalsy();
				expect(reg.idleRequired).toBeTruthy();
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
	it("empty registration creates instant sync", function (done) {
	    messageCallback = function() {
		done();
	    };
	    window.addEventListener('message', messageCallback);
	    swreg.syncManager.register().then(function () {
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
	it("same id registrations get overwritten", function (done) {
	    messageCallback = function(event) {
		expect(event.data.minDelay).toEqual(0);
		done();
	    };
	    window.addEventListener('message', messageCallback);
	    swreg.syncManager.register({id:"test", minDelay:500}).then(function () {
		swreg.syncManager.register({id:"test"}).then(function () {
		    swreg.syncManager.getRegistrations().then(function(regs) {
			expect(regs.length).toEqual(1);
		    },
		    function (err) {
			expect(false).toBe(true);
		    });
		},
		function (err) {
		    expect(false).toBe(true);
		});
	    },
	    function (err) {
		expect(false).toBe(true);
		done();
	    });
	});
	it("empty id registrations get overwritten", function (done) {
	    messageCallback = function(event) {
		expect(event.data.minDelay).toEqual(0);
		done();
	    };
	    window.addEventListener('message', messageCallback);
	    swreg.syncManager.register({minDelay:500}).then(function () {
		swreg.syncManager.register().then(function () {
		    swreg.syncManager.getRegistrations().then(function(regs) {
			expect(regs.length).toEqual(1);
		    },
		    function (err) {
			expect(false).toBe(true);
		    });
		},
		function (err) {
		    expect(false).toBe(true);
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
		swreg.syncManager.getRegistrations().then(function (regs) {
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
	it("batch instant sync with short delayed sync", function (done) {
	    var syncCount = 0;
	    var instantDispatchTime;
	    messageCallback = function(event) {
		syncCount++;
		if (event.data.name === "instant") {
		    expect(Date.now() - instantDispatchTime).toBeGreaterThan(500);
		}
		if (syncCount == 2) {
		    // Ensure the registration list is empty
		    swreg.syncManager.getRegistrations().then(function (regs) {
			expect(false).toBe(true);
			done();
		    },
		    function () {
			done();
		    });
		}
	    };
	    window.addEventListener('message', messageCallback);
	    swreg.syncManager.register({id:"delayed", minDelay:500}).then(function () {
		instantDispatchTime = Date.now();
		swreg.syncManager.register({id:"instant"}).then(function () {
		    swreg.syncManager.getRegistrations().then(function (regs) {
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
	it("batch to prevent maxDelay form expiring", function (done) {
	    var syncCount = 0;
	    var maxTime, nomaxTime;
	    messageCallback = function(event) {
		syncCount++;
		if (event.data.name === "max") {
		    maxTime = Date.now();
		    expect(nomaxTime).toBeUndefined();
		}
		if (event.data.name === "nomax") {
		    nomaxTime = Date.now();
		    expect(nomaxTime - maxTime).toBeGreaterThan(30);
		}
		if (syncCount == 2) {
		    // Ensure the registration list is empty
		    swreg.syncManager.getRegistrations().then(function (regs) {
			expect(false).toBe(true);
			done();
		    },
		    function () {
			done();
		    });
		}
	    };
	    window.addEventListener('message', messageCallback);
	    swreg.syncManager.register({id:"max", minDelay:100, maxDelay:200}).then(function () {
		swreg.syncManager.register({id:"nomax", minDelay: 230}).then(function () {
		    swreg.syncManager.getRegistrations().then(function (regs) {
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
	it("expired sync should unregister without firing", function (done) {
	    var syncCount = 0;
	    messageCallback = function(event) {
		syncCount++;
		expect(event.data.name).toEqual("Nomax");

		// Ensure the registration list is empty
		swreg.syncManager.getRegistrations().then(function (regs) {
		    expect(false).toBe(true);
		    done();
		},
		function () {
		    done();
		});
	    };
	    window.addEventListener('message', messageCallback);
	    swreg.syncManager.register({id:"Max", maxDelay:200, allowOnBattery: false}).then(function (reg) {
		swreg.syncManager.register({id:"Nomax", minDelay: 230}).then(function () {
		    swreg.syncManager.getRegistrations().then(function (regs) {
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
	it("immediate sync should fire without waiting for long delay outside threshold", function (done) {
	    var syncCount = 0;
	    messageCallback = function(event) {
		syncCount++;
		expect(event.data.name).toEqual("immediate");
		expect(syncCount).toEqual(1);
		swreg.syncManager.getRegistrations().then(function (regs) {
		    expect(regs.length).toEqual(1);
		    done();
		},
		function () {
		    expect(false).toBe(true);
		    done();
		});
	    };
	    window.addEventListener('message', messageCallback);
	    swreg.syncManager.register({id:"longSync", minDelay:35*60*1000}).then(function (reg) {
		swreg.syncManager.register({id:"immediate"}).then(function () {
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
	it("periodic sync reschedules with correct minPeriod", function (done) {
	    var syncCount = 0;
	    var initTime;
	    messageCallback = function(event) {
		syncCount++;
		if (syncCount == 1) {
		    expect(Date.now() - initTime).toBeLessThen(200);
		    initTime = Date.now();
		}
		if (syncCount > 1) {
		    expect(Date.now() - initTime).toBeGreaterThan(200);
		    initTime = Date.now();
		}
		if (syncCount == 3) {
		    swreg.syncManager.getRegistrations().then(function (regs) {
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
	    swreg.syncManager.register({id:"periodic", minPeriod: 200}).then(function (reg) {
		swreg.syncManager.getRegistrations().then(function (regs) {
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
