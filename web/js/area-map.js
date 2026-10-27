/* Area map: the full-screen Leaflet map of the locker page (vendored in js/vendor/leaflet, no CDN), one pin per area:
   a ring of free slots and a glass label with the name. The street tiles come from CARTO / OpenStreetMap and are kept
   in Cache Storage, so a tile seen (or prefetched) once also draws offline. With no tile at all the pins stay on the
   right places over a plain grid and a note says so, so the page still works offline.
   Usage (js/locker-map.js):  var map = AreaMap.create(element, { esc, tone, onSelect, padding, notice });
   The staff page (js/locker-map-staff.js) passes { classic: true } for its map card with round pins.
   padding() returns the px the islands cover ({ left, right, top, bottom }); flyTo and fitBounds keep pins out of them.
   map.update(areas, activeCode)  map.setUser({lat, lng, acc})  map.focus(code)  map.fitAll()  map.zoom(+1 | -1) */
(function () {
  'use strict';

  var OSM = '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap</a>';
  // tried in this order: some home routers (VNPT "iGate") do not resolve tile.openstreetmap.org, the mirrors still work.
  // A provider with a "dark" URL gets it in the dark theme; the others are inverted by css/locker-map.css.
  // (CARTO basemaps now answer every tile with an "API KEY REQUIRED" picture, so they are not used.)
  var PROVIDERS = [
    { light: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', attribution: OSM },
    { light: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png', attribution: OSM },
    { light: 'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png', subdomains: 'abc', attribution: OSM }
  ];
  var VIETNAM = { north: 23.4, south: 8.2, west: 102.1, east: 109.5 };
  var PREFETCH_VERSION = '1';
  var reducedMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function hasCoords(a) {
    return a && typeof a.latitude === 'number' && typeof a.longitude === 'number';
  }

  function isDark() {
    return window.SmartLockerTheme ? window.SmartLockerTheme.current() === 'dark'
      : !!(window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
  }

  function lngToX(lng, z) {
    return Math.floor((lng + 180) / 360 * Math.pow(2, z));
  }

  function latToY(lat, z) {
    var r = lat * Math.PI / 180;
    return Math.floor((1 - Math.log(Math.tan(r) + 1 / Math.cos(r)) / Math.PI) / 2 * Math.pow(2, z));
  }

  /* Tiles kept in Cache Storage (secure pages only: HTTPS or localhost). A tile is read from the cache first,
     else fetched and saved, so a tile seen once draws at once and without the Internet. */
  var TileStore = (function () {
    var NAME = 'sl-map-tiles-v2';
    var enabled = !!(window.caches && window.fetch && window.isSecureContext !== false);
    var opened = null;
    if (enabled) {
      // an older cache held the CARTO "API KEY REQUIRED" tiles
      window.caches.keys().then(function (names) {
        names.forEach(function (n) {
          if (n.indexOf('sl-map-tiles-') === 0 && n !== NAME) {
            window.caches.delete(n);
          }
        });
      }).catch(function () {});
    }

    function cache() {
      if (!opened) {
        opened = window.caches.open(NAME);
      }
      return opened;
    }

    // a blob: URL of the tile, or the plain URL when the cache cannot help (the <img> then loads or fails by itself)
    function src(url) {
      if (!enabled) {
        return Promise.resolve(url);
      }
      return cache().then(function (c) {
        return c.match(url).then(function (hit) {
          if (hit) {
            return hit.blob();
          }
          return fetch(url, { mode: 'cors', credentials: 'omit' }).then(function (res) {
            if (!res.ok) {
              throw new Error('HTTP ' + res.status);
            }
            c.put(url, res.clone());
            return res.blob();
          });
        });
      }).then(function (blob) {
        return URL.createObjectURL(blob);
      }).catch(function () {
        return url;
      });
    }

    // saves the tiles it does not have yet, four at a time; resolves true when every tile is saved
    function prefetch(urls) {
      if (!enabled) {
        return Promise.resolve(false);
      }
      return cache().then(function (c) {
        var i = 0;
        var ok = true;
        function next() {
          if (i >= urls.length) {
            return Promise.resolve();
          }
          var url = urls[i++];
          return c.match(url).then(function (hit) {
            return hit || fetch(url, { mode: 'cors', credentials: 'omit' }).then(function (res) {
              if (res.ok) {
                return c.put(url, res);
              }
              ok = false;
            });
          }).catch(function () {
            ok = false;
          }).then(next);
        }
        return Promise.all([next(), next(), next(), next()]).then(function () {
          return ok;
        });
      }).catch(function () {
        return false;
      });
    }

    return { enabled: enabled, src: src, prefetch: prefetch };
  })();

  function create(host, opts) {
    var L = window.L;
    var esc = opts.esc;
    var markers = {};          // area_code -> { marker, html }
    var active = null;
    var userMarker = null;
    var userCircle = null;
    var notice = opts.notice || null;
    var fitted = false;
    var placed = 0;

    if (!L) {
      host.innerHTML = '<p class="map-fallback">Không tải được thư viện bản đồ. Hãy chọn khu ở danh sách bên cạnh.</p>';
      return { update: function () { return 0; }, setUser: function () {}, focus: function () {},
               fitAll: function () {}, zoom: function () {}, invalidate: function () {},
               hasUser: function () { return false; }, focusUser: function () {} };
    }

    // a Leaflet tile layer whose <img> gets its picture through TileStore
    var CachedTileLayer = L.TileLayer.extend({
      createTile: function (coords, done) {
        var tile = document.createElement('img');
        var url = this.getTileUrl(coords);
        tile.alt = '';
        tile.setAttribute('role', 'presentation');
        L.DomEvent.on(tile, 'load', function () {
          if (tile.src.indexOf('blob:') === 0) {
            URL.revokeObjectURL(tile.src);
          }
        });
        L.DomEvent.on(tile, 'load', L.Util.bind(this._tileOnLoad, this, done, tile));
        L.DomEvent.on(tile, 'error', L.Util.bind(this._tileOnError, this, done, tile));
        TileStore.src(url).then(function (src) {
          tile.src = src;
        });
        return tile;
      }
    });

    // classic: the map card of the staff page (Leaflet buttons, page scroll wins over the wheel, round pins);
    // otherwise the full-screen glass map of the users (glass +/- buttons, pins with a ring and a label)
    var classic = !!opts.classic;
    var map = L.map(host, {
      zoomControl: classic,
      attributionControl: true,
      scrollWheelZoom: !classic,
      dragging: !classic || !L.Browser.mobile,   // on the staff page one finger scrolls the page
      zoomSnap: 1,                // whole zoom levels only: a fractional scale shows seams between the tiles
      worldCopyJump: false
    });
    map.attributionControl.setPrefix(false);
    if (classic) {
      L.control.scale({ imperial: false, position: 'bottomleft' }).addTo(map);
      notice = notice || document.createElement('p');
      notice.className = 'area-map__notice';
      notice.setAttribute('role', 'status');
      notice.hidden = true;
      notice.textContent = 'Không tải được nền bản đồ (cần Internet). Các khu vẫn nằm đúng vị trí.';
      host.parentNode.insertBefore(notice, host.nextSibling);
    } else {
      map.attributionControl.setPosition('bottomleft');
    }
    map.setView([10.8800, 106.7900], 13);     // before the first update: the VNU-HCM campus

    var PROVIDER_KEY = 'sl.tiles.provider';
    var provider = 0;          // index in PROVIDERS; moves on when one sends no tile at all
    try {
      // start with the host that worked last time on this browser (a blocked one costs a round of failed tiles)
      provider = Math.min(PROVIDERS.length - 1, Math.max(0, parseInt(window.localStorage.getItem(PROVIDER_KEY), 10) || 0));
    } catch (e) {
      provider = 0;
    }
    var loaded = 0;
    var failed = 0;
    var tiles = new CachedTileLayer(tileUrl(), {
      maxZoom: 19, attribution: PROVIDERS[provider].attribution, subdomains: PROVIDERS[provider].subdomains || 'abc'
    });
    function setOffline(off) {
      host.classList.toggle('is-offline', off);
      if (notice) {
        notice.hidden = !off;
      }
    }
    function tileUrl() {
      var p = PROVIDERS[provider];
      return isDark() && p.dark ? p.dark : p.light;
    }
    // a provider without its own dark tiles is inverted by css/locker-map.css in the dark theme
    function useProvider(i) {
      var p = PROVIDERS[i];
      provider = i;
      loaded = 0;
      failed = 0;
      host.classList.toggle('tiles-invert', !p.dark);
      tiles.options.subdomains = p.subdomains || 'abc';
      if (map.attributionControl) {
        map.attributionControl.removeAttribution(tiles.options.attribution);
        tiles.options.attribution = p.attribution;
        map.attributionControl.addAttribution(p.attribution);
      }
      tiles.setUrl(tileUrl());
    }
    tiles.on('tileload', function () {
      if (!loaded) {
        try {
          window.localStorage.setItem(PROVIDER_KEY, String(provider));
        } catch (e) {
          // private mode: the order is tried again next time
        }
      }
      loaded++;
      setOffline(false);
    });
    tiles.on('tileerror', function () {
      failed++;
      if (!loaded && failed >= 3) {
        // a blocked or broken host: try the next one (from the first again after the last), then give up
        var next = (provider + 1) % PROVIDERS.length;
        if (next !== startProvider) {
          useProvider(next);
        } else {
          setOffline(true);
        }
      }
    });
    var startProvider = provider;
    host.classList.toggle('tiles-invert', !PROVIDERS[provider].dark);
    tiles.addTo(map);   // offline, the tiles saved in Cache Storage still draw
    window.addEventListener('online', function () {
      startProvider = provider;
      useProvider(provider);
    });
    window.addEventListener('offline', function () {
      if (!loaded) {
        setOffline(true);
      }
    });
    // light / dark tiles follow the theme of the page
    document.addEventListener('sl-theme-change', function () {
      tiles.setUrl(tileUrl());
      prefetchLater();
    });
    if (window.matchMedia) {
      var darkQuery = window.matchMedia('(prefers-color-scheme: dark)');
      var onScheme = function () {
        if (!document.documentElement.getAttribute('data-theme')) {
          tiles.setUrl(tileUrl());
        }
      };
      if (darkQuery.addEventListener) {
        darkQuery.addEventListener('change', onScheme);
      }
    }

    // the glass islands drop their refraction while the map moves (css/locker-map.css body.map-moving): smoother panning
    map.on('movestart zoomstart', function () {
      document.body.classList.add('map-moving');
    });
    map.on('moveend zoomend', function () {
      document.body.classList.remove('map-moving');
    });

    /* "tải sẵn": once per browser and tile style, save the whole of Vietnam at low zoom and the areas at street zoom,
       so the next visit draws at once and works without the Internet. Street zooms of the whole country would be
       millions of tiles and break the providers' terms, so only the areas get them. */
    var prefetchTimer = null;
    var areaBox = null;
    function prefetchLater() {
      if (prefetchTimer || !TileStore.enabled || navigator.onLine === false ||
          (navigator.connection && navigator.connection.saveData)) {
        return;
      }
      prefetchTimer = setTimeout(function () {
        prefetchTimer = null;
        var template = tileUrl();
        var key = 'sl.tiles.prefetched.' + template;
        try {
          if (window.localStorage.getItem(key) === PREFETCH_VERSION) {
            return;
          }
        } catch (e) {
          // no storage: prefetch again, Cache Storage skips the tiles it has
        }
        var urls = [];
        tileRange(VIETNAM, 5, 8, template, urls);
        if (areaBox) {
          tileRange(areaBox, 12, 16, template, urls);
        }
        TileStore.prefetch(urls).then(function (ok) {
          if (ok) {
            try {
              window.localStorage.setItem(key, PREFETCH_VERSION);
            } catch (e) {
              // private mode: the cache is still filled
            }
          }
        });
      }, 4000);   // after the page and the first tiles
    }

    function tileRange(box, zMin, zMax, template, out) {
      var p = PROVIDERS[provider];
      var subs = p.subdomains || 'abc';
      for (var z = zMin; z <= zMax; z++) {
        var x0 = lngToX(box.west, z), x1 = lngToX(box.east, z);
        var y0 = latToY(box.north, z), y1 = latToY(box.south, z);
        for (var x = x0; x <= x1; x++) {
          for (var y = y0; y <= y1; y++) {
            out.push(L.Util.template(template, { s: subs[(x + y) % subs.length], z: z, x: x, y: y, r: '' }));
          }
        }
      }
    }

    // the islands over the map, in px
    function pad() {
      var p = opts.padding ? opts.padding() : null;
      return p || { left: 0, right: 0, top: 0, bottom: 0 };
    }

    // the map centre that shows latlng in the middle of the part the islands leave free
    function centerFor(latlng, zoom) {
      var p = pad();
      var shift = L.point((p.left - p.right) / 2, (p.top - p.bottom) / 2);
      return map.unproject(map.project(latlng, zoom).subtract(shift), zoom);
    }

    var PIN_SIZE = classic ? { iconSize: [40, 48], iconAnchor: [20, 46] } : { iconSize: [44, 44], iconAnchor: [22, 22] };

    function pinHtml(a, tone, isActive) {
      if (classic) {
        return '<div class="pin tone-' + tone.key + (isActive ? ' is-active' : '') + '">' +
          '<span class="pin__dot"><span class="pin__n">' + esc(a.available) + '</span>' +
          (a.alert ? '<span class="pin__alert" aria-hidden="true">!</span>' : '') + '</span>' +
          (isActive ? '<span class="pin__name">' + esc(a.name) + '</span>' : '') + '</div>';
      }
      var pct = a.slot_count ? Math.round(a.available * 100 / a.slot_count) : 0;
      return '<div class="pin tone-' + tone.key + (isActive ? ' is-active' : '') + '">' +
        '<span class="ring" style="--p:' + pct + '"><b>' + esc(a.available) + '</b></span>' +
        (a.alert ? '<span class="pin__alert" aria-hidden="true">!</span>' : '') +
        '<span class="pin__label">' + esc(a.name) + '</span></div>';
    }

    function title(a, tone) {
      return a.name + ': trống ' + a.available + '/' + a.slot_count + ' ngăn, ' + tone.label;
    }

    // two areas a few metres apart: the labels would cover each other, so a lower one hides its label
    function declutter() {
      if (classic) {
        return;   // the round pins show the name of the chosen area only
      }
      var codes = Object.keys(markers).sort(function (x, y) {
        return (x === active ? -1 : 0) - (y === active ? -1 : 0);
      });
      var taken = [];
      codes.forEach(function (code) {
        var node = markers[code].marker.getElement();
        var pin = node && node.querySelector('.pin');
        if (!pin) {
          return;
        }
        pin.classList.remove('is-crowded');
        var ring = pin.querySelector('.ring').getBoundingClientRect();
        var label = pin.querySelector('.pin__label').getBoundingClientRect();
        var box = { l: ring.left, t: Math.min(ring.top, label.top), r: label.right, b: Math.max(ring.bottom, label.bottom) };
        var hit = taken.some(function (o) {
          return box.l < o.r && box.r > o.l && box.t < o.b && box.b > o.t;
        });
        if (hit && code !== active) {
          pin.classList.add('is-crowded');
          taken.push({ l: ring.left, t: ring.top, r: ring.right, b: ring.bottom });
        } else {
          taken.push(box);
        }
      });
    }
    map.on('zoomend', declutter);

    function update(areas, activeCode) {
      active = activeCode;
      var seen = {};
      var bounds = [];
      areas.forEach(function (a) {
        if (!hasCoords(a)) {
          return;
        }
        seen[a.area_code] = true;
        bounds.push([a.latitude, a.longitude]);
        var tone = opts.tone(a);
        var isActive = a.area_code === activeCode;
        var html = pinHtml(a, tone, isActive);
        var entry = markers[a.area_code];
        if (!entry) {
          var marker = L.marker([a.latitude, a.longitude], {
            icon: L.divIcon({ className: 'pin-wrap', html: html, iconSize: PIN_SIZE.iconSize, iconAnchor: PIN_SIZE.iconAnchor }),
            title: title(a, tone), alt: title(a, tone), keyboard: true, riseOnHover: true
          });
          marker.on('click', function () {
            opts.onSelect(a.area_code);
          });
          marker.addTo(map);
          entry = markers[a.area_code] = { marker: marker, html: html };
        } else {
          entry.marker.setLatLng([a.latitude, a.longitude]);
          if (entry.html !== html) {
            // only when it changed: setIcon draws a new element and a focused pin would lose the focus
            entry.html = html;
            entry.marker.options.title = title(a, tone);   // before setIcon, which redraws the pin with the title
            entry.marker.setIcon(L.divIcon({ className: 'pin-wrap', html: html, iconSize: PIN_SIZE.iconSize, iconAnchor: PIN_SIZE.iconAnchor }));
          }
        }
        entry.marker.setZIndexOffset(isActive ? 1000 : 0);
      });
      Object.keys(markers).forEach(function (code) {
        if (!seen[code]) {
          map.removeLayer(markers[code].marker);
          delete markers[code];
        }
      });
      placed = bounds.length;
      if (placed && !fitted) {
        fitted = true;
        // the areas and about 2 km around them get the street zooms of the prefetch
        var lats = bounds.map(function (b) { return b[0]; });
        var lngs = bounds.map(function (b) { return b[1]; });
        areaBox = { north: Math.max.apply(null, lats) + 0.02, south: Math.min.apply(null, lats) - 0.02,
                    west: Math.min.apply(null, lngs) - 0.02, east: Math.max.apply(null, lngs) + 0.02 };
        prefetchLater();
        var first = markers[activeCode];
        if (first) {
          map.setView(centerFor(first.marker.getLatLng(), 16), 16, { animate: false });
        } else {
          fit(bounds, false);
        }
      }
      declutter();
      return placed;
    }

    function fit(bounds, animate) {
      if (bounds.length === 1) {
        map.setView(centerFor(L.latLng(bounds[0]), 16), 16, { animate: animate && !reducedMotion });
      } else if (bounds.length > 1) {
        var p = pad();
        map.fitBounds(bounds, {
          paddingTopLeft: [p.left + 40, p.top + 40],
          paddingBottomRight: [p.right + 40, p.bottom + 40],
          maxZoom: 17,
          animate: animate && !reducedMotion
        });
      }
    }

    function fitAll() {
      var bounds = Object.keys(markers).map(function (code) {
        return markers[code].marker.getLatLng();
      });
      if (userMarker) {
        bounds.push(userMarker.getLatLng());
      }
      fit(bounds, true);
    }

    function focusAt(latlng) {
      var zoom = Math.max(map.getZoom(), 16);
      var center = centerFor(latlng, zoom);
      if (reducedMotion) {
        map.setView(center, zoom, { animate: false });
      } else {
        map.flyTo(center, zoom, { duration: 0.7 });
      }
    }

    function focus(code) {
      var entry = markers[code];
      if (entry) {
        focusAt(entry.marker.getLatLng());
      }
    }

    function setUser(pos) {
      if (!pos) {
        return;
      }
      var ll = [pos.lat, pos.lng];
      if (!userMarker) {
        userCircle = L.circle(ll, { radius: 60, className: 'me-acc', interactive: false }).addTo(map);
        userMarker = L.marker(ll, {
          icon: L.divIcon({ className: 'pin-wrap', html: '<span class="me-dot" role="img" aria-label="Vị trí của bạn"></span>',
                            iconSize: [18, 18], iconAnchor: [9, 9] }),
          keyboard: false, interactive: false, zIndexOffset: 2000
        }).addTo(map);
      } else {
        userMarker.setLatLng(ll);
        userCircle.setLatLng(ll);
      }
      userCircle.setRadius(Math.min(Math.max(pos.acc || 60, 20), 500));
    }

    function invalidate() {
      map.invalidateSize();
    }

    return {
      update: update, setUser: setUser, focus: focus, fitAll: fitAll, invalidate: invalidate,
      zoom: function (step) {
        if (step > 0) {
          map.zoomIn();
        } else {
          map.zoomOut();
        }
      },
      hasUser: function () { return !!userMarker; },
      focusUser: function () {
        if (userMarker) {
          focusAt(userMarker.getLatLng());
        }
      }
    };
  }

  window.AreaMap = { create: create };
})();
