/* "Tủ của tôi" and "Nạp tiền" as glass popups over the users' map (WEB-INF/views/lockerMap.jsp, <dialog id="glassPanel">).
   The content is the page itself drawn with ?panel=1 (myLocker.jsp, topup.jsp without the shell). A link to one of the
   two pages anywhere on the map opens the popup instead; a form inside it is posted with fetch and the content is
   drawn again with the flash of the controller. ?panel=mylocker|topup (&id=) on the map opens one at load, which is
   where MyLockerController and TopupController send a user who opens them directly.
   Needs js/app.js (SmartLocker), js/glass-motion.js (SmartLockerMotion); load it before js/locker-map.js. */
(function () {
  'use strict';

  var dlg = document.getElementById('glassPanel');
  var app = document.getElementById('lockerApp');
  if (!dlg || !app || !window.HTMLDialogElement) {
    return;   // no popup: the links keep going to the pages
  }
  var body = dlg.querySelector('[data-panel-body]');
  var ctx = app.getAttribute('data-ctx') || '';
  var PAGES = { mylocker: '/MyLockerController', topup: '/TopupController' };
  var motion = window.SmartLockerMotion;
  var current = null;   // the page shown, "/TopupController?id=7", without panel=1
  var loading = 0;
  var closing = 0;      // the leave animation that may still close the popup
  var ahead = {};       // page -> { at, html: Promise }: loaded when the pointer rests on its link, used for 15 s
  var AHEAD_MS = 15000;

  function panelUrl(page) {
    return ctx + page + (page.indexOf('?') === -1 ? '?' : '&') + 'panel=1';
  }

  function fetchPanel(page, prefetch) {
    var headers = { Accept: 'text/html' };
    if (prefetch) {
      headers['X-SL-Prefetch'] = '1';   // common/panel-flash.jspf keeps the flash for the real load
    }
    return fetch(panelUrl(page), { credentials: 'same-origin', headers: headers })
      .then(function (res) { return res.text(); });
  }

  // the HTML loaded ahead for this page when it is fresh; taken once
  function takeAhead(page) {
    var hit = ahead[page];
    delete ahead[page];
    return hit && Date.now() - hit.at < AHEAD_MS ? hit.html : null;
  }

  // "/MyLockerController?x" when the URL is one of the two pages of this app, else null
  function pageOf(href) {
    var url;
    try {
      url = new URL(href, window.location.href);
    } catch (e) {
      return null;
    }
    if (url.origin !== window.location.origin) {
      return null;
    }
    for (var key in PAGES) {
      if (url.pathname === ctx + PAGES[key]) {
        var params = new URLSearchParams(url.search);
        params.delete('panel');
        var query = params.toString();
        return PAGES[key] + (query ? '?' + query : '');
      }
    }
    return null;
  }

  // the tab of the open page is the pressed one while the popup is open
  function markTab(page) {
    var tabs = document.querySelectorAll('#glassTabs .tab[href]');
    for (var i = 0; i < tabs.length; i++) {
      var mine = page ? pageOf(tabs[i].href) === page.split('?')[0] : /LockerMapController$/.test(tabs[i].getAttribute('href'));
      tabs[i].classList.toggle('on', mine);
      if (mine) {
        tabs[i].setAttribute('aria-current', 'page');
      } else {
        tabs[i].removeAttribute('aria-current');
      }
    }
  }

  function draw(html) {
    // the session ended: the server answered with a whole page (the map and its sign-in popup)
    if (html.indexOf('class="glass-page"') === -1) {
      window.location.href = ctx + '/LockerMapController?login=1';
      return;
    }
    body.innerHTML = html;
    body.removeAttribute('aria-busy');
    if (window.SmartLocker) {
      window.SmartLocker.labelCells(body);
    }
    motion.stagger(body.querySelectorAll('.glass-page > *'), 10);
  }

  function show(page) {
    current = page;
    markTab(page);
    var ticket = ++loading;
    body.setAttribute('aria-busy', 'true');
    if (dlg.hasAttribute('data-closing')) {
      // asked again while it was going away: it stays open (the close of the leave animation is dropped)
      closing++;
      dlg.removeAttribute('data-closing');
      motion.pop(dlg);
    } else if (!dlg.open) {
      body.innerHTML = '<p class="glass-dlg__loading">Đang tải…</p>';
      dlg.show();          // not modal: the tab bar stays usable to switch page or go back to the map
      motion.pop(dlg);
    }
    return (takeAhead(page) || fetchPanel(page, false))
      .then(function (html) {
        if (ticket === loading && dlg.open) {   // a newer page was asked for meanwhile, or the popup was closed
          draw(html);
        }
      })
      .catch(function () {
        if (ticket === loading && dlg.open) {
          body.removeAttribute('aria-busy');
          body.innerHTML = '<p class="flash bad" role="alert">Không tải được nội dung. Kiểm tra kết nối rồi thử lại.</p>';
        }
      });
  }

  function close() {
    if (!dlg.open || dlg.hasAttribute('data-closing')) {
      return;
    }
    dlg.setAttribute('data-closing', '');
    var mine = ++closing;
    motion.leave(dlg).then(function () {
      if (mine !== closing) {
        return;   // opened again meanwhile
      }
      dlg.removeAttribute('data-closing');
      dlg.close();
      dlg.style.removeProperty('transform');
      dlg.style.removeProperty('opacity');
    });
  }

  dlg.addEventListener('close', function () {
    current = null;
    loading++;
    markTab(null);
  });
  // Esc (unless a confirm popup of js/app.js is open on top) and the close button close it with the animation
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape' && dlg.open && !e.defaultPrevented && !document.querySelector('dialog.dlg[open]')) {
      e.preventDefault();   // js/locker-map.js leaves the selected slot alone
      close();
    }
  });
  dlg.addEventListener('click', function (e) {
    if (e.target.closest && e.target.closest('[data-panel-close]')) {
      close();
    }
  });

  // a link to one of the two pages opens (or changes) the popup; a link to the map itself (the tab) closes it
  document.addEventListener('click', function (e) {
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) {
      return;
    }
    var link = e.target.closest ? e.target.closest('a[href]') : null;
    if (!link || link.target === '_blank') {
      return;
    }
    var page = pageOf(link.href);
    if (page) {
      e.preventDefault();
      show(page);
    } else if (/\/LockerMapController$/.test(link.getAttribute('href')) || (dlg.contains(link) && /\/LockerMapController\?/.test(link.getAttribute('href')))) {
      e.preventDefault();
      close();
    }
  });

  // forms of the popup: after the confirm of js/app.js (it listens first), post with fetch and draw the page again
  document.addEventListener('submit', function (e) {
    var form = e.target;
    // read the attributes: a field named "action" (every form here has one) hides form.action
    if (e.defaultPrevented || !body.contains(form) || (form.getAttribute('method') || '').toLowerCase() !== 'post') {
      return;
    }
    e.preventDefault();
    ahead = {};   // what was loaded ahead is old now
    var data = new URLSearchParams(new FormData(form));
    if (e.submitter && e.submitter.name) {
      data.append(e.submitter.name, e.submitter.value);
    }
    var buttons = form.querySelectorAll('button, [type="submit"]');
    for (var i = 0; i < buttons.length; i++) {
      buttons[i].disabled = true;
    }
    // redirect "manual": the controller's flash stays in the session for the panel drawn next
    fetch(new URL(form.getAttribute('action') || '', window.location.href).href, {
      method: 'POST', credentials: 'same-origin', redirect: 'manual', body: data,
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    }).catch(function () {
      // the panel drawn next tells what happened
    }).then(function () {
      ahead = {};   // a copy loaded ahead while the POST was on its way shows the page before it
      // a new top-up shows its own QR: the page without ?id= shows the newest request still waiting
      var page = current && current.indexOf(PAGES.topup) === 0 ? PAGES.topup : current;
      return show(page || PAGES.mylocker);
    }).then(function () {
      document.dispatchEvent(new CustomEvent('sl-data-changed'));   // the map reads the wallet and the slots again
    });
  });

  // the pointer rests on a link to one of the two pages: load it now, so the popup opens with its content
  // (not for a visitor: the server answers with the sign-in page)
  if (app.getAttribute('data-role') !== 'GUEST' && window.matchMedia && window.matchMedia('(hover: hover)').matches) {
    document.addEventListener('pointerover', function (e) {
      var link = e.target.closest ? e.target.closest('a[href]') : null;
      var page = link && pageOf(link.href);
      if (!page || page === current || (ahead[page] && Date.now() - ahead[page].at < AHEAD_MS)) {
        return;
      }
      var html = fetchPanel(page, true);
      ahead[page] = { at: Date.now(), html: html };
      html.catch(function () {
        delete ahead[page];
      });
    });
  }
  document.addEventListener('sl-data-changed', function () {
    ahead = {};
  });

  // ?panel= on the map: open it at load (the map script then cleans the address)
  var asked = new URLSearchParams(window.location.search);
  var kind = asked.get('panel');
  if (PAGES[kind] && app.getAttribute('data-role') !== 'GUEST') {
    var id = parseInt(asked.get('id'), 10);
    show(PAGES[kind] + (kind === 'topup' && id > 0 ? '?id=' + id : ''));
  }

  window.SmartLockerPanel = { open: function (kindOrPage) { show(PAGES[kindOrPage] || kindOrPage); }, close: close };
})();
