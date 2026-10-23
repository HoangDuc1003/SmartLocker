/* Area map: one pin per locker area on a Leaflet map (vendored in js/vendor/leaflet, no CDN).
   The street tiles come from OpenStreetMap and need the Internet. Without them the pins stay on the right
   places over a plain grid and a note says so, so the page still works offline.
   Usage (js/locker-map.js):  var map = AreaMap.create(element, { esc, tone, onSelect });
   map.update(areas, activeCode)  map.setUser({lat, lng, acc})  map.focus(code)  map.fitAll() */
(function () {
  'use strict';

  var TILE_URL = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  var ATTRIBUTION = '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">OpenStreetMap</a>';
  var reducedMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function hasCoords(a) {
    return a && typeof a.latitude === 'number' && typeof a.longitude === 'number';
  }

  function create(host, opts) {
    var L = window.L;
    var esc = opts.esc;
    var markers = {};          // area_code -> { marker, key }
    var active = null;
    var userMarker = null;
    var userCircle = null;
    var notice = document.createElement('p');
    var fitted = false;
    var placed = 0;

    if (!L) {
      host.innerHTML = '<p class="area-map__fallback">Không tải được thư viện bản đồ. Hãy chọn khu ở danh sách bên cạnh.</p>';
      return { update: function () { return 0; }, setUser: function () {}, focus: function () {},
               fitAll: function () {}, invalidate: function () {},
               hasUser: function () { return false; }, focusUser: function () {} };
    }

    var map = L.map(host, {
      zoomControl: true,
      attributionControl: true,
      scrollWheelZoom: false,                 // the page scrolls; zoom with the buttons, a double click or a pinch
      dragging: !L.Browser.mobile,            // one finger scrolls the page on a phone
      zoomSnap: 1,                // whole zoom levels only: a fractional scale shows seams between the tiles
      worldCopyJump: false
    });
    map.attributionControl.setPrefix(false);
    map.setView([10.8800, 106.7900], 13);     // before the first update: the VNU-HCM campus

    notice.className = 'area-map__notice';
    notice.setAttribute('role', 'status');
    notice.hidden = true;
    notice.textContent = 'Không tải được nền bản đồ (cần Internet). Các khu vẫn nằm đúng vị trí.';
    host.parentNode.insertBefore(notice, host.nextSibling);

    var loaded = 0;
    var failed = 0;
    var tiles = L.tileLayer(TILE_URL, { maxZoom: 19, attribution: ATTRIBUTION, crossOrigin: true });
    function setOffline(off) {
      host.classList.toggle('is-offline', off);
      notice.hidden = !off;
    }
    tiles.on('tileload', function () {
      loaded++;
      setOffline(false);
    });
    tiles.on('tileerror', function () {
      failed++;
      if (!loaded && failed >= 2) {
        setOffline(true);
      }
    });
    if (navigator.onLine === false) {
      setOffline(true);
    } else {
      tiles.addTo(map);
    }
    window.addEventListener('online', function () {
      loaded = 0;
      failed = 0;
      if (!map.hasLayer(tiles)) {
        tiles.addTo(map);
      } else {
        tiles.redraw();
      }
    });
    window.addEventListener('offline', function () {
      if (!loaded) {
        setOffline(true);
      }
    });

    L.control.scale({ imperial: false, position: 'bottomleft' }).addTo(map);

    function pinHtml(a, tone, isActive) {
      var name = isActive ? '<span class="pin__name">' + esc(a.name) + '</span>' : '';
      var alert = a.alert ? '<span class="pin__alert" aria-hidden="true">!</span>' : '';
      return '<div class="pin tone-' + tone.key + (isActive ? ' is-active' : '') + '">' +
        '<span class="pin__dot"><span class="pin__n">' + esc(a.available) + '</span>' + alert + '</span>' + name + '</div>';
    }

    function title(a, tone) {
      return a.name + ': trống ' + a.available + '/' + a.slot_count + ' ngăn, ' + tone.label;
    }

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
        var icon = L.divIcon({
          className: 'pin-wrap',
          html: pinHtml(a, tone, isActive),
          iconSize: [40, 48],
          iconAnchor: [20, 46]
        });
        var entry = markers[a.area_code];
        if (!entry) {
          var marker = L.marker([a.latitude, a.longitude], {
            icon: icon, title: title(a, tone), alt: title(a, tone), keyboard: true, riseOnHover: true
          });
          marker.on('click', function () {
            opts.onSelect(a.area_code);
          });
          marker.addTo(map);
          entry = markers[a.area_code] = { marker: marker };
        } else {
          entry.marker.setLatLng([a.latitude, a.longitude]);
          entry.marker.options.title = title(a, tone);   // before setIcon, which redraws the pin with the title
          entry.marker.setIcon(icon);
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
        fit(bounds, false);
        var entry = markers[activeCode];
        if (entry) {
          map.setView(entry.marker.getLatLng(), Math.max(map.getZoom(), 15), { animate: false });
        }
      }
      return placed;
    }

    function fit(bounds, animate) {
      if (bounds.length === 1) {
        map.setView(bounds[0], 16, { animate: animate && !reducedMotion });
      } else if (bounds.length > 1) {
        map.fitBounds(bounds, { padding: [48, 48], maxZoom: 17, animate: animate && !reducedMotion });
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

    function focus(code) {
      var entry = markers[code];
      if (!entry) {
        return;
      }
      var target = entry.marker.getLatLng();
      var zoom = Math.max(map.getZoom(), 16);
      if (reducedMotion) {
        map.setView(target, zoom, { animate: false });
      } else {
        map.flyTo(target, zoom, { duration: 0.7 });
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

    if (window.ResizeObserver) {
      new ResizeObserver(function () { map.invalidateSize(); }).observe(host);
    }

    return { update: update, setUser: setUser, focus: focus, fitAll: fitAll, invalidate: invalidate,
             hasUser: function () { return !!userMarker; },
             focusUser: function () { if (userMarker) { map.setView(userMarker.getLatLng(), Math.max(map.getZoom(), 16), { animate: !reducedMotion }); } } };
  }

  window.AreaMap = { create: create };
})();
