// Protemaxi Projetos — service worker (app instalável e abre offline)
const CACHE = "protemaxi-v2";
const SHELL = ["./", "index.html", "config.js", "manifest.webmanifest", "assets/capa.jpg", "assets/fundo.jpg", "assets/encerramento.jpg", "assets/selo.png", "assets/logo-protemaxi.jpg", "icon-192.png", "icon-512.png"];
self.addEventListener("install", e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL))); self.skipWaiting(); });
self.addEventListener("activate", e => { e.waitUntil(caches.keys().then(k => Promise.all(k.filter(n => n !== CACHE).map(n => caches.delete(n))))); self.clients.claim(); });
self.addEventListener("fetch", e => {
  const u = new URL(e.request.url);
  if (e.request.method !== "GET" || u.hostname.endsWith("supabase.co")) return; // dados sempre direto da nuvem
  e.respondWith(fetch(e.request).then(r => { if (r.ok && (u.origin === location.origin || /cdnjs|jsdelivr|fonts/.test(u.hostname))) { const c = r.clone(); caches.open(CACHE).then(x => x.put(e.request, c)); } return r; })
    .catch(() => caches.match(e.request).then(r => r || caches.match("index.html"))));
});
