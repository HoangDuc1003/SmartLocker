/* Mapbox GL version of the users' map (js/vendor/mapbox), same methods as the Leaflet map of js/area-map.js, which picks it
   when the page has a token. The pins are the same HTML, so css/locker-map.css and the waves of the user's locker do not
   care which map draws them. fail() is called when Mapbox cannot draw (bad token, no style): area-map.js goes on with Leaflet. */
(function () {
  'use strict';

  var STREET_ZOOM = 15.5;     // about the street zoom 16 of the raster map: GL tiles are twice as big
  var LOAD_TIMEOUT_MS = 8000;
  var reducedMotion = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function hasCoords(a) {
    return a && typeof a.latitude === 'number' && typeof a.longitude === 'number';
  }

  function isDark() {
    return window.SmartLockerTheme ? window.SmartLockerTheme.current() === 'dark'
      : !!(window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches);
  }

  function token(name) {
    return window.getComputedStyle(document.documentElement).getPropertyValue(name).trim();
  }

  // a circle in metres as a GeoJSON polygon (the accuracy of the position)
  function circle(lat, lng, metres) {
    var ring = [];
    var dLat = metres / 111320;
    var dLng = dLat / Math.cos(lat * Math.PI / 180);
    for (var i = 0; i <= 48; i++) {
      var t = i / 48 * 2 * Math.PI;
      ring.push([lng + dLng * Math.cos(t), lat + dLat * Math.sin(t)]);
    }
    return { type: 'Feature', properties: {}, geometry: { type: 'Polygon', coordinates: [ring] } };
  }

  function create(host, opts, fail) {
    var gl = window.mapboxgl;
    var shared = window.AreaMap;
    var markers = {};          // area_code -> { marker, node, html }
    var userMarker = null;
    var userPos = null;
    var routeLine = null;      // [[lng, lat], [lng, lat]] or null
    var fitted = false;
    var loaded = false;
    var dead = false;
    var timer = null;

    gl.accessToken = opts.mapbox.token;
    var map = new gl.Map({
      container: host,
      style: styleUrl(),
      center: [106.79, 10.88],   // before the first update: the VNU-HCM campus
      zoom: 12,
      projection: 'mercator',
      logoPosition: 'bottom-right',
      dragRotate: false,
      pitchWithRotate: false,
      touchPitch: false
    });
    map.touchZoomRotate.disableRotation();

    function styleUrl() {
      return isDark() ? opts.mapbox.dark : opts.mapbox.light;
    }

    function giveUp() {
      if (dead) {
        return;
      }
      dead = true;
      clearTimeout(timer);
      document.body.classList.remove('map-moving');
      try {
        map.remove();
      } catch (e) {
        // already broken: Leaflet takes the element over anyway
      }
      host.innerHTML = '';
      fail();
    }

    timer = setTimeout(giveUp, LOAD_TIMEOUT_MS);
    map.on('load', function () {
      loaded = true;
      clearTimeout(timer);
    });
    map.on('error', function (e) {
      var status = e.error && e.error.status;
      // a tile error has a sourceId and heals by itself; a refused token or a missing style draws nothing, ever
      if (status === 401 || status === 403 || (!loaded && !e.sourceId)) {
        giveUp();
      }
    });

    // the layers belong to the style: drawn again after the theme changed the style
    function drawLayers() {
      if (!map.getSource('me-acc')) {
        map.addSource('me-acc', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } });
        map.addLayer({ id: 'me-acc', type: 'fill', source: 'me-acc', paint: { 'fill-color': token('--primary'), 'fill-opacity': 0.14 } });
      }
      if (!map.getSource('me-route')) {
        map.addSource('me-route', { type: 'geojson', data: { type: 'FeatureCollection', features: [] } });
        map.addLayer({ id: 'me-route', type: 'line', source: 'me-route', layout: { 'line-cap': 'round' },
                       paint: { 'line-color': token('--success'), 'line-width': 3, 'line-dasharray': [1, 2.5] } });
      }
      paintAccuracy();
      paintRoute();
    }
    map.on('style.load', drawLayers);

    function paintAccuracy() {
      var source = map.getSource('me-acc');
      if (source && userPos) {
        source.setData(circle(userPos.lat, userPos.lng, Math.min(Math.max(userPos.acc || 60, 20), 500)));
      }
    }

    function paintRoute() {
      var source = map.getSource('me-route');
      if (source) {
        source.setData(routeLine ? { type: 'Feature', properties: {}, geometry: { type: 'LineString', coordinates: routeLine } }
          : { type: 'FeatureCollection', features: [] });
      }
    }

    document.addEventListener('sl-theme-change', function () {
      if (!dead) {
        map.setStyle(styleUrl());
      }
    });

    // the glass islands drop their refraction while the map moves (css/locker-map.css body.map-moving): smoother panning
    map.on('movestart', function () {
      document.body.classList.add('map-moving');
    });
    map.on('moveend', function () {
      document.body.classList.remove('map-moving');
    });

    function pad() {
      var p = opts.padding ? opts.padding() : null;
      return p || { left: 0, right: 0, top: 0, bottom: 0 };
    }

    function focusAt(lngLat) {
      var camera = { center: lngLat, zoom: Math.max(map.getZoom(), STREET_ZOOM), padding: pad() };
      if (reducedMotion) {
        map.jumpTo(camera);
      } else {
        camera.duration = 700;
        map.flyTo(camera);
      }
    }

    function fit(points, animate) {
      if (points.length === 1) {
        var one = { center: points[0], zoom: STREET_ZOOM, padding: pad() };
        if (animate && !reducedMotion) {
          map.flyTo(one);
        } else {
          map.jumpTo(one);
        }
      } else if (points.length > 1) {
        var bounds = new gl.LngLatBounds(points[0], points[0]);
        points.forEach(function (p) {
          bounds.extend(p);
        });
        var p = pad();
        map.fitBounds(bounds, {
          padding: { left: p.left + 40, right: p.right + 40, top: p.top + 40, bottom: p.bottom + 40 },
          maxZoom: 16,
          animate: animate && !reducedMotion
        });
      }
    }

    // a pin is a real button for the keyboard; a drag that starts on a pin moves the map and selects nothing
    function pinNode(code) {
      var node = document.createElement('div');
      var downX = 0;
      var downY = 0;
      node.className = 'pin-wrap pin-wrap--gl';
      node.tabIndex = 0;
      node.setAttribute('role', 'button');
      node.addEventListener('pointerdown', function (e) {
        downX = e.clientX;
        downY = e.clientY;
      });
      node.addEventListener('click', function (e) {
        e.stopPropagation();
        if (Math.abs(e.clientX - downX) < 6 && Math.abs(e.clientY - downY) < 6) {
          opts.onSelect(code);
        }
      });
      node.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          opts.onSelect(code);
        }
      });
      return node;
    }

    function update(areas, activeCode, targetCode) {
      var seen = {};
      var points = [];
      areas.forEach(function (a) {
        if (!hasCoords(a)) {
          return;
        }
        var code = a.area_code;
        var lngLat = [a.longitude, a.latitude];
        seen[code] = true;
        points.push(lngLat);
        var tone = opts.tone(a);
        var isActive = code === activeCode;
        var isTarget = code === targetCode;
        var html = shared.pinHtml(a, tone, isActive, isTarget, opts.esc);
        var entry = markers[code];
        if (!entry) {
          var node = pinNode(code);
          entry = markers[code] = { node: node, html: null, marker: new gl.Marker({ element: node, anchor: 'center' }).setLngLat(lngLat).addTo(map) };
        } else {
          entry.marker.setLngLat(lngLat);
        }
        if (entry.html !== html) {
          // only when it changed: a new element would lose the focus and start the waves again
          entry.html = html;
          entry.node.innerHTML = html;
        }
        entry.node.setAttribute('aria-label', shared.pinTitle(a, tone, isTarget));
        entry.node.setAttribute('title', shared.pinTitle(a, tone, isTarget));
        entry.node.style.zIndex = isTarget ? 3 : (isActive ? 2 : 1);
      });
      Object.keys(markers).forEach(function (code) {
        if (!seen[code]) {
          markers[code].marker.remove();
          delete markers[code];
        }
      });
      if (points.length && !fitted) {
        fitted = true;
        if (markers[activeCode]) {
          fit([markers[activeCode].marker.getLngLat().toArray()], false);
        } else {
          fit(points, false);
        }
      }
      declutter(activeCode, targetCode);
      lastActive = activeCode;
      lastTarget = targetCode;
      return points.length;
    }

    var lastActive = null;
    var lastTarget = null;

    function declutter(activeCode, targetCode) {
      shared.declutter(Object.keys(markers).map(function (code) {
        return { code: code, node: markers[code].node };
      }), activeCode, targetCode);
    }
    map.on('zoomend', function () {
      declutter(lastActive, lastTarget);
    });

    function setUser(pos) {
      if (!pos) {
        return;
      }
      userPos = pos;
      if (!userMarker) {
        var dot = document.createElement('span');
        dot.className = 'me-dot';
        dot.setAttribute('role', 'img');
        dot.setAttribute('aria-label', 'Vị trí của bạn');
        userMarker = new gl.Marker({ element: dot, anchor: 'center' }).setLngLat([pos.lng, pos.lat]).addTo(map);
      } else {
        userMarker.setLngLat([pos.lng, pos.lat]);
      }
      paintAccuracy();
    }

    return {
      update: update,
      setUser: setUser,
      setRoute: function (from, to) {
        routeLine = from && to ? [[from.lng, from.lat], [to.lng, to.lat]] : null;
        paintRoute();
      },
      focus: function (code) {
        if (markers[code]) {
          focusAt(markers[code].marker.getLngLat());
        }
      },
      fitAll: function () {
        var points = Object.keys(markers).map(function (code) {
          return markers[code].marker.getLngLat().toArray();
        });
        if (userMarker) {
          points.push(userMarker.getLngLat().toArray());
        }
        fit(points, true);
      },
      invalidate: function () {
        map.resize();
      },
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
          focusAt(userMarker.getLngLat());
        }
      }
    };
  }

  window.AreaMapbox = { create: create };
})();
