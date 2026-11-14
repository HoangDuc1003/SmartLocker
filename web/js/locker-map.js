/* Locker map (v5): a full-screen map with glass islands (WEB-INF/views/lockerMap.jsp).
   Data: GET data-api?area=CODE on <main id="lockerApp">, refreshed every 10 seconds.
   This file fills the area sheet (the list of areas, or one area with its banks), the slot card and the pins
   (js/area-map.js). On a phone the sheet is a bottom sheet with three heights and holds the slot card.
   Needs js/app.js first (window.SmartLocker: esc, toast, confirm).
   Actions are plain HTML forms posted to the controllers, so they also work without fetch. */
(function () {
  'use strict';

  var root = document.getElementById('lockerApp');
  if (!root) {
    return;
  }

  var REFRESH_MS = 10000;
  var HOLD_MINUTES = 15;

  var STATUS = {
    AVAILABLE: { label: 'Available', icon: 'check' },
    RESERVED: { label: 'Reserved', icon: 'bookmark' },
    OCCUPIED: { label: 'Occupied', icon: 'box' },
    OVERDUE: { label: 'Overdue', icon: 'clock' },
    ALERT: { label: 'Alert', icon: 'alert' },
    MAINTENANCE: { label: 'Maintenance', icon: 'wrench' },
    OFFLINE: { label: 'Offline', icon: 'wifiOff' }
  };
  var STATUS_ORDER = ['AVAILABLE', 'RESERVED', 'OCCUPIED', 'OVERDUE', 'ALERT', 'MAINTENANCE', 'OFFLINE'];

  var ICONS = {
    check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
    bookmark: '<path d="M7 4h10v16l-5-3.5L7 20z"/>',
    lock: '<rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>',
    clock: '<circle cx="12" cy="12" r="8"/><path d="M12 7.5V12l3 2"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    minus: '<path d="M5 12h14"/>',
    alert: '<path d="M12 4l9 16H3z"/><path d="M12 10v4.5M12 17.5v.01"/>',
    wrench: '<path d="M14.5 5.5a4 4 0 0 0-5 5L4 16l4 4 5.5-5.5a4 4 0 0 0 5-5l-2.5 2.5-2.5-.5-.5-2.5z"/>',
    wifiOff: '<path d="M3 3l18 18"/><path d="M8.5 16.5a5 5 0 0 1 7 0M5 12.5a10 10 0 0 1 4-2.3M19 12.5a10 10 0 0 0-2.6-1.8M12 19.5v.01"/>',
    close: '<path d="M6 6l12 12M18 6L6 18"/>',
    unlock: '<rect x="5" y="10.5" width="14" height="9.5" rx="2"/><path d="M8 10.5V8a4 4 0 0 1 7.6-1.7"/>',
    box: '<path d="M4 7.5l8-4 8 4v9l-8 4-8-4z"/><path d="M4 7.5l8 4 8-4M12 11.5v9"/>',
    route: '<path d="M3 11 21 3l-8 18-2-8z"/>',
    locate: '<circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="7.5"/><path d="M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22"/>',
    chevronRight: '<path d="M9 6l6 6-6 6"/>',
    refresh: '<path d="M19 12a7 7 0 1 1-2.05-4.95"/><path d="M19 4.5V8h-3.5"/>'
  };

  var cfg = {
    ctx: root.getAttribute('data-ctx') || '',
    api: root.getAttribute('data-api') || 'api/locker-map',
    role: (root.getAttribute('data-role') || 'END_USER').toUpperCase(),
    balance: Number(root.getAttribute('data-balance')) || 0,
    bookingUrl: root.getAttribute('data-booking-url') || 'BookingController',
    myLockerUrl: root.getAttribute('data-mylocker-url') || 'MyLockerController',
    topupUrl: root.getAttribute('data-topup-url') || 'TopupController',
    loginUrl: root.getAttribute('data-login-url') || 'LoginController',
    mapbox: {
      token: root.getAttribute('data-mapbox-token') || '',
      light: root.getAttribute('data-mapbox-light') || '',
      dark: root.getAttribute('data-mapbox-dark') || ''
    }
  };

  var state = {
    data: null,
    area: readParam('area'),
    slotId: toInt(readParam('slot')),
    sheetMode: readParam('area') ? 'detail' : 'list',   // the list of areas, or one area
    snap: readParam('slot') ? 'full' : 'half',   // phone bottom sheet: peek | half | full
    animateBanks: false,      // the banks of an area just opened come in one after the other
    filters: {},
    query: '',
    loadedAt: 0,
    error: null,
    panelDirty: false,
    panelSig: null,           // what the slot card shows; a refresh with the same slot does not redraw it
    popupOpen: false,
    stale: false,             // an answer came while a popup was open and is not drawn yet
    etag: null,               // ETag of the last answer and the URL it belongs to (304 = nothing to draw)
    etagUrl: null,
    userChoseArea: false,     // the map flies to the nearest area by itself only until the visitor picks one
    placed: -1,               // pins on the map (-1 before the first answer)
    returnFocus: null
  };

  var phoneQuery = window.matchMedia('(max-width: 639px)');   // same breakpoint as css/locker-map.css
  var el = {};
  var areaMap = null;   // js/area-map.js
  // springs of js/glass-motion.js (Motion); without it every change shows at once
  var motion = window.SmartLockerMotion || (function () {
    var done = function () { return Promise.resolve(); };
    return { pop: done, leave: done, slideIn: done, stagger: done, bump: done, stopHeight: done,
             height: function (node, px) { node.style.height = px + 'px'; return done(); } };
  })();

  /* ---------- small helpers ---------- */

  function icon(name) {
    return '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true" focusable="false">' + (ICONS[name] || '') + '</svg>';
  }

  var esc = window.SmartLocker.esc;   // the one HTML escaper, from js/app.js

  function readParam(name) {
    var match = new RegExp('[?&]' + name + '=([^&#]*)').exec(window.location.search);
    return match ? decodeURIComponent(match[1].replace(/\+/g, ' ')) : null;
  }

  function toInt(value) {
    var n = parseInt(value, 10);
    return isNaN(n) ? null : n;
  }

  function isPhone() {
    return phoneQuery.matches;
  }

  function statusInfo(code) {
    return STATUS[code] || { label: code, icon: 'lock' };
  }

  function toast(message, type) {
    if (window.SmartLocker) {
      window.SmartLocker.toast(message, type);
    }
  }

  // The DB stores UTC and CONVERT(..., 121) drops the zone: "2026-10-17 07:03:00.0000000" is UTC
  function parseUtc(iso) {
    var s = String(iso).replace(' ', 'T').replace(/(\.\d{3})\d*$/, '$1');
    return new Date(/[zZ]|[+-]\d\d:?\d\d$/.test(s) ? s : s + 'Z');
  }

  function formatTime(iso) {
    if (!iso) {
      return '';
    }
    var d = parseUtc(iso);
    if (isNaN(d.getTime())) {
      return esc(iso);
    }
    var time = d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
    var today = new Date();
    if (d.toDateString() === today.toDateString()) {
      return time;
    }
    var two = function (n) { return (n < 10 ? '0' : '') + n; };   // 21/10, the same as <ui:dt> prints
    return two(d.getDate()) + '/' + two(d.getMonth() + 1) + ', ' + time;
  }

  // "12:34 left" under an hour, "2 h 05 min left" above, "5:00 late" when the time has passed
  function formatCountdown(iso) {
    var diff = Math.round((parseUtc(iso).getTime() - Date.now()) / 1000);
    var late = diff < 0;
    var s = Math.abs(diff);
    var h = Math.floor(s / 3600);
    var m = Math.floor((s % 3600) / 60);
    var sec = s % 60;
    var text = h > 0 ? h + ' h ' + (m < 10 ? '0' : '') + m + ' min'
                     : m + ':' + (sec < 10 ? '0' : '') + sec;
    return { text: late ? text + ' late' : text + ' left', late: late };
  }

  function countdownHtml(iso) {
    var c = formatCountdown(iso);
    return '<span class="countdown' + (c.late ? ' is-late' : '') + '" data-countdown="' + esc(iso) + '">' + esc(c.text) + '</span>';
  }

  function deviceLabel(code) {
    var names = { ACTIVE: 'Active', MAINTENANCE: 'Maintenance', OFFLINE: 'Offline', NONE: 'No device attached' };
    return names[code || 'ACTIVE'] || code;
  }

  function areas() {
    return (state.data && state.data.areas) || [];
  }

  // the area row of the list (counts, coordinates) for a code
  function areaInfo(code) {
    var list = areas();
    for (var i = 0; i < list.length; i++) {
      if (list[i].area_code === code) {
        return list[i];
      }
    }
    return null;
  }

  function banks() {
    return state.data && state.data.banks ? state.data.banks : [];
  }

  function findSlot(id) {
    var list = banks();
    for (var b = 0; b < list.length; b++) {
      var slots = list[b].slots || [];
      for (var s = 0; s < slots.length; s++) {
        if (slots[s].slot_id === id) {
          return { slot: slots[s], bank: list[b] };
        }
      }
    }
    return null;
  }

  function countStatuses() {
    var counts = {};
    banks().forEach(function (bank) {
      (bank.slots || []).forEach(function (slot) {
        counts[slot.status] = (counts[slot.status] || 0) + 1;
      });
    });
    return counts;
  }

  function hasFilter() {
    for (var key in state.filters) {
      if (state.filters[key]) {
        return true;
      }
    }
    return false;
  }

  function money(n) {
    return (Number(n) || 0).toLocaleString('en-US') + ' VND';
  }

  // the list of areas has no area in the URL, so a reload opens the list again
  function syncUrl() {
    try {
      var parts = [];
      if (state.area && state.sheetMode === 'detail') {
        parts.push('area=' + encodeURIComponent(state.area));
        if (state.slotId !== null) {
          parts.push('slot=' + state.slotId);
        }
      }
      window.history.replaceState(null, '', window.location.pathname + (parts.length ? '?' + parts.join('&') : ''));
    } catch (e) {
      // some browsers refuse replaceState (private mode, file://); the page works without it
    }
  }

  function collectRefs() {
    var refs = root.querySelectorAll('[data-ref]');
    for (var i = 0; i < refs.length; i++) {
      el[refs[i].getAttribute('data-ref')] = refs[i];
    }
  }

  /* ---------- area list ---------- */

  // how full an area is: the colour always comes with a word
  function areaTone(a) {
    if (!a.slot_count) {
      return { key: 'none', label: 'No slots yet' };
    }
    if (!a.available) {
      // every slot behind a silent (or missing) box is not "full": nothing can open it
      return a.offline >= a.slot_count ? { key: 'full', label: 'Offline' } : { key: 'full', label: 'Full' };
    }
    return a.available / a.slot_count < 0.25 ? { key: 'low', label: 'Almost full' } : { key: 'ok', label: 'Plenty free' };
  }

  function ringHtml(a) {
    var pct = a.slot_count ? Math.round(a.available * 100 / a.slot_count) : 0;
    return '<span class="ring tone-' + areaTone(a).key + '" style="--p:' + pct + '" aria-hidden="true"><b>' + esc(a.available) + '</b></span>';
  }

  function areaMatches(a) {
    var q = state.query;
    return !q || (a.name + ' ' + a.area_code + ' ' + (a.location || '')).toLowerCase().indexOf(q) !== -1;
  }

  function renderAreas() {
    var list = areas();
    renderMap(list);
    if (!state.data) {
      return;
    }
    if (!list.length) {
      el.areas.innerHTML = '<p class="sheet-empty">No locker areas yet.</p>';
      return;
    }
    var sorted = sortedAreas(list);
    var shown = sorted.filter(areaMatches);
    if (!shown.length) {
      el.areas.innerHTML = '<p class="sheet-empty">No area matches “' + esc(el.search.value.trim()) + '”.</p>';
      return;
    }
    el.areas.innerHTML = shown.map(function (a) {
      var dist = distanceTo(a);
      var tone = areaTone(a);
      var where = dist !== null ? formatDistance(dist) : (a.location || a.area_code);
      var tags = [];
      if (myBooking() && myBooking().area_code === a.area_code) {
        tags.push('<span class="gtag gtag--mine">Your locker</span>');
      }
      if (dist !== null && a === sorted[0]) {
        tags.push('<span class="gtag">Nearest</span>');
      }
      if (tone.key !== 'ok') {
        tags.push('<span class="gtag tone-' + tone.key + '">' + esc(tone.label) + '</span>');
      }
      if (a.alert) {
        tags.push('<span class="gtag tone-full">' + esc(a.alert) + (a.alert === 1 ? ' alert' : ' alerts') + '</span>');
      }
      return '<button type="button" class="area-row lg-hover" data-area="' + esc(a.area_code) + '">' +
        ringHtml(a) +
        '<span class="area-row__body"><span class="area-row__name">' + esc(a.name) + '</span>' +
          '<span class="area-row__meta">' + esc(where) + ' · Free ' + esc(a.available) + '/' + esc(a.slot_count) + '</span>' +
          (tags.length ? '<span class="area-row__tags">' + tags.join('') + '</span>' : '') +
        '</span>' + icon('chevronRight') +
      '</button>';
    }).join('');
  }

  function renderMap(list) {
    if (!areaMap || !state.data) {
      return;
    }
    state.placed = areaMap.update(list, state.sheetMode === 'detail' ? state.area : null,
      myBooking() ? myBooking().area_code : null);
  }

  /* ---------- where the user's locker is: the waves on its pin, the "wrong place" warning ---------- */

  var PLACE_RADIUS_M = 120;      // standing at an area
  var PLACE_MAX_ACC_M = 300;     // a position worse than this (a PC on Wi-Fi) never says "right" or "wrong"
  var place = { dismissed: null, sig: null, html: '', kind: null, route: '', flown: false };
  // the same words as CardMail.action on the server
  var CARD_ACTION = { CHECK_IN: 'store your things in the slot', ACCESS: 'open the slot (the booking continues)', PICKUP: 'pick up your things and check out (the booking ends)' };
  // result of CardConfirm_Decide -> [the message, is it an error]
  var CARD_ANSWER = {
    OK: ['Confirmed. The box opens in a few seconds.', false],
    DONE_BEFORE: ['This request was already confirmed.', false],
    REJECTED: ['Cancelled, the locker stays closed. If you did not scan your card, tell the staff so they can block it.', false],
    DEVICE_OFFLINE: ['The box is offline, so it cannot open yet. Try again in a few seconds.', true],
    EXPIRED: ['The request has expired. Scan your card at the box again.', true]
  };

  function myBooking() {
    return state.data && state.data.my_booking ? state.data.my_booking : null;
  }

  // kind: confirm | here | wrong | info. A card scan waiting for its answer comes first. The GPS says "here" before a
  // wrong scan (a card, a finger or a phone tap at another box), so that one does not nag someone who walked to the right area.
  function placeNow(b, mine) {
    var dist = distanceTo(mine);
    var key = b.area_code + '|' + b.slot_code;
    if (b.confirm_until) {
      return { kind: 'confirm', dist: dist, sig: 'confirm|' + b.confirm_until + '|' + key };
    }
    var sure = dist !== null && geo.pos.acc <= PLACE_MAX_ACC_M;
    var nearest = sure ? sortedAreas(areas()).filter(hasCoords)[0] : null;
    var gap = nearest ? distanceTo(nearest) : null;
    // two areas can be 30 m apart (DOMA, CANT): "here" only when this one is the nearest, or the position cannot tell them apart
    if (sure && dist <= PLACE_RADIUS_M && (nearest.area_code === b.area_code || dist - gap <= geo.pos.acc)) {
      return { kind: 'here', dist: dist, sig: 'here|' + key };
    }
    if (b.wrong_scan) {
      return { kind: 'wrong', scan: true, near: b.wrong_area, dist: dist, sig: 'scan|' + b.wrong_scan + '|' + key };
    }
    if (sure && gap <= PLACE_RADIUS_M && nearest.area_code !== b.area_code) {
      return { kind: 'wrong', near: nearest.name, dist: dist, sig: 'wrong|' + nearest.area_code + '|' + key };
    }
    return { kind: 'info', dist: dist, sig: 'info|' + key };
  }

  function placeHtml(b, mine, now) {
    var name = b.area_name;
    var slot = 'slot ' + b.slot_code + ', bank ' + b.bank_code;
    var far = now.dist !== null ? ' (' + formatDistance(now.dist) + ' from you)' : '';
    var where = (b.status === 'RESERVED' ? 'You hold ' : 'Your things are in ') + slot + ', ' + name + far + '.';
    var title, text, ico;
    if (now.kind === 'confirm') {
      return '<span class="place-alert__ico">' + icon('unlock') + '</span>' +
        '<div class="place-alert__body"><b>Confirm opening</b><p>' +
          esc('Your card was just scanned at the box to ' + (CARD_ACTION[b.confirm_phase] || 'open the locker') + '. Your locker: ' + slot + ', ' + name +
              '. No e-mail yet? You can confirm right here.') + '</p></div>' +
        '<button type="button" class="round-btn lg-hover place-alert__close" data-place-close aria-label="Close the locker location notice">' + icon('close') + '</button>' +
        '<div class="place-alert__do">' +
          '<button type="button" class="chip lg-hover place-alert__yes" data-card-answer="approve">' + icon('unlock') + 'Confirm opening</button>' +
          '<button type="button" class="chip lg-hover" data-card-answer="reject">It was not me</button>' +
        '</div>';
    }
    if (now.kind === 'wrong') {
      ico = 'alert';
      title = now.scan ? 'Wrong locker box' : 'You are in the wrong place';
      text = (now.scan ? 'You just tried to open a locker at ' + (now.near || 'another box') : 'You are at ' + now.near) + '. ' + where;
    } else if (now.kind === 'here') {
      ico = 'check';
      title = 'You are in the right place';
      text = 'Your locker is in this area: ' + slot + ', ' + name + '.';
    } else {
      ico = 'box';
      title = 'Your locker is at ' + name;
      text = (b.status === 'RESERVED' ? 'You hold ' : 'Your things are in ') + slot + far + '. The area with your locker has wave rings on the map.';
    }
    return '<span class="place-alert__ico">' + icon(ico) + '</span>' +
      '<div class="place-alert__body"><b>' + esc(title) + '</b><p>' + esc(text) + '</p></div>' +
      '<button type="button" class="round-btn lg-hover place-alert__close" data-place-close aria-label="Close the locker location notice">' + icon('close') + '</button>' +
      (now.kind === 'here' ? '' : '<div class="place-alert__do">' +
        '<button type="button" class="chip lg-hover" data-place-show>' + icon('locate') + 'Show my locker</button>' +
        (hasCoords(mine) ? '<a class="chip lg-hover" href="' + esc(directionsUrl(mine)) + '" target="_blank" rel="noopener noreferrer">' +
          icon('route') + 'Directions</a>' : '') + '</div>');
  }

  function renderPlace() {
    var b = myBooking();
    drawPlace(b);
    // whoever has a locker sees its waves first; after the warning is drawn, so the pin stays out from under it
    if (b && !place.flown && areaMap && !state.userChoseArea && !readParam('area')) {
      place.flown = true;
      areaMap.focus(b.area_code);
    }
  }

  function drawPlace(b) {
    var mine = b ? areas().filter(function (a) { return a.area_code === b.area_code; })[0] : null;
    var now = b ? placeNow(b, mine) : null;
    if (areaMap) {
      var line = now && now.kind === 'wrong' && geo.pos && hasCoords(mine);
      var key = line ? [geo.pos.lat, geo.pos.lng, mine.area_code].join() : '';
      if (key !== place.route) {
        place.route = key;
        areaMap.setRoute(line ? geo.pos : null, line ? { lat: mine.latitude, lng: mine.longitude } : null);
      }
    }
    if (!now || place.dismissed === now.sig) {
      el.place.hidden = true;
      el.place.innerHTML = '';
      place.html = '';
      place.kind = null;
      return;
    }
    place.sig = now.sig;        // also with the same text: a second wrong scan has a new mark, which the X must close
    var html = placeHtml(b, mine, now);
    if (html === place.html) {
      return;                   // a redraw would lose the focus of a button
    }
    var fresh = place.kind !== now.kind;
    place.html = html;
    place.kind = now.kind;
    el.place.className = 'place-alert place-alert--' + now.kind;
    el.place.setAttribute('role', now.kind === 'wrong' || now.kind === 'confirm' ? 'alert' : 'status');
    el.place.innerHTML = html;
    el.place.hidden = false;
    if (fresh) {
      motion.pop(el.place);
    }
  }

  // the answer to a card scan from the map: MyLockerController asks the same procedure as the page behind the e-mail
  function answerCard(button) {
    var body = new URLSearchParams();
    body.set('action', 'cardConfirm');
    body.set('decision', button.getAttribute('data-card-answer'));
    Array.prototype.forEach.call(el.place.querySelectorAll('[data-card-answer]'), function (b) {
      b.disabled = true;
    });
    fetch(cfg.myLockerUrl, { method: 'POST', credentials: 'same-origin', headers: { Accept: 'application/json' }, body: body })
      .then(function (res) {
        if (!res.ok) {
          throw new Error('HTTP ' + res.status);
        }
        return res.json();
      })
      .then(function (answer) {
        var said = CARD_ANSWER[answer.result] || CARD_ANSWER.EXPIRED;
        toast(said[0], said[1] ? 'error' : undefined);
      })
      .catch(function () {
        toast('Could not send your answer. Please try again.', 'error');
      })
      .then(function () {
        place.html = '';        // the buttons work again if the wait goes on (box offline, no network)
        state.etag = null;      // the wait is over: the next answer must come in full, not as a 304
        load();
      });
  }

  /* ---------- one area: head, quick tiles, chips, banks ---------- */

  function renderHead() {
    var info = areaInfo(state.area);
    var area = info || (state.data && state.data.area) || null;
    el.title.textContent = area ? area.name : 'Area';
    el.sub.textContent = area ? (area.location || '') : '';
    if (!info) {
      el.quick.innerHTML = '';
      return;
    }
    var go;
    if (hasCoords(info)) {
      var dist = distanceTo(info);
      var text = dist !== null ? formatDistance(dist) : 'Directions';
      go = '<a class="quick__tile quick__go lg-hover" href="' + esc(directionsUrl(info)) + '" target="_blank" rel="noopener noreferrer"' +
        ' aria-label="' + esc('Directions to ' + info.name + (dist !== null ? ', ' + text + ' away' : '') + ' (opens Google Maps)') + '">' +
        icon('route') + '<span>' + esc(text) + '</span></a>';
    } else {
      go = '<div class="quick__tile"><b>–</b><span>No coordinates yet</span></div>';
    }
    el.quick.innerHTML = go +
      '<div class="quick__tile"><b>' + esc(info.available) + '</b><span>free slots</span></div>' +
      '<div class="quick__tile"><b>' + esc(info.slot_count) + '</b><span>total slots</span></div>';
  }

  function renderChips() {
    var counts = countStatuses();
    var html = STATUS_ORDER.filter(function (code) {
      return counts[code] || state.filters[code];
    }).map(function (code) {
      return '<button type="button" class="chip lg-hover st-' + code + '" data-filter="' + code + '" aria-pressed="' + (state.filters[code] ? 'true' : 'false') + '">' +
        '<span class="chip__dot"></span>' + statusInfo(code).label +
        ' <span class="chip__count">' + (counts[code] || 0) + '</span></button>';
    }).join('');
    if (hasFilter()) {
      html += '<button type="button" class="chip chip--clear lg-hover" data-filter-clear>Clear filters</button>';
    }
    el.chips.innerHTML = html;
  }

  function deviceTag(bank) {
    if (bank.device_status === 'MAINTENANCE') {
      return '<span class="device-tag device-tag--maintenance">Maintenance</span>';
    }
    if (bank.device_status === 'OFFLINE') {
      return '<span class="device-tag device-tag--offline">Offline</span>';
    }
    if (bank.device_status === 'NONE') {
      return '<span class="device-tag device-tag--offline">No device attached</span>';
    }
    return '<span class="device-tag device-tag--live">Online</span>';
  }

  /* cabinet (spec v3 D9): one block per bank, door height by size S 1 / M 2 / L 3 units */

  var SIZE_NAMES = { S: 'Small', M: 'Medium', L: 'Large' };

  function slotHtml(slot) {
    var st = statusInfo(slot.status);
    var q = state.query;
    var size = SIZE_NAMES[slot.size] ? slot.size : 'S';
    var match = q && String(slot.slot_code).toLowerCase().indexOf(q) !== -1;
    var dim = (hasFilter() && !state.filters[slot.status]) || (q && !match);
    // a door locked for overdue is drawn in the overdue colors, whatever the box reports
    var classes = 'slot st-' + (slot.locked ? 'OVERDUE' : slot.status) + ' size-' + size +
      (slot.locked ? ' is-locked' : '') + (slot.mine ? ' is-mine' : '') + (dim ? ' is-dim' : '') +
      (match ? ' is-match' : '') + (slot.slot_id === state.slotId ? ' is-selected' : '');
    var label = slot.slot_code + ', ' + st.label + ', size ' + size + (slot.locked ? ', locked because overdue' : '') +
      (slot.mine ? ', yours' : '');
    return '<button type="button" class="' + classes + '" data-slot="' + esc(slot.slot_id) + '" aria-label="' + esc(label) + '"' +
        ' aria-pressed="' + (slot.slot_id === state.slotId ? 'true' : 'false') + '" title="' + esc(label) + '">' +
      '<span class="slot__top"><span class="slot__code">' + esc(slot.slot_code) + '</span>' +
        '<span class="slot__size">' + size + '</span></span>' +
      '<span class="slot__icon">' + icon(slot.locked ? 'lock' : st.icon) + '</span>' +
      (slot.mine ? '<span class="slot__you">You</span>' : '') +
    '</button>';
  }

  // the slots come sorted by code, door_rows of them per column, top to bottom
  function cabinetHtml(bank) {
    var per = toInt(bank.rows) || 4;
    var slots = bank.slots || [];
    var cols = [];
    for (var i = 0; i < slots.length; i += per) {
      cols.push(slots.slice(i, i + per));
    }
    return '<div class="cabinet">' + cols.map(function (col) {
      return '<div class="cabinet__col">' + col.map(slotHtml).join('') + '</div>';
    }).join('') + '</div>';
  }

  function bankFoot(bank) {
    var free = 0, used = 0, issues = 0, locked = 0;
    (bank.slots || []).forEach(function (s) {
      if (s.locked) {
        locked++;
      }
      if (s.status === 'AVAILABLE') {
        free++;
      } else if (s.status === 'OCCUPIED' || s.status === 'RESERVED' || s.status === 'OVERDUE') {
        used++;
      } else {
        issues++;
      }
    });
    return free + ' free · ' + used + ' in use' + (locked ? ' · ' + locked + ' locked overdue' : '') +
      (issues ? ' · ' + issues + ' to check' : '');
  }

  function renderBanks() {
    var list = banks();
    if (!state.data || (!list.length && state.data.area && state.data.area.area_code !== state.area)) {
      el.banks.innerHTML = '<div class="empty">Loading locker banks…</div>';
      return;
    }
    if (!list.length) {
      el.banks.innerHTML = '<div class="empty">This area has no locker banks yet.</div>';
      return;
    }
    el.banks.innerHTML = list.map(function (bank) {
      return '<article class="bank" aria-label="' + esc(bank.name + ' ' + bank.bank_code) + '">' +
        '<header class="bank__head"><h3 class="bank__name">' + esc(bank.name) +
          '<span class="bank__code">' + esc(bank.bank_code) + (bank.device_code ? ' · ' + esc(bank.device_code) : '') + '</span>' +
          '</h3>' + deviceTag(bank) + '</header>' +
        '<div class="bank__scroll">' + cabinetHtml(bank) + '</div>' +
        '<p class="bank__foot">' + bankFoot(bank) + '</p>' +
      '</article>';
    }).join('');
    if (state.animateBanks) {
      state.animateBanks = false;
      motion.stagger(el.banks.querySelectorAll('.bank'));
    }
  }

  function renderSync() {
    var text;
    if (state.error) {
      text = 'Connection lost, retrying';
    } else if (!state.loadedAt) {
      text = 'Loading';
    } else {
      var secs = Math.max(0, Math.round((Date.now() - state.loadedAt) / 1000));
      text = secs < 3 ? 'Updated just now' : 'Updated ' + secs + ' s ago';
    }
    if (el.sync.textContent !== text) {
      el.sync.textContent = text;
    }
    el.sync.classList.toggle('is-error', !!state.error);
  }

  // the wallet pill and the account menu print the balance the API just sent
  function renderBalance() {
    var nodes = document.querySelectorAll('[data-balance-text]');
    for (var i = 0; i < nodes.length; i++) {
      nodes[i].textContent = money(cfg.balance);
      nodes[i].classList.toggle('is-debt', cfg.balance < 0);
    }
  }

  /* ---------- slot card ---------- */

  function describe(slot) {
    var mine = slot.mine;
    if (slot.locked) {
      return mine ? 'The booking is overdue, so the slot is locked. The late fee is taken from your wallet; the slot opens again once your balance is 0 VND or more.'
                  : 'The booking in this slot is overdue and the slot is locked.';
    }
    switch (slot.status) {
      case 'AVAILABLE':
        return 'Choose a storage plan and an open method to book this slot.';
      case 'RESERVED':
        return mine ? 'This slot is held for you. When the hold ends the booking starts by itself: early or late, you can use it for the time you paid.'
                    : 'Someone has booked this slot.';
      case 'OCCUPIED':
        return mine ? 'Your things are in this slot.' : 'Someone is using this slot.';
      case 'OVERDUE':
        return mine ? 'Your storage time is over. Extend it or pick up your things before the grace period ends.' : 'The storage time is over.';
      case 'ALERT':
        return 'This slot has an alert; staff are checking it.';
      case 'MAINTENANCE':
        return 'Out of service while a technician checks it.';
      case 'OFFLINE':
        return 'The locker controller is offline, so the slot cannot be booked and the status may be out of date.';
      default:
        return '';
    }
  }

  function fact(label, value) {
    return '<dt>' + label + '</dt><dd>' + value + '</dd>';
  }

  function hidden(name, value) {
    return '<input type="hidden" name="' + name + '" value="' + esc(value) + '">';
  }

  // every form carries area and slot back, so the controller can redirect to the same view
  function formStart(url, action, slot, confirmText, extra) {
    return '<form class="action-form" method="post" action="' + esc(url) + '"' +
      (confirmText ? ' data-confirm="' + esc(confirmText) + '"' : '') + (extra || '') + '>' +
      (action ? hidden('action', action) : '') +
      hidden('slotId', slot.slot_id) + hidden('area', state.area) + hidden('slot', slot.slot_id);
  }

  var METHODS = {
    PIN: { label: 'PIN', desc: 'Enter the 6-digit PIN on the keypad of the box or on your phone (scan the QR code).' },
    CARD: { label: 'RFID card', desc: 'Hold your RFID card to the reader of the box.' },
    PHONE: { label: 'Phone', desc: 'Sign in on your phone, tap it on the NFC reader of the box, then press Open. No PIN needed.' },
    FINGERPRINT: { label: 'Fingerprint', desc: 'Place your finger on the sensor of the box.' }
  };
  var METHOD_ORDER = ['PIN', 'CARD', 'PHONE', 'FINGERPRINT'];

  // the numbers of the rules come from AppConfig through the API (spec v3 2.1); the defaults are only a fallback
  function rule(name, fallback) {
    var r = state.data && state.data.rules;
    return r && r[name] !== undefined && r[name] !== null ? Number(r[name]) : fallback;
  }

  function holdMinutes() {
    return rule('hold_min', (state.data && state.data.hold_min) || HOLD_MINUTES);
  }

  function cancelMinutes() {
    return rule('cancel_min', 5);
  }

  function cancelLatePct() {
    return rule('cancel_late_pct', 50);
  }

  // a cancel after the free minutes: the same rounding as Deposit_Cancel (down to 100 VND)
  function lateRefund(paid) {
    return Math.floor((Number(paid) || 0) * cancelLatePct() / 10000) * 100;
  }

  function bookingBuffer() {
    return rule('booking_buffer', 10000);
  }

  function sizeInfo(code) {
    var list = (state.data && state.data.sizes) || [];
    for (var i = 0; i < list.length; i++) {
      if (list[i].code === code) {
        return list[i];
      }
    }
    return null;
  }

  // "20x20x20" -> "20×20×20 cm"
  function sizeDims(slot) {
    var z = sizeInfo(slot.size);
    var dims = (z && z.size_cm) || slot.size_cm;
    return dims ? String(dims).replace(/x/g, '×') + ' cm' : '';
  }

  // price of a plan for one size, from the server's table (plan x size factor); every open method costs the same
  function planPrice(plan, size) {
    var bySize = plan.prices && plan.prices[size];
    return bySize !== undefined ? Number(bySize) || 0 : Number(plan.price) || 0;
  }

  function fingerEnrolled(bank) {
    var list = (state.data && state.data.fp_devices) || [];
    return !!bank.device_code && list.indexOf(bank.device_code) !== -1;
  }

  function methodDesc(code, bank) {
    if (code === 'FINGERPRINT') {
      return METHODS.FINGERPRINT.desc + (fingerEnrolled(bank) ? ' Your fingerprint is already enrolled on this box.'
        : ' The first time, enroll it at the box with the code from My locker.');
    }
    return METHODS[code].desc;
  }

  // "Custom": price tables of the map API (util.Pricing, the same formula as dbo.fn_CustomPrice).
  // Display only: the form posts customMin and Deposit_Reserve prices the booking again.
  function customCfg() {
    var c = state.data && state.data.custom;
    return c && (Number(c.max_hours) > 0 || Number(c.max_days) > 0) ? c : null;
  }

  // 0 when that unit is switched off in AppConfig
  function customMax(unit) {
    var c = customCfg();
    return c ? Math.max(Number(unit === 'day' ? c.max_days : c.max_hours) || 0, 0) : 0;
  }

  function customPrice(unit, count, size) {
    var c = customCfg();
    var list = c && (unit === 'day' ? c.days : c.hours);
    var bySize = list && list[size];
    return bySize && bySize[count - 1] !== undefined ? Number(bySize[count - 1]) || 0 : 0;
  }

  function durationText(unit, count) {
    return count + (unit === 'day' ? (count === 1 ? ' day' : ' days') : ' h');
  }

  // the unit and the count picked in the "Custom" block, kept inside the limits
  function customPick(form) {
    var unitInput = form.querySelector('input[name="customUnit"]:checked');
    var unit = unitInput && unitInput.value === 'day' ? 'day' : 'hour';
    if (customMax(unit) < 1) {
      unit = unit === 'day' ? 'hour' : 'day';
    }
    var range = form.querySelector('[data-custom-count]');
    var count = Math.min(Math.max(toInt(range ? range.value : 1) || 1, 1), customMax(unit));
    return { unit: unit, count: count, minutes: count * (unit === 'day' ? 1440 : 60) };
  }

  // what the user is choosing: plan, open method and the price taken now
  function reserveChoice(slot) {
    var form = el.panel.querySelector('form[data-reserve]');
    var plans = (state.data && state.data.plans) || [];
    if (!form || !plans.length || !slot) {
      return null;
    }
    var pickedPlan = form.querySelector('input[name="planId"]:checked');
    var plan = plans[0];
    for (var i = 0; i < plans.length; i++) {
      if (pickedPlan && String(plans[i].plan_id) === pickedPlan.value) {
        plan = plans[i];
      }
    }
    var wantsCustom = !!pickedPlan && pickedPlan.value === 'custom';
    var custom = wantsCustom && customCfg() ? customPick(form) : null;
    var checked = form.querySelector('input[name="openMethod"]:checked');
    var method = checked ? checked.value : 'PIN';
    var price = custom ? customPrice(custom.unit, custom.count, slot.size) : planPrice(plan, slot.size);
    if (custom) {
      plan = { plan_name: 'Custom · ' + durationText(custom.unit, custom.count), duration_min: custom.minutes };
    }
    // "Custom" picked but no longer offered (a refresh dropped it) or not priced: never show it as free
    var unavailable = wantsCustom && (!custom || price <= 0);
    var balance = Number(cfg.balance) || 0;
    // Deposit_Reserve: balance - price must stay >= BOOKING_BUFFER
    var enough = balance - price >= bookingBuffer();
    return { plan: plan, custom: unavailable ? null : custom, unavailable: unavailable, method: method, price: price,
             size: slot.size, balance: balance, after: balance - price, enough: enough };
  }

  // "21/10 14:30": the due time if the slot is opened now (the clock starts at the first open)
  function dueIfOpenedNow(minutes) {
    var d = new Date(Date.now() + minutes * 60000);
    var two = function (n) { return (n < 10 ? '0' : '') + n; };
    return two(d.getDate()) + '/' + two(d.getMonth() + 1) + ' ' + two(d.getHours()) + ':' + two(d.getMinutes());
  }

  // the saving of a custom choice: hours capped by the day pass, days below the price of single days
  function customNote(choice) {
    var c = customCfg();
    var cu = choice.custom;
    var size = choice.size;
    var parts = [];
    if (cu.unit === 'hour') {
      var rate = Number(c.hour_rate && c.hour_rate[size]) || 0;
      var byHour = rate * cu.count;
      if (choice.price < byHour) {
        // capped by the day pass: the day pass costs the same and lasts 24 hours
        parts.push('Charged at the full-day price, saving ' + money(byHour - choice.price) + ' against ' + money(rate) +
          '/h. The Day pass plan costs the same and lasts 24 h.');
      } else {
        parts.push(money(rate) + ' per hour (size ' + size + '), never more than the full-day price of ' + money(c.day_price && c.day_price[size]) + '.');
      }
      var plans = (state.data && state.data.plans) || [];
      for (var i = 0; i < plans.length; i++) {
        var p = planPrice(plans[i], size);
        if (Number(plans[i].duration_min) === cu.minutes && p < choice.price) {
          parts.push('The plan “' + plans[i].plan_name + '” is cheaper: ' + money(p) + '.');
        }
      }
    } else {
      var day = Number(c.day_price && c.day_price[size]) || 0;
      var full = day * cu.count;
      if (cu.count > 1 && choice.price < full) {
        parts.push('About ' + money(Math.round(choice.price / cu.count / 100) * 100) + '/day, saving ' +
          money(full - choice.price) + ' against ' + cu.count + ' single days.');
      } else {
        parts.push(money(day) + ' per day (size ' + size + '); 2 days or more get a discount.');
      }
    }
    parts.push('Time counts from the first opening; if you open it now, the due time is ' + dueIfOpenedNow(cu.minutes) + '.');
    return parts.join(' ');
  }

  function rulesHint() {
    return 'Hold ' + holdMinutes() + ' min · cancel in the first ' + cancelMinutes() + ' min for a full refund, after that until the hold ends for a ' +
      cancelLatePct() + '% refund. When the hold ends the booking starts by itself and can no longer be cancelled: the slot stays locked for you, ' +
      'and whether you come early, late or not at all, the paid time is yours; no refund.';
  }

  // the segmented controls are radios, so the form posts planId and openMethod as before
  function segOption(name, id, value, checked, inner) {
    return '<label class="seg-opt lg-hover" for="' + id + '">' +
      '<input type="radio" id="' + id + '" name="' + name + '" value="' + esc(value) + '"' + (checked ? ' checked' : '') + '>' +
      inner + '</label>';
  }

  function reserveForm(slot) {
    var plans = (state.data && state.data.plans) || [];
    if (!plans.length) {
      return '<p class="notice">No storage plans yet.</p>';
    }
    var planOpts = plans.map(function (p, i) {
      var price = planPrice(p, slot.size);
      return segOption('planId', 'pl-' + slot.slot_id + '-' + p.plan_id, p.plan_id, i === 0,
        '<span>' + esc(p.plan_name) + '</span><span class="seg-opt__sub seg-opt__sub--line">' + esc(price ? money(price) : 'Free') + '</span>');
    }).join('');
    var customBlock = '';
    if (customCfg()) {
      var sid = slot.slot_id;
      planOpts += segOption('planId', 'pl-' + sid + '-custom', 'custom', false,
        '<span>Custom</span><span class="seg-opt__sub seg-opt__sub--line">Hours / days</span>');
      // disabled while hidden, so a plan booking posts no customMin
      customBlock = '<fieldset class="custom-pick" data-custom hidden disabled>' +
        '<div class="seg-track">' +
          (customMax('hour') >= 1 ? segOption('customUnit', 'cu-' + sid + '-hour', 'hour', true,
            '<span>By hour</span><span class="seg-opt__sub">1 to ' + esc(customMax('hour')) + ' h</span>') : '') +
          (customMax('day') >= 1 ? segOption('customUnit', 'cu-' + sid + '-day', 'day', customMax('hour') < 1,
            '<span>By day</span><span class="seg-opt__sub">1 to ' + esc(customMax('day')) + ' days</span>') : '') +
        '</div>' +
        '<div class="stepper">' +
          '<button type="button" class="stepper__btn lg-hover" data-custom-step="-1" aria-label="One less">' + icon('minus') + '</button>' +
          '<output class="stepper__value" data-custom-value aria-live="polite"></output>' +
          '<button type="button" class="stepper__btn lg-hover" data-custom-step="1" aria-label="One more">' + icon('plus') + '</button>' +
        '</div>' +
        '<input type="range" class="custom-range" name="customCount" min="1" max="' + esc(customMax('hour')) + '" value="3" ' +
          'data-custom-count aria-label="Storage time">' +
        '<input type="hidden" name="customMin" value="" data-custom-min>' +
        '<p class="hint" data-custom-note></p>' +
      '</fieldset>';
    }
    var methodOpts = METHOD_ORDER.map(function (code, i) {
      return segOption('openMethod', 'om-' + slot.slot_id + '-' + code, code, i === 0, '<span>' + esc(METHODS[code].label) + '</span>');
    }).join('');
    return formStart(cfg.bookingUrl, 'reserve', slot, null, ' data-reserve') +
      '<fieldset class="seg-pick"><legend>Storage plan</legend><div class="seg-track">' + planOpts + '</div></fieldset>' +
      customBlock +
      '<fieldset class="seg-pick"><legend>Open method</legend><div class="seg-track">' + methodOpts + '</div></fieldset>' +
      '<p class="hint" data-method-desc></p>' +
      '<div class="pay-now"><span>Taken now</span><strong data-pay-now></strong></div>' +
      '<div class="pay-line"><span>Wallet balance</span><strong data-account-balance></strong></div>' +
      '<button type="submit" class="btn btn--block btn--pill lg-hover" data-reserve-button>Book slot ' + esc(slot.slot_code) + '</button>' +
      '<p class="notice" data-balance-warning hidden>After booking, your wallet must keep at least ' +
        esc(money(bookingBuffer())) + ' to cover a possible late fee. <a href="' + esc(cfg.topupUrl) + '">Top up</a></p>' +
      '<p class="hint">' + esc(rulesHint()) + '</p>' +
    '</form>';
  }

  function updateReserveForm() {
    var found = state.slotId !== null ? findSlot(state.slotId) : null;
    var choice = found ? reserveChoice(found.slot) : null;
    if (!choice) {
      return;
    }
    var customBox = el.panel.querySelector('[data-custom]');
    if (customBox) {
      customBox.hidden = !choice.custom;
      customBox.disabled = !choice.custom;
      if (choice.custom) {
        var range = customBox.querySelector('[data-custom-count]');
        range.max = String(customMax(choice.custom.unit));
        range.value = String(choice.custom.count);
        customBox.querySelector('[data-custom-min]').value = String(choice.custom.minutes);
        customBox.querySelector('[data-custom-value]').textContent = durationText(choice.custom.unit, choice.custom.count);
        customBox.querySelector('[data-custom-note]').textContent = customNote(choice);
      }
    }
    el.panel.querySelector('[data-method-desc]').textContent = methodDesc(choice.method, found.bank);
    el.panel.querySelector('[data-pay-now]').textContent = choice.unavailable ? '—' : choice.price ? money(choice.price) : 'Free';
    if (choice.unavailable) {
      el.panel.querySelector('[data-method-desc]').textContent = 'A custom time cannot be booked right now. Please choose one of the plans.';
    }
    var balanceNode = el.panel.querySelector('[data-account-balance]');
    balanceNode.textContent = money(choice.balance);
    balanceNode.classList.toggle('text-danger', choice.balance < 0);
    var insufficient = !!state.loadedAt && !choice.enough;
    el.panel.querySelector('[data-reserve-button]').disabled = insufficient || choice.unavailable;
    el.panel.querySelector('[data-balance-warning]').hidden = !insufficient;
  }

  function kvHtml(rows) {
    return '<dl class="kv">' + rows.map(function (r) {
      return '<dt>' + r[0] + '</dt><dd>' + r[1] + '</dd>';
    }).join('') + '</dl>';
  }

  // the popup of spec v3 5.3: the amount taken now, the rules, the late fee of the size and the balance left
  function reserveConfirmHtml(slot, bank, choice) {
    var z = sizeInfo(choice.size) || {};
    var rows = [
      ['Slot', esc(slot.slot_code) + ' <span class="muted">' + esc(bank.bank_code) + '</span>'],
      ['Size', esc(choice.size) + (z.size_cm ? ' <span class="muted">' + esc(z.size_cm) + ' cm</span>' : '')],
      ['Storage plan', esc(choice.plan.plan_name)]
    ];
    if (choice.custom) {
      rows.push(['Storage time', esc(durationText(choice.custom.unit, choice.custom.count)) +
        ' <span class="muted">from the first opening · if opened now, due at ' + esc(dueIfOpenedNow(choice.custom.minutes)) + '</span>']);
    }
    rows = rows.concat([
      ['Open method', esc(METHODS[choice.method].label)],
      ['Taken now', '<strong class="dlg__total money">' + (choice.price ? esc(money(choice.price)) : 'Free') + '</strong>']
    ]);
    rows.push(['Balance after', '<span class="money">' + esc(money(choice.after)) + '</span>']);
    var rules = [
      ['check', 'Cancel in the first ' + cancelMinutes() + ' min: full refund. After that until the hold ends: ' + cancelLatePct() + '% refund.'],
      ['clock', 'After ' + holdMinutes() + ' min it can no longer be cancelled: the booking starts by itself and the slot stays locked for you.'],
      ['alert', 'Early, late or not at all, you can use the slot at any time within the paid time. No refund.']
    ];
    if (z.overdue_rate) {
      rules.push(['lock', 'Overdue: the slot locks and a late fee of ' + money(z.overdue_rate) + ' per late hour (size ' + choice.size + ') is taken from your wallet.']);
    }
    return kvHtml(rows) + '<ul class="rule-list">' + rules.map(function (r) {
      return '<li>' + icon(r[0]) + '<span>' + esc(r[1]) + '</span></li>';
    }).join('') + '</ul>';
  }

  function cancelUntil(slot) {
    if (!slot.reserved_at) {
      return null;
    }
    return new Date(parseUtc(slot.reserved_at).getTime() + cancelMinutes() * 60000);
  }

  // spec v3 D4: full refund in the first minutes, then a part until the hold ends. expectedRefund is the amount the
  // popup shows; Deposit_Cancel refuses a lower refund, so a popup left open across the boundary cannot cost money.
  function cancelForm(slot) {
    var now = Date.now();
    var hold = slot.hold_until ? parseUtc(slot.hold_until).getTime() : 0;
    if (hold <= now) {
      return '<p class="hint">The hold time is over, so the booking can no longer be cancelled.</p>';
    }
    var until = cancelUntil(slot);
    var free = until ? until.getTime() : 0;
    var isFree = free > now;
    var paid = Number(slot.paid_amount) || 0;
    var late = lateRefund(paid);
    var head = 'Cancel the booking of slot ' + slot.slot_code + '? ';
    var fullText = head + 'The full ' + money(paid) + ' is refunded to your wallet.';
    var lateText = head + 'More than ' + cancelMinutes() + ' min have passed since booking, so only ' + cancelLatePct() + '% is refunded: ' +
      money(late) + ' to your wallet.';
    var lateLabel = cancelLatePct() + '% refund (' + money(late) + ')';
    return formStart(cfg.bookingUrl, 'cancel', slot, isFree ? fullText : lateText,
        ' data-cancel-until="' + free + '" data-hold-until="' + hold + '" data-late-refund="' + late + '"' +
        ' data-confirm-late="' + esc(lateText) + '" data-late-label="' + esc(lateLabel) + '"' + (isFree ? '' : ' data-late')) +
      hidden('depositId', slot.deposit_id) +
      '<input type="hidden" name="expectedRefund" value="' + (isFree ? paid : late) + '" data-expected-refund>' +
      '<button type="submit" class="btn ghost btn--block">Cancel booking · <span data-cancel-label>' +
        esc(isFree ? 'full refund' : lateLabel) + '</span> · <span data-cancel-left>' +
        esc(leftText(isFree ? free : hold)) + '</span></button>' +
    '</form>';
  }

  function leftText(endMs) {
    var s = Math.max(0, Math.round((endMs - Date.now()) / 1000));
    var m = Math.floor(s / 60);
    var sec = s % 60;
    return m + ':' + (sec < 10 ? '0' : '') + sec + ' left';
  }

  function hourRate(slot) {
    var z = sizeInfo(slot.size);
    return z ? Number(z.hour_rate) || 0 : 0;
  }

  // Deposit_Extend: CEILING(minutes / 60) x the hour price of the size, taken at once
  function extendPrice(slot, minutes) {
    return Math.ceil(minutes / 60) * hourRate(slot);
  }

  var EXTEND_OPTIONS = [30, 60, 120, 240];

  function extendForm(slot) {
    var options = EXTEND_OPTIONS.map(function (m) {
      return '<option value="' + m + '"' + (m === 60 ? ' selected' : '') + '>' +
        (m < 60 ? m + ' min' : (m / 60) + ' h') + ' · ' + esc(money(extendPrice(slot, m))) + '</option>';
    }).join('');
    return formStart(cfg.bookingUrl, 'extend', slot, null, ' data-extend') +
      hidden('depositId', slot.deposit_id) +
      '<h3>Extend online</h3>' +
      '<label class="field"><span>Add time</span><select name="minutes" data-extend-minutes>' + options + '</select></label>' +
      '<p class="hint">' + esc(money(hourRate(slot))) + ' for each extra hour started (size ' + esc(slot.size) + '), taken from your wallet at once. At most 3 times.</p>' +
      '<button type="submit" class="btn btn--block btn--pill lg-hover" data-extend-button>' +
        'Extend · pay ' + esc(money(extendPrice(slot, 60))) + '</button>' +
    '</form>';
  }

  function extendConfirmHtml(slot, minutes) {
    var price = extendPrice(slot, minutes);
    return kvHtml([
      ['Slot', esc(slot.slot_code)],
      ['Add', esc(minutes < 60 ? minutes + ' min' : (minutes / 60) + ' h')],
      ['Taken now', '<strong class="dlg__total money">' + esc(money(price)) + '</strong>'],
      ['Balance after', '<span class="money">' + esc(money((Number(cfg.balance) || 0) - price)) + '</span>']
    ]);
  }

  // the owner's overdue box: locked, late hours, fee taken, debt, and the way out (top up)
  function overdueBoxHtml(slot) {
    var debt = (Number(cfg.balance) || 0) < 0 ? -Number(cfg.balance) : 0;
    return '<div class="overdue-box" role="status">' +
      '<p class="overdue-box__title">' + icon('lock') + 'Overdue, the slot is locked</p>' +
      '<dl class="kv">' +
        '<dt>Late hours charged</dt><dd>' + esc(slot.overdue_hours || 0) + ' h</dd>' +
        '<dt>Late fee taken</dt><dd class="money">' + esc(money(slot.overdue_fee || 0)) + '</dd>' +
        '<dt>Amount owed</dt><dd class="money' + (debt ? ' text-danger' : '') + '">' + esc(money(debt)) + '</dd>' +
      '</dl>' +
      '<p class="hint">' + (debt ? 'Top up until your balance is 0 VND or more, then open the slot to pick up your things. The late fee keeps growing every hour.'
                                  : 'Your balance is enough: open the slot to pick up your things now; the late fee keeps growing every hour.') +
        ' A locked slot cannot be extended.</p>' +
      '<a class="btn btn--block' + (debt ? '' : ' ghost') + '" href="' + esc(cfg.topupUrl) + '">Top up</a>' +
    '</div>';
  }

  // the owner's booking, whatever the slot shows (an OFFLINE box still has the booking): RESERVED until check-in, then ACTIVE
  function bookingPhase(slot) {
    if (!slot.mine || !slot.deposit_id) {
      return null;
    }
    return slot.due_at ? 'ACTIVE' : 'RESERVED';
  }

  // a visitor who is not signed in: the booking form needs an account, so the button opens the popup
  function guestBox() {
    return '<div class="guest-box"><h3>Book this slot</h3>' +
      '<p class="hint">You need an account to book a slot. Sign in or sign up in the small window; the slot you picked stays selected.</p>' +
      '<button type="button" class="btn btn--block btn--pill lg-hover" data-auth-reserve="login">Sign in to book</button>' +
      '<button type="button" class="btn ghost btn--block" data-auth-reserve="register">Create a new account</button></div>';
  }

  function requireLogin(tab) {
    var found = state.slotId !== null ? findSlot(state.slotId) : null;
    if (!window.SmartLockerAuth) {
      window.location.href = cfg.loginUrl;
      return;
    }
    window.SmartLockerAuth.open({
      tab: tab,
      reason: found ? 'Sign in or sign up to book slot ' + found.slot.slot_code + '. The slot you picked stays selected.' : ''
    }).then(function (ok) {
      if (ok) {
        afterSignIn();
      }
    });
  }

  // the visitor just signed in (popup, or another tab): take the new menus and role without reloading the page,
  // keep the area and the slot, and the slot card then shows the booking form
  var SWAPPED = ['glassTabs', 'glassAccount', 'glassBalance'];

  function afterSignIn() {
    fetch(window.location.pathname + window.location.search, { credentials: 'same-origin', headers: { Accept: 'text/html' } })
      .then(function (res) { return res.text(); })
      .then(function (html) {
        var doc = new DOMParser().parseFromString(html, 'text/html');
        var app = doc.getElementById('lockerApp');
        if (!app || !doc.getElementById('glassAccount')) {
          throw new Error('SHELL');   // a staff account gets the map with the sidebar: the catch reloads the page
        }
        SWAPPED.forEach(function (id) {
          var fresh = doc.getElementById(id);
          var current = document.getElementById(id);
          if (fresh && current) {
            current.innerHTML = fresh.innerHTML;
          }
        });
        cfg.role = (app.getAttribute('data-role') || 'END_USER').toUpperCase();
        cfg.balance = Number(app.getAttribute('data-balance')) || 0;
        root.setAttribute('data-role', cfg.role);
        state.panelDirty = false;
        state.panelSig = null;
        state.popupOpen = false;
        toast('Signed in.' + (cfg.role === 'END_USER' && state.slotId !== null ? ' Choose a plan and an open method, then press Book slot.' : ''));
        load();
      })
      .catch(function () {
        window.location.reload();
      });
  }

  // There is no login page: /LoginController, /RegisterController and a page that needs a sign-in send the visitor
  // here with ?login=1 or ?register=1, and ?next= for the page to open after the sign-in (a path of this app only).
  function openAskedSignIn() {
    var tab = readParam('register') ? 'register' : (readParam('login') ? 'login' : null);
    var next = readParam('next');
    var back = next && /^\/[A-Za-z][\w\/-]*(\?[^#]*)?$/.test(next) && next.indexOf('/api/') !== 0 ? next : null;
    syncUrl();   // the address keeps only the area and the slot
    // without <dialog> the popup falls back to /LoginController, which sends the visitor back here: no loop
    if (!tab || cfg.role !== 'GUEST' || !window.SmartLockerAuth || !window.HTMLDialogElement) {
      return;
    }
    window.SmartLockerAuth.open({ tab: tab, reason: back ? 'The page you opened needs a sign-in.' : '' }).then(function (ok) {
      if (!ok) {
        return;
      }
      if (back) {
        window.location.href = cfg.ctx + back;
      } else {
        afterSignIn();
      }
    });
  }

  // v7: the page of the box (/k/{device}): a phone opens the owner's slot there after a tap on its NFC reader; a demo box
  // has no reader, so its page opens without a tap
  function boxPageLink(bank) {
    if (!bank || !bank.device_code) {
      return '';
    }
    return '<a class="btn ghost btn--block" href="' + esc(cfg.ctx + '/k/' + encodeURIComponent(bank.device_code)) + '">' +
      'Open with your phone</a>';
  }

  function actionsHtml(slot, bank) {
    var role = cfg.role;
    var parts = [];
    if (role === 'GUEST') {
      if (slot.status === 'AVAILABLE') {
        parts.push(guestBox());
      }
    } else if (role === 'END_USER') {
      if (slot.status === 'AVAILABLE') {
        parts.push(reserveForm(slot));
      } else if (bookingPhase(slot) === 'RESERVED') {
        parts.push('<a class="btn btn--block btn--pill lg-hover" href="' + esc(cfg.myLockerUrl) + '">' + icon('unlock') + 'How to open it, in My locker</a>');
        parts.push(boxPageLink(bank));
        parts.push(cancelForm(slot));
      } else if (slot.mine && slot.locked) {
        parts.push(overdueBoxHtml(slot));
        parts.push('<a class="btn ghost btn--block" href="' + esc(cfg.myLockerUrl) + '">View in My locker</a>');
      } else if (bookingPhase(slot) === 'ACTIVE') {
        parts.push(boxPageLink(bank));
        parts.push(extendForm(slot));
      }
    }
    return parts.join('');
  }

  // prices of this slot's size, before the user pays from the account balance
  function priceHtml(slot) {
    var plans = (state.data && state.data.plans) || [];
    return plans.map(function (p) {
      var price = planPrice(p, slot.size);
      return '<span class="price-row"><span>' + esc(p.plan_name) + '</span><strong>' + (price ? esc(money(price)) : 'Free') + '</strong></span>';
    }).join('') + (customCfg() ? '<span class="price-row"><span>Custom ' + esc(customMax('day')) + ' days</span><strong>' +
      esc(money(customPrice('day', customMax('day'), slot.size))) + '</strong></span>' : '');
  }

  // a slot that is not free and not the user's only shows why; the user's own slot and a visitor's free slot show facts
  function factsHtml(slot, bank) {
    var guestPrices = cfg.role === 'GUEST' && slot.status === 'AVAILABLE';
    if (!slot.mine && !guestPrices) {
      return '';
    }
    var z = sizeInfo(slot.size);
    var facts = [];
    var prices = slot.status === 'AVAILABLE' ? priceHtml(slot) : '';
    if (prices) {
      facts.push(fact('Price, size ' + esc(slot.size), '<span class="price-list">' + prices + '</span>'));
    }
    if (bank.device_status !== 'ACTIVE') {
      facts.push(fact('Device', esc(deviceLabel(bank.device_status)) + (bank.device_code ? ' <span class="muted">' + esc(bank.device_code) + '</span>' : '')));
    }
    if (z && z.overdue_rate) {
      facts.push(fact('Late fee', esc(money(z.overdue_rate)) + ' <span class="muted">per hour</span>'));
    }
    var phase = bookingPhase(slot);
    if ((slot.status === 'RESERVED' || phase === 'RESERVED') && slot.hold_until && phase !== 'ACTIVE') {
      facts.push(fact(slot.mine ? 'Starts by itself at' : 'Held until', formatTime(slot.hold_until) + countdownHtml(slot.hold_until)));
    }
    if ((slot.status === 'OCCUPIED' || slot.status === 'OVERDUE' || phase === 'ACTIVE' || slot.locked) && slot.due_at) {
      facts.push(fact('Due time', formatTime(slot.due_at) + countdownHtml(slot.due_at)));
    }
    if (slot.escalated) {
      facts.push(fact('Escalation', '<span class="text-danger">Escalated to staff (long overdue)</span>'));
    }
    return facts.length ? '<dl class="facts">' + facts.join('') + '</dl>' : '';
  }

  function panelHtml(found) {
    var slot = found.slot;
    var bank = found.bank;
    var st = statusInfo(slot.status);
    var z = sizeInfo(slot.size);
    var dims = sizeDims(slot);
    var fits = slot.status === 'AVAILABLE' && z && z.items && z.items.length
      ? '<p class="size-fits"><b>Fits:</b> ' + esc(z.items.join(', ')) + '</p>' : '';
    return '<div class="card-head"><div>' +
        '<h2 class="card-title" id="panelTitle" tabindex="-1">Slot ' + esc(slot.slot_code) + '</h2>' +
        '<p class="card-sub">' + esc(bank.name) + ' · size ' + esc(slot.size) + (dims ? ' · ' + esc(dims) : '') + '</p></div>' +
        '<button type="button" class="round-btn lg-hover" data-close aria-label="Deselect the slot">' + icon('close') + '</button>' +
      '</div>' +
      '<span class="status-pill st-' + esc(slot.locked ? 'OVERDUE' : slot.status) + '">' + icon(slot.locked ? 'lock' : st.icon) +
        (slot.locked ? 'Overdue lock' : esc(st.label)) + (slot.mine ? ' · yours' : '') + '</span>' +
      '<p class="panel-desc">' + esc(describe(slot)) + '</p>' +
      fits +
      factsHtml(slot, bank) +
      '<div class="panel-actions">' + actionsHtml(slot, bank) + '</div>';
  }

  // what the card shows about a slot; the 10 s refresh redraws the card only when this changes
  function panelSignature(found) {
    var s = found.slot;
    return [cfg.role, s.slot_id, s.status, s.locked, s.mine, s.deposit_id, s.hold_until, s.due_at, s.reserved_at,
      s.escalated, s.occupant, s.alert ? s.alert.alert_id : '', s.ticket_id, s.overdue_hours, s.overdue_fee,
      found.bank.device_status, (state.data.fp_devices || []).join(',')].join('|');
  }

  function renderPanel(force) {
    var found = state.slotId !== null && state.data ? findSlot(state.slotId) : null;
    if (!found) {
      if (state.data && banks().length) {
        state.slotId = null;   // before the first load of the area, keep the slot asked for in the URL
      }
      el.panel.hidden = true;
      el.panel.innerHTML = '';
      state.panelDirty = false;
      state.panelSig = null;
      placePanel();
      return;
    }
    var sig = panelSignature(found);
    // keep what the user is choosing or typing when a background refresh brings the same slot
    if (!force && (state.panelDirty || sig === state.panelSig)) {
      updateReserveForm();
      return;
    }
    var appearing = el.panel.hidden;
    var otherSlot = !appearing && force;
    el.panel.innerHTML = panelHtml(found);
    el.panel.hidden = false;
    state.panelSig = sig;
    state.panelDirty = false;
    updateReserveForm();
    placePanel();
    if (appearing) {
      motion.pop(el.panel);
    } else if (otherSlot) {
      motion.slideIn(el.panel, 1);
    }
  }

  function renderDetail() {
    renderHead();
    renderChips();
    renderBanks();
  }

  function renderAll() {
    setSheetMode(state.sheetMode);
    renderAreas();
    renderNear();
    renderDetail();
    renderPanel(false);
    renderSync();
    renderBalance();
    fitSheet();
    renderPlace();
  }

  /* ---------- nearest area (spec v3 D6): the position stays in the browser, it is never sent ---------- */

  var GEO_MIN_MS = 10000;   // at most one update every 10 seconds
  var geo = { pos: null, watchId: null, lastAt: 0, message: '', wanted: false, picked: false };

  function hasCoords(a) {
    return a && typeof a.latitude === 'number' && typeof a.longitude === 'number';
  }

  // great-circle distance in metres
  function haversine(lat1, lng1, lat2, lng2) {
    var rad = Math.PI / 180;
    var dLat = (lat2 - lat1) * rad;
    var dLng = (lng2 - lng1) * rad;
    var h = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos(lat1 * rad) * Math.cos(lat2 * rad) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    return 2 * 6371000 * Math.asin(Math.min(1, Math.sqrt(h)));
  }

  function distanceTo(a) {
    return geo.pos && hasCoords(a) ? haversine(geo.pos.lat, geo.pos.lng, a.latitude, a.longitude) : null;
  }

  function formatDistance(m) {
    return m < 1000 ? Math.round(m / 10) * 10 + ' m' : (m / 1000).toFixed(1) + ' km';
  }

  // nearest first; areas without coordinates keep their order at the end
  function sortedAreas(list) {
    if (!geo.pos) {
      return list;
    }
    return list.map(function (a, i) {
      return { a: a, i: i, d: distanceTo(a) };
    }).sort(function (x, y) {
      if (x.d === null || y.d === null) {
        return x.d === null && y.d === null ? x.i - y.i : (x.d === null ? 1 : -1);
      }
      return x.d - y.d;
    }).map(function (x) {
      return x.a;
    });
  }

  function directionsUrl(a) {
    return 'https://www.google.com/maps/dir/?api=1&destination=' + Number(a.latitude) + ',' + Number(a.longitude) +
      '&travelmode=walking';
  }

  function renderNear() {
    var list = areas();
    var html = '';
    if (state.placed === 0 && list.length) {
      html += '<p>No area has coordinates yet, so the map has no pins. An administrator enters the latitude and longitude on the Areas page.</p>';
    }
    if (list.some(hasCoords) && !geo.pos && geo.watchId === null) {
      html += '<p><button type="button" class="chip lg-hover" data-geo-start>' + icon('locate') + 'Sort by distance</button></p>' +
        (geo.message ? '' : '<p>Let the browser share your location to sort the areas from near to far. The location stays on your device and is never sent.</p>');
    }
    if (geo.message) {
      html += '<p class="near__msg" role="status">' + esc(geo.message) + '</p>';
    }
    el.near.innerHTML = html;
  }

  function geoStop() {
    if (geo.watchId !== null) {
      navigator.geolocation.clearWatch(geo.watchId);
      geo.watchId = null;
    }
  }

  function geoStart() {
    geo.wanted = true;
    if (!('geolocation' in navigator)) {
      geo.message = 'This browser does not support location. The area list still works as usual.';
    } else if (window.isSecureContext === false) {
      geo.message = 'Location only works on an HTTPS page. The area list still works as usual.';
    } else if (geo.watchId === null) {
      geo.message = geo.pos ? '' : 'Finding your location…';
      geo.watchId = navigator.geolocation.watchPosition(onPosition, onGeoError,
        { enableHighAccuracy: false, maximumAge: GEO_MIN_MS, timeout: 20000 });
    }
    renderNear();
  }

  function onPosition(p) {
    var now = Date.now();
    if (geo.pos && now - geo.lastAt < GEO_MIN_MS) {
      return;
    }
    geo.lastAt = now;
    geo.pos = { lat: p.coords.latitude, lng: p.coords.longitude, acc: p.coords.accuracy };
    if (areaMap) {
      areaMap.setUser(geo.pos);
    }
    geo.message = '';
    // the first fix shows the nearest area on the map, unless the visitor already chose one or the link names one
    if (!geo.picked) {
      geo.picked = true;
      var nearest = state.data && !myBooking() && !state.userChoseArea && !readParam('area') ? sortedAreas(areas())[0] : null;
      if (nearest && distanceTo(nearest) !== null && areaMap) {
        areaMap.focus(nearest.area_code);
      }
    }
    renderAreas();
    renderNear();
    renderHead();
    renderPlace();
  }

  function onGeoError(err) {
    if (err.code === 1) {
      geoStop();
      geo.wanted = false;
      geo.message = 'Location access is not allowed. Turn on the location permission for this page in your browser to see the nearest lockers.';
    } else if (geo.pos) {
      geo.message = 'Could not update your location; distances use the previous one.';
    } else if (err.code === 3) {
      geo.message = 'Location is taking too long, retrying.';
    } else {
      geo.message = 'Could not find your location. The area list still works as usual.';
    }
    renderNear();
  }

  // stop the GPS while the tab is hidden, resume when it comes back
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) {
      geoStop();
    } else if (geo.wanted) {
      geoStart();
    }
  });

  /* ---------- sheet: list / one area, and the phone bottom sheet ---------- */

  function setSheetMode(mode) {
    var changed = state.sheetMode !== mode;
    state.sheetMode = mode;
    el.listView.hidden = mode !== 'list';
    el.detailView.hidden = mode !== 'detail';
    el.sheet.setAttribute('aria-label', mode === 'list' ? 'Locker areas' : 'Area details');
    if (changed) {
      motion.slideIn(mode === 'list' ? el.listView : el.detailView, mode === 'list' ? -1 : 1);
    }
  }

  // on a phone the slot card lives in the bottom sheet, elsewhere it floats on its own
  function placePanel() {
    var host = isPhone() ? el.sheetSlot : root;
    if (el.panel.parentNode !== host) {
      host.appendChild(el.panel);
    }
    el.sheet.classList.toggle('has-slot', isPhone() && !el.panel.hidden);
    fitSheet();
  }

  var SNAPS = ['peek', 'half', 'full'];

  // the three heights of the phone sheet, in px: between the search pill and the tab bar, and never taller than
  // what it holds (a short list gets a short sheet, not empty glass)
  function snapHeights() {
    var top = el.search.closest('.search-pill').getBoundingClientRect().bottom + 8;
    var bottom = el.sheet.getBoundingClientRect().bottom;
    var room = Math.max(160, bottom - top);
    var content = el.sheet.querySelector('.sheet__grab').offsetHeight + bodyContentHeight() +
      el.sheet.querySelector('.sheet__foot').offsetHeight + 2;
    var full = Math.min(room, Math.max(132, content));
    return { peek: Math.min(132, full), half: Math.min(Math.round(room * 0.5), full), full: full };
  }

  // the height the body's content needs (scrollHeight never drops below the height shown, so it cannot shrink)
  function bodyContentHeight() {
    var box = el.sheetBody.getBoundingClientRect();
    var top = box.top - el.sheetBody.scrollTop;
    var bottom = 0;
    for (var i = 0; i < el.sheetBody.children.length; i++) {
      var kid = el.sheetBody.children[i];
      if (kid.getClientRects().length) {
        bottom = Math.max(bottom, kid.getBoundingClientRect().bottom - top);
      }
    }
    return Math.ceil(bottom + parseFloat(getComputedStyle(el.sheetBody).paddingBottom || 0));
  }

  // the content of the sheet changed: its height follows (only when it really differs)
  function fitSheet() {
    if (isPhone() && Math.abs(snapHeights()[state.snap] - el.sheet.getBoundingClientRect().height) > 2) {
      setSnap(state.snap);
    }
  }

  // animate: a spring of Motion to the new height (taps, drags, a chosen area); a new layout sets it at once
  function setSnap(snap, animate) {
    state.snap = snap;
    if (!isPhone()) {
      return;
    }
    var px = snapHeights()[snap];
    if (animate === false) {
      motion.stopHeight(el.sheet);
      el.sheet.style.height = px + 'px';
    } else {
      motion.height(el.sheet, px);
    }
  }

  function layoutSheet() {
    var grab = el.sheet.querySelector('[data-sheet-grab]');
    if (isPhone()) {
      grab.removeAttribute('aria-hidden');
      grab.setAttribute('tabindex', '0');
      grab.setAttribute('aria-label', 'Change the panel height (low, medium, high)');
      setSnap(state.snap, false);
    } else {
      grab.setAttribute('aria-hidden', 'true');
      grab.setAttribute('tabindex', '-1');
      grab.removeAttribute('aria-label');
      el.sheet.style.height = '';
    }
    placePanel();
  }

  // drag the grabber; a tap without a move steps to the next height
  function bindSheetDrag() {
    var grab = el.sheet.querySelector('[data-sheet-grab]');
    var start = null;
    grab.addEventListener('pointerdown', function (e) {
      if (!isPhone()) {
        return;
      }
      start = { y: e.clientY, h: el.sheet.getBoundingClientRect().height, moved: false };
      grab.setPointerCapture(e.pointerId);
      motion.stopHeight(el.sheet);
    });
    grab.addEventListener('pointermove', function (e) {
      if (!start) {
        return;
      }
      var dy = e.clientY - start.y;
      if (Math.abs(dy) > 4) {
        start.moved = true;
      }
      var hs = snapHeights();
      el.sheet.style.height = Math.max(hs.peek, Math.min(hs.full, start.h - dy)) + 'px';
    });
    function end() {
      if (!start) {
        return;
      }
      var hs = snapHeights();
      var h = el.sheet.getBoundingClientRect().height;
      var next;
      if (!start.moved) {
        next = SNAPS[(SNAPS.indexOf(state.snap) + 1) % SNAPS.length];
      } else {
        next = SNAPS.reduce(function (best, s) {
          return Math.abs(hs[s] - h) < Math.abs(hs[best] - h) ? s : best;
        }, 'peek');
      }
      start = null;
      setSnap(next);
    }
    grab.addEventListener('pointerup', end);
    grab.addEventListener('pointercancel', end);
    grab.addEventListener('keydown', function (e) {
      if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
        e.preventDefault();
        var i = SNAPS.indexOf(state.snap) + (e.key === 'ArrowUp' ? 1 : -1);
        setSnap(SNAPS[Math.max(0, Math.min(SNAPS.length - 1, i))]);
      }
    });
    // a click from the keyboard (Enter, Space) has no pointer: step as a tap does
    grab.addEventListener('click', function (e) {
      if (isPhone() && e.detail === 0) {
        setSnap(SNAPS[(SNAPS.indexOf(state.snap) + 1) % SNAPS.length]);
      }
    });
  }

  // the px the islands cover, so a pin flown to stays in the free part of the map
  function mapPadding() {
    var alertBottom = el.place.hidden ? 0 : el.place.getBoundingClientRect().bottom + 8;   // the pin stays out from under the warning
    if (isPhone()) {
      return { left: 0, right: 56, top: Math.max(64, alertBottom), bottom: window.innerHeight - el.sheet.getBoundingClientRect().top };
    }
    return { left: el.sheet.getBoundingClientRect().right, right: 72, top: alertBottom, bottom: 76 };
  }

  /* ---------- selection ---------- */

  function selectSlot(id) {
    state.slotId = id;
    state.returnFocus = id;
    renderBanks();
    renderPanel(true);
    syncUrl();
    if (isPhone()) {
      setSnap('full');
      el.sheetBody.scrollTop = 0;
    }
    var title = document.getElementById('panelTitle');
    if (title) {
      title.focus({ preventScroll: true });
    }
  }

  function clearSelection() {
    state.slotId = null;
    renderBanks();
    syncUrl();
    // the card leaves with a short fade before it is hidden; a slot chosen meanwhile keeps it open
    motion.leave(el.panel).then(function () {
      el.panel.style.removeProperty('transform');
      el.panel.style.removeProperty('opacity');
      if (state.slotId === null) {
        renderPanel(true);
      }
    });
    if (state.returnFocus) {
      var target = root.querySelector('[data-slot="' + state.returnFocus + '"]');
      if (target) {
        target.focus({ preventScroll: true });
      }
    }
  }

  // the list rows and the pins both end here
  function selectArea(code, byItself) {
    if (!byItself) {
      state.userChoseArea = true;
    }
    var changed = code !== state.area;
    state.area = code;
    if (changed) {
      state.slotId = null;
      state.filters = {};
      state.animateBanks = true;
      state.etag = null;   // the banks are emptied: the next answer must come in full, not as a 304
      if (state.data) {
        state.data.banks = [];
      }
    }
    setSheetMode('detail');
    el.sheetBody.scrollTop = 0;
    if (isPhone() && state.snap === 'peek') {
      setSnap('half');
    }
    renderAreas();
    renderDetail();
    renderPanel(true);
    syncUrl();
    if (areaMap) {
      areaMap.focus(code);
    }
    motion.bump(el.mapCanvas.querySelector('.pin.is-active .ring'));
    if (changed) {
      load();
    }
  }

  function backToList() {
    state.slotId = null;
    setSheetMode('list');
    renderPanel(true);
    renderAreas();
    syncUrl();
    el.sheetBody.scrollTop = 0;
    var row = root.querySelector('.area-row[data-area="' + state.area + '"]');
    if (row) {
      row.focus({ preventScroll: false });
    }
  }

  /* ---------- data ---------- */

  // optional fields get defaults, so a smaller API answer still renders
  function normalize(data) {
    data.areas = data.areas || [];
    data.banks = data.banks || [];
    data.banks.forEach(function (bank) {
      bank.name = bank.name || bank.bank_code;
      bank.slots = bank.slots || [];
    });
    return data;
  }

  function onData(data) {
    if (data.guest === true && cfg.role !== 'GUEST') {
      window.location.reload();   // the session ended: draw the page for a visitor
      return;
    }
    if (data.guest === false && cfg.role === 'GUEST') {
      afterSignIn();              // signed in from another tab
      return;
    }
    state.data = normalize(data);
    if (data.balance !== undefined && data.balance !== null) {
      cfg.balance = Number(data.balance) || 0;
    }
    state.error = null;
    state.loadedAt = Date.now();
    if (data.area && data.area.area_code) {
      state.area = data.area.area_code;
    }
    if (state.popupOpen) {
      state.stale = true;   // a fetch that started before the popup opened: draw it after the popup (next refresh)
      return;
    }
    state.stale = false;
    renderAll();
  }

  // nothing changed since the last answer (304): only the "updated" time moves, nothing is drawn again
  function onSame() {
    state.error = null;
    state.loadedAt = Date.now();
    if (state.stale && !state.popupOpen) {
      state.stale = false;
      renderAll();
    } else {
      renderSync();
    }
  }

  function load() {
    var asked = state.area;
    var url = cfg.api + (cfg.api.indexOf('?') === -1 ? '?' : '&') + 'area=' + encodeURIComponent(asked || '');
    var headers = { Accept: 'application/json' };
    if (state.etag && state.etagUrl === url) {
      headers['If-None-Match'] = state.etag;   // LockerMapApi answers 304 when the JSON is the same
    }
    // no-store: the browser cache stays out of it, so a 304 reaches this code and the old data is kept
    fetch(url, { credentials: 'same-origin', cache: 'no-store', headers: headers })
      .then(function (res) {
        if (res.status === 304) {
          return null;
        }
        var type = res.headers.get('Content-Type') || '';
        if (type.indexOf('json') === -1) {
          // SecurityFilter answered with the login page: the session has expired
          throw new Error('SESSION');
        }
        if (!res.ok) {
          throw new Error('HTTP ' + res.status);
        }
        return res.json().then(function (data) {
          return { data: data, etag: res.headers.get('ETag') };
        });
      })
      .then(function (answer) {
        if (asked && asked !== state.area) {
          return;   // the user picked another area while this answer was on its way
        }
        if (answer === null) {
          onSame();
        } else {
          state.etag = answer.etag;   // only an answer that is drawn: a 304 later means "what is on screen"
          state.etagUrl = url;
          onData(answer.data);
        }
      })
      .catch(function (err) {
        var first = !state.error;
        state.error = err;
        renderSync();
        if (err.message === 'SESSION') {
          toast('Your session has expired. Please sign in again.', 'error');
          window.location.reload();
        } else if (first) {
          toast('Could not load the locker map. Retrying every 10 s.', 'error');
        }
      });
  }

  /* ---------- events ---------- */

  function onClick(e) {
    var target = e.target.closest('[data-area],[data-slot],[data-filter],[data-filter-clear],[data-close],[data-refresh],' +
      '[data-geo-start],[data-map-fit],[data-map-me],[data-map-zoom],[data-sheet-list],[data-auth-reserve],' +
      '[data-place-show],[data-place-close],[data-card-answer]');
    if (!target) {
      return;
    }
    if (target.hasAttribute('data-area')) {
      selectArea(target.getAttribute('data-area'));
    } else if (target.hasAttribute('data-card-answer')) {
      answerCard(target);
    } else if (target.hasAttribute('data-place-show')) {
      if (myBooking()) {
        selectArea(myBooking().area_code);
        motion.bump(el.mapCanvas.querySelector('.pin.is-target .ring'));
      }
    } else if (target.hasAttribute('data-place-close')) {
      place.dismissed = place.sig;
      renderPlace();
    } else if (target.hasAttribute('data-map-fit')) {
      if (areaMap) {
        areaMap.fitAll();
      }
    } else if (target.hasAttribute('data-map-me')) {
      if (areaMap && areaMap.hasUser()) {
        areaMap.focusUser();
      } else {
        geoStart();
      }
    } else if (target.hasAttribute('data-map-zoom')) {
      if (areaMap) {
        areaMap.zoom(target.getAttribute('data-map-zoom') === 'in' ? 1 : -1);
      }
    } else if (target.hasAttribute('data-sheet-list')) {
      backToList();
    } else if (target.hasAttribute('data-auth-reserve')) {
      requireLogin(target.getAttribute('data-auth-reserve'));
    } else if (target.hasAttribute('data-slot')) {
      selectSlot(toInt(target.getAttribute('data-slot')));
    } else if (target.hasAttribute('data-filter')) {
      var status = target.getAttribute('data-filter');
      state.filters[status] = !state.filters[status];
      renderChips();
      renderBanks();
    } else if (target.hasAttribute('data-filter-clear')) {
      state.filters = {};
      renderChips();
      renderBanks();
    } else if (target.hasAttribute('data-close')) {
      clearSelection();
    } else if (target.hasAttribute('data-refresh')) {
      load();
    } else if (target.hasAttribute('data-geo-start')) {
      geoStart();
    }
  }

  // the confirm popup of js/app.js; on OK the form is submitted again with data-confirmed="1"
  function askFirst(form, opts, submitter) {
    var wasDirty = state.panelDirty;
    state.panelDirty = true;   // the 10 s refresh must not replace this form while the popup is open
    state.popupOpen = true;    // nor redraw the banks (the ADMIN reconnect form lives there)
    window.SmartLocker.confirm(opts).then(function (yes) {
      state.popupOpen = false;
      if (!yes) {
        state.panelDirty = wasDirty;   // "Back": the card follows the refresh again
        return;
      }
      if (!form.isConnected) {
        toast('The slot has just changed status. Please try again.', 'error');
        return;
      }
      form.setAttribute('data-confirmed', '1');
      if (form.requestSubmit) {
        form.requestSubmit(submitter && submitter.form === form ? submitter : undefined);
      } else {
        form.submit();
      }
    });
  }

  function onSubmit(e) {
    var form = e.target;
    if (!form.classList.contains('action-form')) {
      return;
    }
    var isReserve = form.hasAttribute('data-reserve');
    var isExtend = form.hasAttribute('data-extend');
    var needsConfirm = isReserve || isExtend || form.hasAttribute('data-confirm');
    if (needsConfirm && form.getAttribute('data-confirmed') !== '1' && window.SmartLocker && window.SmartLocker.confirm) {
      e.preventDefault();
      if (isReserve) {
        var found = findSlot(toInt(form.querySelector('[name="slotId"]').value));
        var choice = found ? reserveChoice(found.slot) : null;
        if (!found || !choice) {
          return;
        }
        askFirst(form, {
          title: 'Confirm booking of slot ' + found.slot.slot_code,
          html: reserveConfirmHtml(found.slot, found.bank, choice),
          okText: choice.price ? 'Book and pay ' + money(choice.price) : 'Book slot'
        }, e.submitter);
      } else if (isExtend) {
        var target = findSlot(toInt(form.querySelector('[name="slotId"]').value));
        var minutes = toInt(form.querySelector('[name="minutes"]').value) || 60;
        if (!target) {
          return;
        }
        askFirst(form, {
          title: 'Extend slot ' + target.slot.slot_code,
          html: extendConfirmHtml(target.slot, minutes),
          okText: 'Extend and pay ' + money(extendPrice(target.slot, minutes))   // the amount taken now
        }, e.submitter);
      } else {
        askFirst(form, {
          title: 'Confirm',
          text: form.getAttribute('data-confirm'),
          okText: 'OK',
          danger: true
        }, e.submitter);
      }
      return;
    }
    // js/app.js clears data-confirmed for forms with data-confirm; the reserve and extend forms have none
    if (isReserve || isExtend) {
      form.removeAttribute('data-confirmed');
    }
    // let the browser post the form, the controller redirects back with a flash message
    var button = form.querySelector('[type="submit"]');
    if (button) {
      button.disabled = true;
      button.textContent = 'Sending…';
    }
  }

  function bindEvents() {
    root.addEventListener('click', onClick);
    root.addEventListener('submit', onSubmit);
    el.panel.addEventListener('input', function (e) {
      state.panelDirty = true;
      if (e.target.hasAttribute('data-custom-count')) {
        updateReserveForm();
      }
    });
    el.panel.addEventListener('click', function (e) {
      var step = e.target.closest ? e.target.closest('[data-custom-step]') : null;
      var range = step ? el.panel.querySelector('[data-custom-count]') : null;
      if (range) {
        state.panelDirty = true;
        range.value = String(Math.min(Math.max((toInt(range.value) || 1) + toInt(step.getAttribute('data-custom-step')), 1),
          toInt(range.max) || 1));
        updateReserveForm();
      }
    });
    el.panel.addEventListener('change', function (e) {
      if (e.target.name === 'planId' || e.target.name === 'openMethod' || e.target.name === 'customUnit') {
        state.panelDirty = true;
        if (e.target.name === 'customUnit') {
          // a new unit starts from a sensible count: 3 hours (no fixed plan) or 2 days (the first discount)
          var count = el.panel.querySelector('[data-custom-count]');
          count.max = String(customMax(e.target.value));
          count.value = e.target.value === 'day' ? '2' : '3';
        }
        updateReserveForm();
      }
      if (e.target.hasAttribute('data-extend-minutes')) {
        var found = findSlot(state.slotId);
        var btn = el.panel.querySelector('[data-extend-button]');
        if (found && btn) {
          btn.textContent = 'Extend · pay ' + money(extendPrice(found.slot, toInt(e.target.value) || 60));
        }
      }
    });
    el.search.addEventListener('input', function () {
      state.query = el.search.value.trim().toLowerCase();
      renderAreas();
      renderBanks();
    });
    el.search.addEventListener('keydown', function (e) {
      if (e.key !== 'Enter') {
        return;
      }
      e.preventDefault();
      // one area of the list, or one slot of the open area
      if (state.sheetMode === 'detail') {
        var matches = root.querySelectorAll('.slot.is-match');
        if (matches.length === 1) {
          selectSlot(toInt(matches[0].getAttribute('data-slot')));
          return;
        }
      }
      var rows = areas().filter(areaMatches);
      if (rows.length === 1) {
        selectArea(rows[0].area_code);
      }
    });
    document.addEventListener('keydown', function (e) {
      // Esc inside the confirm popup only closes the popup; a menu of the tab bar handles its own Esc
      if (e.key === 'Escape' && !e.defaultPrevented && !el.panel.hidden && !document.querySelector('dialog[open]')) {
        clearSelection();
      }
    });
    var onLayoutChange = function () {
      layoutSheet();
    };
    if (phoneQuery.addEventListener) {
      phoneQuery.addEventListener('change', onLayoutChange);
    } else {
      phoneQuery.addListener(onLayoutChange);
    }
    window.addEventListener('resize', function () {
      if (isPhone()) {
        setSnap(state.snap, false);
      }
    });
    bindSheetDrag();
    bindGlassHover();
  }

  // liquid glass hover (css/locker-map.css): the light of an island and of the button under the pointer follows it.
  // The island's light is a child layer moved with a transform: writing a variable on the blurred island itself made
  // the browser blur it again on every move (about 26 frames a second over the sheet).
  function bindGlassHover() {
    if (!window.matchMedia || !window.matchMedia('(hover: hover) and (pointer: fine)').matches) {
      return;
    }
    var last = null;
    var queued = false;
    var litGlare = null;
    var lastButton = null;
    var bx = -1;
    var by = -1;

    // null for an island that cannot hold the light: a list (a <span> is not list content), one laid out static
    // (css/locker-map.css makes the static islands relative), or one drawn without blur (reduced transparency)
    function glareOf(island) {
      var glare = island.firstElementChild;
      if (glare && glare.classList.contains('glass__glare')) {
        return glare;
      }
      var css = window.getComputedStyle(island);
      if (island.tagName === 'UL' || island.tagName === 'OL' || css.position === 'static' ||
          (css.backdropFilter || css.webkitBackdropFilter || 'none') === 'none') {
        return null;
      }
      glare = document.createElement('span');
      glare.className = 'glass__glare';
      glare.setAttribute('aria-hidden', 'true');
      glare.appendChild(document.createElement('i'));
      island.insertBefore(glare, island.firstChild);
      return glare;
    }

    function frame() {
      queued = false;
      var target = last.target && last.target.closest ? last.target : null;
      var island = target && target.closest('.glass');
      var glare = island ? glareOf(island) : null;
      if (glare !== litGlare) {
        if (litGlare) {
          litGlare.classList.remove('is-on');
        }
        if (glare) {
          glare.classList.add('is-on');
        }
        litGlare = glare;
      }
      if (glare) {
        var r = island.getBoundingClientRect();
        glare.firstChild.style.transform = 'translate(' + Math.round(last.clientX - r.left) + 'px,' + Math.round(last.clientY - r.top) + 'px)';
      }
      var button = target && target.closest('.lg-hover');
      if (button) {
        var br = button.getBoundingClientRect();
        var x = Math.round(last.clientX - br.left);
        var y = Math.round(last.clientY - br.top);
        // a button is small: a move of a few pixels does not show, so it is not drawn again for it
        if (button !== lastButton || Math.abs(x - bx) > 3 || Math.abs(y - by) > 3) {
          button.style.setProperty('--mx', x + 'px');
          button.style.setProperty('--my', y + 'px');
          lastButton = button;
          bx = x;
          by = y;
        }
      }
    }

    document.addEventListener('pointermove', function (e) {
      last = e;
      if (!queued) {
        queued = true;
        window.requestAnimationFrame(frame);
      }
    }, { passive: true });
    document.addEventListener('pointerleave', function () {
      if (litGlare) {
        litGlare.classList.remove('is-on');
        litGlare = null;
      }
    });
  }

  function tick() {
    renderSync();
    var nodes = el.panel.querySelectorAll('[data-countdown]');
    for (var i = 0; i < nodes.length; i++) {
      var c = formatCountdown(nodes[i].getAttribute('data-countdown'));
      nodes[i].textContent = c.text;
      nodes[i].classList.toggle('is-late', c.late);
    }
    // the cancel button (spec v3 D4): partial refund once the free minutes end, gone when the hold ends, no reload.
    // Frozen while a confirm popup is open (dialog.dlg: the map's own panel is a dialog too).
    var cancels = document.querySelector('dialog.dlg[open]') ? [] : el.panel.querySelectorAll('form[data-cancel-until]');
    for (var k = 0; k < cancels.length; k++) {
      var form = cancels[k];
      var free = Number(form.getAttribute('data-cancel-until'));
      var hold = Number(form.getAttribute('data-hold-until'));
      var now = Date.now();
      if (hold <= now) {
        var note = document.createElement('p');
        note.className = 'hint';
        note.textContent = 'The hold time is over, so the booking can no longer be cancelled.';
        form.parentNode.replaceChild(note, form);
        continue;
      }
      if (free <= now && !form.hasAttribute('data-late')) {
        form.setAttribute('data-late', '');
        form.setAttribute('data-confirm', form.getAttribute('data-confirm-late'));
        form.querySelector('[data-expected-refund]').value = form.getAttribute('data-late-refund');
        form.querySelector('[data-cancel-label]').textContent = form.getAttribute('data-late-label');
      }
      var left = form.querySelector('[data-cancel-left]');
      if (left) {
        left.textContent = leftText(form.hasAttribute('data-late') ? hold : free);
      }
    }
  }

  /* ---------- start ---------- */

  document.addEventListener('sl-signed-in', afterSignIn);
  collectRefs();
  if (window.AreaMap) {
    areaMap = window.AreaMap.create(el.mapCanvas, {
      esc: esc, tone: areaTone, onSelect: selectArea, padding: mapPadding, notice: el.mapNotice, mapbox: cfg.mapbox
    });
  }
  bindEvents();
  layoutSheet();
  renderAll();
  // the islands come in one after the other over the map
  motion.stagger([el.search.closest('.search-pill'), el.sheet].concat(
    Array.prototype.slice.call(document.querySelectorAll('.map-right > *:not(:empty), #glassTabs, .map-legend'))), 18);
  motion.pop(document.querySelector('.flash--float'));
  // a popup (My locker, Top up) changed the wallet or a booking: read the map again now
  document.addEventListener('sl-data-changed', load);
  load();
  openAskedSignIn();
  geoStart();   // v4: asks for the position as soon as the page opens (the browser shows its own prompt once)
  setInterval(tick, 1000);
  setInterval(function () {
    if (!document.hidden && !state.popupOpen) {
      load();
    }
  }, REFRESH_MS);
})();
