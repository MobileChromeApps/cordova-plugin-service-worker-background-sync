function report(message) {
  return clients.matchAll().then(
    function(clientList) {
      for (var client of clientList) {
        client.postMessage(message);
      }
    });
}

function reportOneShot(registration) {
  var message = {};
  message.tag = registration.tag;
  message.type = "one-off";
  return report(message);
}

function reportPeriodic(registration) {
  var message = {};
  message.tag = registration.tag;
  message.minPeriod = registration.minPeriod;
  message.networkState = registration.networkState;
  message.powerState = registration.powerState;
  message.type = "periodic";
  return report(message);
}

this.onsync = function(event) {
  // Do we have ExtendableEvent support yet?
  if (event.WaitUntil) {
    // Yes! Do this asynchronously.
    event.waitUntil(reportOneShot(event.registration));
  } else {
    // No :( Just report the event synchronously.
    reportOneShot(event.registration);
  }
};

this.onperiodicsync = function(event) {
  // Do we have ExtendableEvent support yet?
  if (event.WaitUntil) {
    // Yes! Do this asynchronously.
    event.waitUntil(reportPeriodic(event.registration));
  } else {
    // No :( Just report the event synchronously.
    reportPeriodic(event.registration);
  }
};

self.oninstall = function(event) {
    console.log(event);
};
