/* Login / sign-up popup for visitors who are not signed in (the map page is open to everybody).
   Any element with data-auth-open="login|register" opens it (its href still works without JavaScript).
   SmartLockerAuth.open({ tab, reason }) returns a Promise that resolves true after a successful sign-in,
   false when the popup is closed. The session cookie is set by the same POST the login page uses,
   asked for as JSON (Accept: application/json). Needs js/app.js first (window.SmartLocker.esc). */
(function () {
  'use strict';

  var ctx =(document.querySelector('link[href*="/css/app.css"]') || { getAttribute: function () { return ''; } })
    .getAttribute('href').replace(/\/css\/app\.css.*$/, '');
  var LOGIN_URL = ctx + '/LoginController';
  var REGISTER_URL = ctx + '/RegisterController';
  var esc = window.SmartLocker.esc;

  var dlg = null;
  var pending = null;   // { resolve, back }

  function field(id, label, type, extra) {
    return '<label for="' + id + '">' + label + '</label>' +
      '<input id="' + id + '" name="' + extra.name + '" type="' + type + '"' + (extra.attrs || '') + '>' +
      (extra.hint ? '<p class="hint">' + extra.hint + '</p>' : '');
  }

  function build() {
    dlg = document.createElement('dialog');
    dlg.className = 'dlg auth glass glass--sheet glass--dense';   // liquid glass: css/locker-map.css
    dlg.setAttribute('aria-labelledby', 'authTitle');
    dlg.innerHTML =
      '<div class="auth__head"><h2 id="authTitle" class="dlg__title">Sign in to continue</h2>' +
        '<button type="button" class="round-btn lg-hover" data-auth-close aria-label="Close">' +
          '<svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M6 6l12 12M18 6L6 18"/></svg></button></div>' +
      '<p class="auth__why" id="authWhy"></p>' +
      '<div class="seg auth__tabs" role="tablist" aria-label="Sign in or sign up">' +
        '<button type="button" role="tab" data-auth-tab="login" aria-selected="true">Sign in</button>' +
        '<button type="button" role="tab" data-auth-tab="register" aria-selected="false">Sign up</button></div>' +
      '<form class="auth__form" data-auth-form="login" action="' + esc(LOGIN_URL) + '" method="post" novalidate>' +
        field('authUser', 'Username', 'text', { name: 'username', attrs: ' autocomplete="username" autocapitalize="none" spellcheck="false" required' }) +
        field('authPass', 'Password', 'password', { name: 'password', attrs: ' autocomplete="current-password" required' }) +
        '<p class="auth__error error" role="alert" hidden></p>' +
        '<button type="submit" class="btn btn--block btn--pill lg-hover">Sign in</button></form>' +
      '<form class="auth__form" data-auth-form="register" action="' + esc(REGISTER_URL) + '" method="post" novalidate hidden>' +
        field('regUser', 'Username', 'text', { name: 'username', attrs: ' autocomplete="username" autocapitalize="none" spellcheck="false" required minlength="3" maxlength="50"',
          hint: '3 to 50 characters: letters without accents, digits, _ and dots.' }) +
        field('regName', 'Full name', 'text', { name: 'fullName', attrs: ' autocomplete="name" required minlength="2" maxlength="80"' }) +
        field('regEmail', 'E-mail <span class="muted">(optional)</span>', 'email', { name: 'email', attrs: ' autocomplete="email" maxlength="150"',
          hint: 'Get a reminder e-mail 15 minutes before your booking ends.' }) +
        field('regPass', 'Password', 'password', { name: 'password', attrs: ' autocomplete="new-password" required minlength="6"', hint: 'At least 6 characters.' }) +
        field('regConfirm', 'Confirm password', 'password', { name: 'confirm', attrs: ' autocomplete="new-password" required minlength="6"' }) +
        '<p class="auth__error error" role="alert" hidden></p>' +
        '<button type="submit" class="btn btn--block btn--pill lg-hover">Create account and sign in</button></form>';
    document.body.appendChild(dlg);

    dlg.addEventListener('click', function (e) {
      var tab = e.target.closest('[data-auth-tab]');
      if (tab) {
        showTab(tab.getAttribute('data-auth-tab'));
      } else if (e.target.closest('[data-auth-close]') || e.target === dlg) {
        dlg.close();   // a click on the backdrop lands on the dialog itself
      }
    });
    dlg.addEventListener('close', function () {
      var p = pending;
      pending = null;
      if (p) {
        if (p.back && p.back.focus && document.contains(p.back)) { p.back.focus(); }
        p.resolve(false);
      }
    });
    dlg.addEventListener('submit', onSubmit);
  }

  function showTab(name) {
    var tabs = dlg.querySelectorAll('[data-auth-tab]');
    for (var i = 0; i < tabs.length; i++) {
      tabs[i].setAttribute('aria-selected', tabs[i].getAttribute('data-auth-tab') === name ? 'true' : 'false');
    }
    var forms = dlg.querySelectorAll('[data-auth-form]');
    for (var j = 0; j < forms.length; j++) {
      forms[j].hidden = forms[j].getAttribute('data-auth-form') !== name;
      setError(forms[j], '');
    }
    dlg.querySelector('#authTitle').textContent = name === 'login' ? 'Sign in to continue' : 'Create a new account';
    var first = dlg.querySelector('[data-auth-form="' + name + '"] input');
    if (first && dlg.open) { first.focus(); }
  }

  function setError(form, text) {
    var box = form.querySelector('.auth__error');
    box.textContent = text;
    box.hidden = !text;
  }

  function send(url, form) {
    var body = new URLSearchParams(new FormData(form));
    return fetch(url, {
      method: 'POST', credentials: 'same-origin',
      headers: { Accept: 'application/json', 'Content-Type': 'application/x-www-form-urlencoded' },
      body: body.toString()
    }).then(function (res) {
      if ((res.headers.get('Content-Type') || '').indexOf('json') === -1) {
        // the server answered with an HTML error page, not a network failure
        return { ok: false, error: 'The server ran into an error (code ' + res.status + '). Please try again later.' };
      }
      return res.json().then(function (json) { return { ok: res.ok && json.ok, error: json.error }; });
    });
  }

  function onSubmit(e) {
    var form = e.target;
    var kind = form.getAttribute('data-auth-form');
    if (!kind) { return; }
    e.preventDefault();
    setError(form, '');
    if (!form.checkValidity()) {
      form.reportValidity();
      return;
    }
    var button = form.querySelector('[type="submit"]');
    var label = button.textContent;
    button.disabled = true;
    button.textContent = 'Sending…';
    var work = kind === 'register'
      ? send(REGISTER_URL, form).then(function (r) {
          if (!r.ok) { return r; }
          return send(LOGIN_URL, form);   // the new user is signed in at once, with the same name and password
        })
      : send(LOGIN_URL, form);
    work.then(function (r) {
      if (!r.ok) {
        setError(form, r.error || 'Could not send, please try again.');
        return;
      }
      var p = pending;
      pending = null;
      dlg.close();
      if (p) { p.resolve(true); }
    }).catch(function () {
      setError(form, 'Could not reach the server, please try again.');
    }).then(function () {
      button.disabled = false;
      button.textContent = label;
    });
  }

  function open(opts) {
    opts = opts || {};
    if (!window.HTMLDialogElement || !document.createElement('dialog').showModal) {
      window.location.href = opts.tab === 'register' ? REGISTER_URL : LOGIN_URL;
      return Promise.resolve(false);
    }
    if (!dlg) { build(); }
    var why = dlg.querySelector('#authWhy');
    why.textContent = opts.reason || '';
    why.hidden = !opts.reason;
    return new Promise(function (resolve) {
      if (pending) { pending.resolve(false); }
      pending = { resolve: resolve, back: document.activeElement };
      showTab(opts.tab === 'register' ? 'register' : 'login');
      if (!dlg.open) {
        dlg.showModal();
        if (window.SmartLockerMotion) { window.SmartLockerMotion.pop(dlg); }   // the spring of js/glass-motion.js
      }
      var first = dlg.querySelector('[data-auth-form]:not([hidden]) input');
      if (first) { first.focus(); }
    });
  }

  // the sidebar buttons: they open the popup, and without it they are plain links
  document.addEventListener('click', function (e) {
    var trigger = e.target.closest ? e.target.closest('[data-auth-open]') : null;
    if (!trigger) { return; }
    e.preventDefault();
    open({ tab: trigger.getAttribute('data-auth-open'), reason: trigger.getAttribute('data-auth-reason') || '' }).then(function (ok) {
      if (ok) { document.dispatchEvent(new CustomEvent('sl-signed-in')); }
    });
  });

  window.SmartLockerAuth = { open: open };
})();
