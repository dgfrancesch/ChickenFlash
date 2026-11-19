var CACHE_NAME = "$(ProjectName)";
var CACHED_URLS = [
  "$(ProjectHTML)",
  $(FileList)
];

self.addEventListener('install', function(event) {
  event.waitUntil(
    caches.open(CACHE_NAME).then(function(cache) {
           return Promise.all(CACHED_URLS.filter(function(url) {
        return url.indexOf('Source/') !== 0;
      }).map(function(url) {
        return cache.add(url).catch(function(err) {
          console.warn('SW: no se pudo cachear', url);
        });
      }));
    }).then(function() { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function(event) {
  event.waitUntil(
    caches.keys().then(function(keys) {
      return Promise.all(keys.filter(function(k) { return k !== CACHE_NAME; })
                             .map(function(k) { return caches.delete(k); }));
    }).then(function() { return self.clients.claim(); })
  );
});

self.addEventListener('fetch', function(event) {
  if (event.request.method !== 'GET') return;
  event.respondWith(
    fetch(event.request).catch(function() {
      return caches.match(event.request).then(function(response) {
        if (response) return response;
        var accept = event.request.headers.get("accept") || "";
        if (accept.includes("text/html")) return caches.match("$(ProjectHTML)");
        return Response.error();
      });
    })
  );
});
