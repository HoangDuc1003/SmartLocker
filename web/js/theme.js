// Light / dark theme. Loaded in <head> so the page is painted in the right theme at once.
// No stored choice: css/app.css follows the OS preference.
(function () {
    'use strict';
    var KEY = 'sl-theme';
    var root = document.documentElement;

    function stored() {
        try { return localStorage.getItem(KEY); } catch (e) { return null; }
    }
    function current() {
        var t = root.getAttribute('data-theme');
        if (t) return t;
        return window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }

    var saved = stored();
    if (saved === 'light' || saved === 'dark') root.setAttribute('data-theme', saved);

    window.SmartLockerTheme = {
        current: current,
        toggle: function () {
            var next = current() === 'dark' ? 'light' : 'dark';
            root.setAttribute('data-theme', next);
            try { localStorage.setItem(KEY, next); } catch (e) { /* private mode: still switches for this page */ }
            var btns = document.querySelectorAll('.theme-toggle');
            for (var i = 0; i < btns.length; i++) {
                btns[i].setAttribute('aria-label', next === 'dark' ? 'Chuyển sang nền sáng' : 'Chuyển sang nền tối');
            }
            document.dispatchEvent(new CustomEvent('sl-theme-change', { detail: next }));
        }
    };

    document.addEventListener('click', function (e) {
        var btn = e.target.closest ? e.target.closest('.theme-toggle') : null;
        if (btn) window.SmartLockerTheme.toggle();
    });
})();
