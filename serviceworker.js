var CACHE_NAME = "$(ProjectName)";
var CACHED_URLS = [
  "$(ProjectHTML)",
  $(FileList)
];

var VERSION = "2";   // súbelo (3, 4...) para obligar a todos los dispositivos a bajar todo de nuevo
var CACHE = CACHE_NAME + "-v" + VERSION;
var ROOT = self.registration.scope;                       // p. ej. https://chickenflash.pages.dev/
var HOME = new URL("$(ProjectHTML)", ROOT).href;          // .../index.html

// Archivos que el index.html carga pero que la lista automatica de TMS puede no incluir.
// Si alguno no existe, se ignora.
var EXTRA_URLS = [
  "$(ProjectName).js",
  "styles.css",
  "Css/dashboard.css",
  "Css/uShell.css",
  "Css/Inventario.css",
  "Css/addProduct.css",
  "Css/secciones.css",
  "Assets/favicon2.ico",
  "Assets/apple-touch-icon.png",
  "Assets/icon-64.png",
  "Assets/icon-256.png",
  "Assets/icon-512.png"
];

// Datos de Supabase: NO se guardan aquí, la app los guarda aparte (uHttp)
function esApi(url) {
  return /\/(rest|auth|functions|realtime)\/v1\//.test(url);
}

// Cloudflare responde /index.html con una redirección a "/". Una respuesta
// redirigida NO se puede entregar a una navegación, así que se guarda "limpia".
function limpia(res) {
  if (!res || !res.redirected) return Promise.resolve(res);
  return res.blob().then(function (b) {
    return new Response(b, { status: 200, statusText: 'OK', headers: res.headers });
  });
}

function guardar(cache, url) {
  return fetch(new Request(url, { cache: 'reload' })).then(function (res) {
    if (!res.ok) throw new Error(res.status);
    return limpia(res).then(function (c) { return cache.put(url, c); });
  }).catch(function () {
    console.warn('SW: no se pudo cachear', url);
  });
}

self.addEventListener('install', function (event) {
  event.waitUntil(
    caches.open(CACHE).then(function (cache) {
      var urls = CACHED_URLS.filter(function (url) {
        return url.indexOf('Source/') !== 0;
      }).concat(EXTRA_URLS, [ROOT, HOME]);
      // uno por uno: si un archivo falla, los demás se guardan igual
      return Promise.all(urls.map(function (url) { return guardar(cache, url); }));
    }).then(function () { return self.skipWaiting(); })
  );
});

self.addEventListener('activate', function (event) {
  event.waitUntil(
    caches.keys().then(function (keys) {
      // solo borra versiones viejas de ESTA app (el origen puede alojar otras)
      return Promise.all(keys
        .filter(function (k) { return k.indexOf(CACHE_NAME) === 0 && k !== CACHE; })
        .map(function (k) { return caches.delete(k); }));
    }).then(function () { return self.clients.claim(); })
  );
});

// Abrir la app (cualquier ruta #/...): la página guardada al instante, y se actualiza detrás
function paginaInicial() {
  return caches.open(CACHE).then(function (cache) {
    return cache.match(ROOT).then(function (hit) {
      return hit || cache.match(HOME);
    }).then(function (hit) {
      var red = fetch(ROOT).then(limpia).then(function (res) {
        if (res && res.ok) cache.put(ROOT, res.clone());
        return res;
      }).catch(function () { return hit || Response.error(); });
      return hit || red;
    });
  });
}

// JS, CSS, iconos, fuentes, fotos: lo guardado al instante, y se actualiza detrás
function guardadoYActualiza(peticion) {
  return caches.open(CACHE).then(function (cache) {
    return cache.match(peticion, { ignoreSearch: true }).then(function (hit) {
      var red = fetch(peticion).then(function (res) {
        if (res && (res.ok || res.type === 'opaque')) cache.put(peticion, res.clone());
        return res;
      }).catch(function () { return hit || Response.error(); });
      return hit || red;
    });
  });
}

self.addEventListener('fetch', function (event) {
  var req = event.request;
  if (req.method !== 'GET') return;
  if (!/^https?:/.test(req.url)) return;
  if (esApi(req.url)) return;

  if (req.mode === 'navigate') {
    event.respondWith(paginaInicial());
    return;
  }
  event.respondWith(guardadoYActualiza(req));
});
