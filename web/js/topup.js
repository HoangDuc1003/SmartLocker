/* "Nạp tiền": the quick amounts fill the amount field and stay pressed while they match it.
   Listens on the document, so it also works when the page is drawn inside the glass popup of the map. */
(function () {
  'use strict';

  function sync(form) {
    var amount = form.querySelector('#amount');
    var presets = form.querySelectorAll('.presets [data-amt]');
    for (var i = 0; i < presets.length; i++) {
      presets[i].setAttribute('aria-pressed', Number(presets[i].getAttribute('data-amt')) === Number(amount.value) ? 'true' : 'false');
    }
  }

  document.addEventListener('click', function (e) {
    var btn = e.target.closest ? e.target.closest('.presets [data-amt]') : null;
    var form = btn && btn.closest('#topupForm');
    if (!form) {
      return;
    }
    form.querySelector('#amount').value = btn.getAttribute('data-amt');
    sync(form);
  });

  document.addEventListener('input', function (e) {
    if (e.target.id === 'amount' && e.target.closest('#topupForm')) {
      sync(e.target.closest('#topupForm'));
    }
  });
})();
