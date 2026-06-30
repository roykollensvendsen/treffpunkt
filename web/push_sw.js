// Dedicated Web Push service worker (spec 0060).
//
// It handles ONLY push delivery and notification clicks. It has no `fetch`
// handler, so it caches nothing and cannot reintroduce the stale-build problem
// that `--pwa-strategy=none` and index.html guard against (ADR-0026 / spec 0027).

self.addEventListener('push', function (event) {
  var payload = {};
  try {
    payload = event.data ? event.data.json() : {};
  } catch (e) {
    payload = {};
  }
  var title = payload.title || 'Treffpunkt';
  var options = {
    body: payload.body || '',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    tag: payload.tag,
    data: { url: payload.url || './' },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var url =
    (event.notification.data && event.notification.data.url) || './';
  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then(function (windowClients) {
        for (var i = 0; i < windowClients.length; i++) {
          var client = windowClients[i];
          if ('focus' in client) {
            client.focus();
            if ('navigate' in client) {
              client.navigate(url);
            }
            return;
          }
        }
        if (self.clients.openWindow) {
          return self.clients.openWindow(url);
        }
      })
  );
});
