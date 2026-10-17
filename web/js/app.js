// Shared browser code. No library is fetched from the internet, so the pages
// still work on a machine with no network.

// Draws a bar chart straight onto a canvas.
function drawBars(canvasId, labels, values) {
    var cv = document.getElementById(canvasId);
    if (!cv || !values || values.length === 0) return;
    var ctx = cv.getContext('2d');
    var w = cv.width, h = cv.height;
    var padL = 42, padB = 34, padT = 18, padR = 14;

    var max = 0;
    for (var i = 0; i < values.length; i++) if (values[i] > max) max = values[i];
    if (max === 0) max = 1;

    ctx.clearRect(0, 0, w, h);

    // axes
    ctx.strokeStyle = '#aab';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(padL, padT);
    ctx.lineTo(padL, h - padB);
    ctx.lineTo(w - padR, h - padB);
    ctx.stroke();

    // horizontal guides and their labels
    ctx.fillStyle = '#667';
    ctx.font = '11px sans-serif';
    ctx.textAlign = 'right';
    for (var g = 0; g <= 4; g++) {
        var val = Math.round(max * g / 4);
        var y = (h - padB) - (h - padB - padT) * g / 4;
        ctx.fillText(String(val), padL - 6, y + 4);
        if (g > 0) {
            ctx.strokeStyle = '#eef0f3';
            ctx.beginPath();
            ctx.moveTo(padL + 1, y);
            ctx.lineTo(w - padR, y);
            ctx.stroke();
        }
    }

    var slot = (w - padL - padR) / values.length;
    var barW = Math.min(64, slot * 0.6);

    for (var j = 0; j < values.length; j++) {
        var cx = padL + slot * j + slot / 2;
        var bh = (h - padB - padT) * values[j] / max;
        ctx.fillStyle = '#4a6fa5';
        ctx.fillRect(cx - barW / 2, (h - padB) - bh, barW, bh);

        ctx.fillStyle = '#222';
        ctx.font = 'bold 12px sans-serif';
        ctx.textAlign = 'center';
        ctx.fillText(String(values[j]), cx, (h - padB) - bh - 6);

        ctx.fillStyle = '#556';
        ctx.font = '11px sans-serif';
        ctx.fillText(labels[j], cx, h - padB + 15);
    }
}

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

    window.SmartLocker = { toast: toast, labelCells: labelCells, confirm: confirmDialog, esc: esc };
    document.addEventListener('DOMContentLoaded', function () { labelCells(); });
})();
