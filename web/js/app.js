// Shared browser code. No library is fetched from the internet, so the pages
// still work on a machine with no network.

(function () {
    'use strict';

    // Copies each column title into its cells, the phone layout prints it before the value.
    function labelCells(root) {
        var tables = (root || document).querySelectorAll('table.grid');
        for (var t = 0; t < tables.length; t++) {
            var head = tables[t].querySelector('tr');
            if (!head) continue;
            var names = [];
            var ths = head.children;
            for (var i = 0; i < ths.length; i++) names.push(ths[i].textContent.trim());
            var rows = tables[t].querySelectorAll('tr');
            for (var r = 1; r < rows.length; r++) {
                var cells = rows[r].children;
                for (var c = 0; c < cells.length; c++) {
                    if (!cells[c].hasAttribute('colspan') && names[c]) {
                        cells[c].setAttribute('data-th', names[c]);
                    }
                }
            }
        }
    }

    var region = null;

    function toast(message, type) {
        if (!region) {
            region = document.createElement('div');
            region.className = 'toast-region';
            region.setAttribute('aria-live', 'polite');
            document.body.appendChild(region);
        }
        var item = document.createElement('div');
        item.className = 'toast' + (type ? ' toast--' + type : '');
        item.setAttribute('role', type === 'error' ? 'alert' : 'status');
        item.textContent = message;
        region.appendChild(item);
        setTimeout(function () {
            if (item.parentNode) item.parentNode.removeChild(item);
        }, type === 'error' ? 7000 : 4500);
    }

    function esc(value) {
        return String(value === null || value === undefined ? '' : value)
            .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }

    // Accessible confirm popup on the native <dialog>: focus stays inside, Esc cancels, focus returns after.
    // opts: title (text), html (already escaped with esc()) or text, okText, cancelText, danger. Resolves true on OK.
    var dlg = null;
    function confirmDialog(opts) {
        opts = opts || {};
        if (!window.HTMLDialogElement || !document.createElement('dialog').showModal) {
            return Promise.resolve(window.confirm(opts.text || opts.title || ''));
        }
        if (!dlg) {
            dlg = document.createElement('dialog');
            dlg.className = 'dlg';
            dlg.setAttribute('aria-labelledby', 'dlgTitle');
            dlg.setAttribute('aria-describedby', 'dlgBody');
            dlg.innerHTML = '<form method="dialog" class="dlg__form">' +
                '<h2 class="dlg__title" id="dlgTitle"></h2><div class="dlg__body" id="dlgBody"></div>' +
                '<div class="dlg__actions"><button type="submit" value="cancel" class="ghost" data-dlg-cancel></button>' +
                '<button type="submit" value="ok" data-dlg-ok></button></div></form>';
            document.body.appendChild(dlg);
        }
        var back = document.activeElement;
        dlg.querySelector('#dlgTitle').textContent = opts.title || 'Xác nhận';
        dlg.querySelector('#dlgBody').innerHTML = opts.html || ('<p>' + esc(opts.text || '') + '</p>');
        var ok = dlg.querySelector('[data-dlg-ok]');
        ok.textContent = opts.okText || 'Đồng ý';
        ok.className = opts.danger ? 'btn--danger' : '';
        dlg.querySelector('[data-dlg-cancel]').textContent = opts.cancelText || 'Quay lại';
        dlg.returnValue = '';
        return new Promise(function (resolve) {
            dlg.addEventListener('close', function onClose() {
                dlg.removeEventListener('close', onClose);
                if (back && back.focus) back.focus();
                resolve(dlg.returnValue === 'ok');
            });
            dlg.showModal();
            (opts.danger ? dlg.querySelector('[data-dlg-cancel]') : ok).focus();
        });
    }

    // A form with data-confirm="text" asks first (data-confirm-ok, data-confirm-danger optional).
    // The attributes may also sit on one submit button, so only that button asks.
    // A page script that handles the submit itself calls preventDefault and this listener stays out of it.
    document.addEventListener('submit', function (e) {
        var form = e.target;
        if (e.defaultPrevented || !form.hasAttribute) return;
        var submitter = e.submitter || null;
        var src = submitter && submitter.hasAttribute('data-confirm') ? submitter
                : (form.hasAttribute('data-confirm') ? form : null);
        if (!src) return;
        if (form.getAttribute('data-confirmed') === '1') { form.removeAttribute('data-confirmed'); return; }
        e.preventDefault();
        confirmDialog({
            title: src.getAttribute('data-confirm-title') || 'Xác nhận',
            text: src.getAttribute('data-confirm'),
            okText: src.getAttribute('data-confirm-ok') || 'Đồng ý',
            danger: src.hasAttribute('data-confirm-danger')
        }).then(function (yes) {
            if (!yes) return;
            form.setAttribute('data-confirmed', '1');
            if (form.requestSubmit) form.requestSubmit(submitter); else form.submit();
        });
    });

    // Show / hide password: <button data-pw-toggle="id1 id2" aria-pressed="false"> switches those inputs.
    document.addEventListener('click', function (e) {
        var btn = e.target.closest ? e.target.closest('[data-pw-toggle]') : null;
        if (!btn) return;
        var show = btn.getAttribute('aria-pressed') !== 'true';
        btn.getAttribute('data-pw-toggle').split(/\s+/).forEach(function (id) {
            var input = document.getElementById(id);
            if (input) input.type = show ? 'text' : 'password';
        });
        btn.setAttribute('aria-pressed', show ? 'true' : 'false');
        var label = show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu';
        btn.setAttribute('aria-label', label);
        btn.setAttribute('title', label);
    });

    window.SmartLocker = { toast: toast, labelCells: labelCells, confirm: confirmDialog, esc: esc };
    document.addEventListener('DOMContentLoaded', function () { labelCells(); });
})();
