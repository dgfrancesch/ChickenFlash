var CACHE_NAME = "ChickenFlash";
var CACHED_URLS = [
  "index.html",
  "Assets/apple-touch-icon.png",
  "Assets/favicon.ico",
  "Assets/favicon1.ico",
  "Assets/favicon2.ico",
  "Assets/fondo-comida.jpg",
  "Assets/icon-192.png",
  "Assets/icon-192_New1.png",
  "Assets/icon-512.png",
  "Assets/icon-512_New1.png",
  "Assets/icon-512-maskable.png",
  "Assets/logo.jpg",
  "Assets/logo.png",
  "Assets/logo-grande.jpg",
  "Assets/logo-grande.png",
  "Assets/mercaditologo.jpg",
  "ChickenFlash.js",
  "Source/Presentation/fLogin.html",
  "styles.css"
  ];

self.addEventListener('install', function(event) {
                event.waitUntil(
                                caches.open(CACHE_NAME).then(function(cache) {
                                return cache.addAll(CACHED_URLS);
                })
                                );
});


self.addEventListener('fetch',function(event) {
   event.respondWith(
     fetch(event.request).catch(function() {
                   return caches.match(event.request).then(function(response) {
       if (response) {
                                   return response;
       } else if (event.request.headers.get("accept").includes("text/html")) {
                                   return caches.match("index.html");
                   }
                   });
   })
                   );
});