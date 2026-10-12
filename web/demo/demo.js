/* Demo helpers shared by every demo page: sign in, permission checks, top bar,
   storage of the sample data. The real application does these jobs with
   LoginController, SecurityFilter, nav.jsp and the database. */
(function () {
  'use strict';

  var D = window.DEMO_DATA;
  var memory = {};

  function clone(v) { return JSON.parse(JSON.stringify(v)); }

  // data lives in the browser only; sessionStorage for "who is signed in", localStorage for edits
  function read(key, fallback, session) {
    try {
      var raw = (session ? window.sessionStorage : window.localStorage).getItem(key);
      if (raw !== null) return JSON.parse(raw);
    } catch (e) {
      if (memory[key] !== undefined) return clone(memory[key]);
    }
    return clone(fallback);
  }

  function write(key, value, session) {
    memory[key] = clone(value);
    try { (session ? window.sessionStorage : window.localStorage).setItem(key, JSON.stringify(value)); } catch (e) { /* blocked */ }
  }

  function drop(key, session) {
    delete memory[key];
    try { (session ? window.sessionStorage : window.localStorage).removeItem(key); } catch (e) { /* blocked */ }
  }

  function storageWorks() {
    try {
      window.sessionStorage.setItem('sl_probe', '1');
      window.sessionStorage.removeItem('sl_probe');
      return true;
    } catch (e) {
      return false;
    }
  }

  function esc(v) {
    return String(v === null || v === undefined ? '' : v)
      .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  function pad(n) { return (n < 10 ? '0' : '') + n; }

  function fmt(value) {
    var d = value instanceof Date ? value : new Date(value);
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' +
           pad(d.getHours()) + ':' + pad(d.getMinutes()) + ':' + pad(d.getSeconds());
  }

  function qs(name) {
    var v = new URLSearchParams(window.location.search).get(name);
    return v === null ? '' : v;
  }

  /* ---------- data ---------- */

  function users() { return read('sl_users', D.users); }
  function saveUsers(list) { write('sl_users', list); }
  function perms() { return read('sl_perms', D.rolePerms); }
  function savePerms(map) { write('sl_perms', map); }
  function areas() { return read('sl_areas', D.areas); }
  function saveAreas(list) { write('sl_areas', list); }

  function roleOf(code) {
    for (var i = 0; i < D.roles.length; i++) if (D.roles[i].code === code) return D.roles[i];
    return null;
  }

  function rank(code) { var r = roleOf(code); return r ? r.rank : 99; }

  function me() {
    var name = read('sl_me', null, true);
    if (!name) return null;
    var list = users();
    for (var i = 0; i < list.length; i++) {
      if (list[i].username === name && !list[i].locked) return list[i];
    }
    return null;
  }

  function can(code) {
    var u = me();
    return !!u && (perms()[u.role] || []).indexOf(code) !== -1;
  }

  // everybody manages roles below theirs, the administrator manages all
  function canManage(target) {
    var u = me();
    if (!u) return false;
    return u.role === 'ADMIN' || rank(target.role) > rank(u.role);
  }

  /* ---------- logs ---------- */

  function audit(action, table, target, detail) {
    var extra = read('sl_audit', []);
    extra.unshift({ id: D.audits.length + extra.length + 1, at: new Date().toISOString(),
                    actor: me() ? me().username : 'system', action: action, table: table,
                    target: target, detail: detail || '' });
    write('sl_audit', extra.slice(0, 60));
  }

  function auditRows() {
    return read('sl_audit', []).map(function (r) { r.at = new Date(r.at); return r; }).concat(D.audits);
  }

  function addLogin(username, ok) {
    var extra = read('sl_logins', []);
    extra.unshift({ id: D.logins.length + extra.length + 1, at: new Date().toISOString(),
                    username: username, ok: ok, ip: '127.0.0.1' });
    write('sl_logins', extra.slice(0, 60));
  }

  function loginRows() {
    return read('sl_logins', []).map(function (r) { r.at = new Date(r.at); return r; }).concat(D.logins);
  }

  /* ---------- sign in ---------- */

  function login(username, password) {
    var found = null;
    users().forEach(function (u) { if (u.username === username) found = u; });
    if (!found || password !== '123456') {
      addLogin(username || '(empty)', false);
      return { error: 'Invalid username or password' };
    }
    if (found.locked) {
      addLogin(username, false);
      return { error: 'This account is locked, ask a Locker Operator to unlock it' };
    }
    write('sl_me', found.username, true);
    addLogin(username, true);
    return { user: found };
  }

  function logout() {
    drop('sl_me', true);
    window.location.href = 'index.html';
  }

  function home(user) {
    return perms()[user.role].indexOf('DASH_VIEW') !== -1 ? 'dashboard.html' : 'map.html';
  }

  function flash(message, bad) {
    write('sl_flash', { m: message, bad: !!bad }, true);
  }

  /* ---------- page shell, plays the part of nav.jsp and SecurityFilter ---------- */

  var MENU = [
    ['dashboard', 'dashboard.html', 'Dashboard',    'DASH_VIEW'],
    ['map',       'map.html',       'Locker map',   'MAP_VIEW'],
    ['users',     'users.html',     'Users',        'USER_VIEW'],
    ['roles',     'roles.html',     'Roles',        'ROLE_VIEW'],
    ['areas',     'areas.html',     'Locker areas', 'AREA_VIEW'],
    ['logs',      'logs.html',      'Logs',         'LOG_VIEW']
  ];

  function renderNav(user, active) {
    var bal = (user.balance !== undefined ? user.balance : 0).toLocaleString() + ' VND';
    var html = '<div class="topbar"><div class="brand">Smart Locker <span class="sem">FALL2026</span></div>' +
      '<div class="who"><span class="badge" title="Số dư tài khoản" style="background:#e8f5e9; color:#2e7d32; padding:3px 8px; border-radius:4px; font-weight:600; margin-right:8px; border:1px solid #c8e6c9;">💰 ' + bal + '</span>' +
      esc(user.fullName) + ' <span class="tag">' + esc(user.role) + '</span>' +
      '<a class="out" href="index.html" id="demoLogout">Logout</a></div></div><div class="menu">';
    MENU.forEach(function (m) {
      if (can(m[3])) {
        html += '<a href="' + m[1] + '"' + (m[0] === active ? ' class="on" aria-current="page"' : '') + '>' + m[2] + '</a>';
      }
    });
    html += '</div><div class="demo-note">Demo mode: sample data, kept in this browser only. ' +
            '<a href="#" id="demoReset">Reset demo data</a></div>';
    var note = read('sl_flash', null, true);
    if (note) {
      drop('sl_flash', true);
      html += '<div class="flash' + (note.bad ? ' bad' : '') + '">' + esc(note.m) + '</div>';
    }
    var holder = document.getElementById('nav');
    holder.innerHTML = html;
    document.getElementById('demoLogout').addEventListener('click', function (e) { e.preventDefault(); logout(); });
    document.getElementById('demoReset').addEventListener('click', function (e) {
      e.preventDefault();
      reset();
      window.location.reload();
    });
  }

  function denied(into) {
    var box = document.getElementById(into || 'content');
    box.className = 'wrap';
    box.innerHTML = '<div class="denied"><h2>Access denied</h2>' +
      '<p>Your role does not have permission to open this page. On the real server the ' +
      'SecurityFilter blocks the path itself, hiding the menu link is only a convenience.</p>' +
      '<a class="btn ghost" href="' + home(me()) + '">Back to my home page</a></div>';
  }

  // call first in every demo page, returns false when the page must not be drawn
  function page(opts) {
    var user = me();
    if (!user) { window.location.replace('index.html'); return false; }
    renderNav(user, opts.nav);
    if (opts.perm && !can(opts.perm)) { denied(opts.into); return false; }
    return true;
  }

  function reset() {
    ['sl_users', 'sl_perms', 'sl_areas', 'sl_audit', 'sl_logins'].forEach(function (k) { drop(k); });
  }

  /* ---------- small widgets ---------- */

  function pager(total, current, size, hrefOf) {
    var pages = Math.max(1, Math.ceil(total / size));
    var html = '<div class="pager">';
    for (var p = 1; p <= pages; p++) {
      html += p === current ? '<b>' + p + '</b>' : '<a href="' + esc(hrefOf(p)) + '">' + p + '</a>';
    }
    return html + '</div>';
  }

  function csv(filename, header, rows) {
    function cell(v) { return '"' + String(v === null || v === undefined ? '' : v).replace(/"/g, '""') + '"'; }
    var text = '﻿' + [header].concat(rows).map(function (r) { return r.map(cell).join(','); }).join('\r\n');
    var url = URL.createObjectURL(new Blob([text], { type: 'text/csv;charset=utf-8' }));
    var a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
  }

  window.DEMO = {
    data: D, esc: esc, fmt: fmt, qs: qs, pager: pager, csv: csv,
    users: users, saveUsers: saveUsers, perms: perms, savePerms: savePerms,
    areas: areas, saveAreas: saveAreas, roleOf: roleOf, rank: rank,
    me: me, can: can, canManage: canManage, login: login, logout: logout, home: home,
    flash: flash, page: page, reset: reset, audit: audit, auditRows: auditRows,
    loginRows: loginRows, storageWorks: storageWorks
  };
})();
