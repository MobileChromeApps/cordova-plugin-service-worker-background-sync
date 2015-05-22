function reportOneShot(registration) {
  var message = {};
  message.tag = registration.tag;
  message.type = "one-off";
  client.postMessage(message);
}

function reportPeriodic(registration) {
  var message = {};
  message.tag = registration.tag;
  message.minPeriod = registration.minPeriod;
  message.networkState = registration.networkState;
  message.powerState = registration.powerState;
  message.type = "periodic";
  client.postMessage(message);
}

this.onsync = function(event) {
  // Do we have ExtendableEvent support yet?
  if (event.WaitUntil) {
    // Yes! Do this asynchronously.
    event.waitUntil(new Promise(function(resolve, reject) {
      reportOneShot(event.registration);
      resolve(true);
    }));
  } else {
    // No :( Just report the event synchronously.
    reportOneShot(event.registration);
  }
};

this.onperiodicsync = function(event) {
  // Do we have ExtendableEvent support yet?
  if (event.WaitUntil) {
    // Yes! Do this asynchronously.
    event.waitUntil(new Promise(function(resolve, reject) {
      reportPeriodic(event.registration);
      resolve(true);
    }));
  } else {
    // No :( Just report the event synchronously.
    reportPeriodic(event.registration);
  }
};

self.oninstall = function(event) {
    console.log(event);
};
