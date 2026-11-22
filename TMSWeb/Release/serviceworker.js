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
  "Assets/icon-256.png",
  "Assets/icon-512.png",
  "Assets/icon-512_New1.png",
  "Assets/icon-512-maskable.png",
  "Assets/icon-64.png",
  "Assets/logo.jpg",
  "Assets/logo.png",
  "Assets/logo-grande.jpg",
  "Assets/logo-grande.png",
  "Assets/logo-web.webp",
  "Assets/mercaditologo.jpg",
  "ChickenFlash.js",
  "Css/addProduct.css",
  "Css/dashboard.css",
  "Css/Inventario.css",
  "Css/secciones.css",
  "Css/uShell.css",
  "Fonts/PlusJakartaSans-Italic-VariableFont_wght.ttf",
  "Fonts/PlusJakartaSans-VariableFont_wght.ttf",
  "Fonts/RadioCanadaBig-Italic-VariableFont_wght.ttf",
  "Fonts/RadioCanadaBig-VariableFont_wght.ttf",
  "Source/Presentation/fAddProduct.html",
  "Source/Presentation/fDashboard.html",
  "Source/Presentation/fInventory.html",
  "Source/Presentation/fLogin.html",
  "Source/Presentation/fSecciones.html",
  "styles.css"
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
        if (accept.includes("text/html")) return caches.match("index.html");
        return Response.error();
      });
    })
  );
});
