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
	var originalTimeout;
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
	beforeEach(function(done) {
	    originalTimeout = jasmine.DEFAULT_TIMEOUT_INTERVAL;
	    jasmine.DEFAULT_TIMEOUT_INTERVAL = 10000;
	    clearAllRegs(done);
	});
	afterEach(function(done) {
	    jasmine.DEFAULT_TIMEOUT_INTERVAL = originalTimeout;
	    clearAllRegs(done);
	});

	it("getRegistrations with empty list", function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		swreg.syncManager.getRegistrations().then(function (regs) {
		    expect(false).toBe(true);
		},
		function (err) {
		    done();
		});
	    });
	});
	it("register and getRegistrations with one element", function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
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
	});
	it("registrations received from getRegistrations .unregister()", function (done) {
	    navigator.serviceWorker.ready.then(function (swreg) {
		swreg.syncManager.register({"minDelay":50000}).then(function (regs) {
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
	});
    });


 };

 /* Manual Tests */

exports.defineManualTests = function (contentEl, createActionButton) {

};
