/* Motion for the glass pages of the users (the map, its popups). The library is vendored in js/vendor/motion
   (motion.dev, MIT, global window.Motion), so it works offline. Every animation is a spring and ends by handing the
   element back to its CSS: the inline transform and opacity it wrote are removed when it finishes.
   Without Motion, or with "reduce motion" in the OS, everything shows at once and nothing moves.
   Usage: SmartLockerMotion.pop(el), .leave(el).then(...), .slideIn(el, 1 | -1), .stagger(nodes), .height(el, px). */
(function () {
  'use strict';

  var M = window.Motion;
  var reduced = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)');

  // a quick, lightly damped spring for small things; a softer one for big islands and heights
  var SNAPPY = { type: 'spring', stiffness: 420, damping: 30, mass: 0.8 };
  var SOFT = { type: 'spring', stiffness: 260, damping: 30, mass: 1 };
  var OUT = { duration: 0.16, ease: [0.4, 0, 1, 1] };

  function enabled() {
    return !!(M && M.animate) && !(reduced && reduced.matches);
  }

  function clear(nodes, props) {
    for (var i = 0; i < nodes.length; i++) {
      for (var k = 0; k < props.length; k++) {
        nodes[i].style.removeProperty(props[k]);
      }
    }
  }

  // runs one animation; the promise settles when it ends (at once when motion is off)
  function run(target, keyframes, options, keep) {
    var nodes = !target ? [] : (target.length !== undefined ? Array.prototype.slice.call(target) : [target]);
    if (!nodes.length || !enabled()) {
      return Promise.resolve();
    }
    try {
      var animation = M.animate(nodes, keyframes, options);
      return Promise.resolve(animation.finished || animation).then(function () {
        if (!keep) {
          // a frame later: Motion writes the last keyframe inline after its promise settles
          return new Promise(function (resolve) {
            window.requestAnimationFrame(function () {
              clear(nodes, ['transform', 'opacity']);
              resolve();
            });
          });
        }
      }, function () {});
    } catch (e) {
      return Promise.resolve();   // an unknown property in an old browser: the page still works
    }
  }

  var api = {
    enabled: enabled,

    // an island, a card or a popup appears
    pop: function (el) {
      return run(el, { opacity: [0, 1], scale: [0.95, 1], y: [14, 0] }, SNAPPY);
    },

    // and goes away (the caller hides or closes it when the promise settles)
    leave: function (el) {
      return run(el, { opacity: [1, 0], scale: [1, 0.97], y: [0, 10] }, OUT, true);
    },

    // a new view slides in from the side it comes from (1 forward, -1 back)
    slideIn: function (el, dir) {
      return run(el, { opacity: [0, 1], x: [(dir || 1) * 22, 0] }, SOFT);
    },

    // rows, cards, islands one after the other
    stagger: function (nodes, from) {
      if (!nodes || !nodes.length || !enabled()) {
        return Promise.resolve();
      }
      return run(nodes, { opacity: [0, 1], y: [from || 12, 0] },
        { type: 'spring', stiffness: 320, damping: 28, delay: M.stagger(0.04) });
    },

    // a height that changes (the phone sheet); a new one stops the one still running; without motion it is set at once
    height: function (el, px) {
      api.stopHeight(el);
      if (!enabled()) {
        el.style.height = px + 'px';
        return Promise.resolve();
      }
      try {
        el._slHeight = M.animate(el, { height: px + 'px' }, SOFT);
        return Promise.resolve(el._slHeight.finished).catch(function () {});
      } catch (e) {
        el.style.height = px + 'px';
        return Promise.resolve();
      }
    },

    // the finger takes the sheet: the spring lets go
    stopHeight: function (el) {
      if (el._slHeight) {
        try {
          el._slHeight.stop();
        } catch (e) {
          // already over
        }
        el._slHeight = null;
      }
    },

    // a small bounce of something that changed (the ring of the chosen pin)
    bump: function (el) {
      return run(el, { scale: [0.72, 1] }, { type: 'spring', stiffness: 520, damping: 18 });
    }
  };

  /* Hover and press of the glass buttons (.lg-hover): a spring lift on hover and a squeeze on press, read by
     delegation so the rows and the cards drawn again every 10 seconds get it too. Buttons inside a stack or a
     list (.ctl, .area-row, .pop__link) only get the light of css/locker-map.css, not the lift; nor does a button that
     is a glass island itself (the wallet pill): moving it would blur the map behind it again on every frame. */
  var FLAT = '.ctl, .area-row, .pop__link, .glass';
  var hoverOk = window.matchMedia && window.matchMedia('(hover: hover) and (pointer: fine)').matches;

  function liftable(e) {
    var el = e.target && e.target.closest ? e.target.closest('.lg-hover') : null;
    return el && !el.matches(FLAT) && !el.disabled ? el : null;
  }

  function to(el, values, options) {
    if (!enabled()) {
      return;
    }
    try {
      M.animate(el, values, options);
    } catch (e) {
      // no motion for this one
    }
  }

  if (hoverOk) {
    document.addEventListener('pointerover', function (e) {
      var el = liftable(e);
      if (el && !el.contains(e.relatedTarget)) {
        to(el, { scale: 1.035, y: -1 }, SNAPPY);
      }
    });
    document.addEventListener('pointerout', function (e) {
      var el = liftable(e);
      if (el && !el.contains(e.relatedTarget)) {
        run(el, { scale: 1, y: 0 }, SNAPPY);
      }
    });
  }
  document.addEventListener('pointerdown', function (e) {
    var el = liftable(e);
    if (el) {
      to(el, { scale: 0.96 }, { type: 'spring', stiffness: 600, damping: 30 });
    }
  });
  document.addEventListener('pointerup', function (e) {
    var el = liftable(e);
    if (el) {
      to(el, { scale: hoverOk ? 1.035 : 1 }, SNAPPY);
    }
  });

  window.SmartLockerMotion = api;
})();
