/* Файл: идоракунии ҳаракатҳои ороишии сайт бе вобастагии беруна.
   Гузариши мавзӯъ, пайдоиши бахшҳо, scroll, parallax ва FAQ-ро бо дастгирии reduced motion идора мекунад. */
(function () {
  'use strict';

  var root = document.documentElement;
  var reduceQuery = window.matchMedia('(prefers-reduced-motion: reduce)');
  var colorQuery = window.matchMedia('(prefers-color-scheme: dark)');
  var reduced = reduceQuery.matches;
  var revealItems = [];

  /* Пайвандҳои берунаро бо `noopener` ва `noreferrer` аз саҳифа ҷудо мекунад. */
  function secureExternalLinks() {
    document.querySelectorAll('a[href]').forEach(function (link) {
      var target = new URL(link.href, location.href);
      if (target.origin !== location.origin) {
        link.relList.add('noopener');
        link.relList.add('noreferrer');
      }
    });
  }
  secureExternalLinks();

  /* Fragment-и ҷориро ҳангоми гузариш байни забонҳо нигоҳ медорад. */
  function syncLanguageHashes() {
    document.querySelectorAll('.lang-switch a').forEach(function (link) {
      var target = new URL(link.href, location.href);
      target.hash = location.hash;
      link.href = target.pathname + target.search + target.hash;
    });
  }
  syncLanguageHashes();
  addEventListener('hashchange', syncLanguageHashes);

  /* Унсурро намоён мекунад, аз ҷумла дар роҳи эҳтиётии observer. */
  function reveal(element) {
    element.classList.add('is-visible');
  }

  /* Интихоби мавзӯъро нигоҳ дошта, гузаришро аз ҷойи тугма оғоз мекунад. */
  var themeToggle = document.getElementById('theme-toggle');
  if (themeToggle) {
    themeToggle.checked = root.getAttribute('data-theme') === 'dark';
    themeToggle.addEventListener('change', function () {
      var theme = themeToggle.checked ? 'dark' : 'light';
      /* Мавзӯъро ба саҳифа татбиқ карда, интихобро дар localStorage менависад. */
      var applyTheme = function () {
        root.setAttribute('data-theme', theme);
        try { localStorage.setItem('nigoh-theme', theme); } catch (error) {}
      };

      if (reduced || !document.startViewTransition) {
        applyTheme();
        return;
      }

      var box = themeToggle.getBoundingClientRect();
      var x = box.left + box.width / 2;
      var y = box.top + box.height / 2;
      var radius = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y));
      root.style.setProperty('--theme-x', x + 'px');
      root.style.setProperty('--theme-y', y + 'px');
      root.style.setProperty('--theme-radius', radius + 'px');
      root.classList.add('motion-theme-transition');
      try {
        var transition = document.startViewTransition(applyTheme);
        transition.finished.finally(function () {
          root.classList.remove('motion-theme-transition');
        });
      } catch (error) {
        root.classList.remove('motion-theme-transition');
        applyTheme();
      }
    });
  }

  /* Месанҷад, ки корбар мавзӯъро пештар ошкоро интихоб кардааст ё не. */
  function hasStoredTheme() {
    try {
      var stored = localStorage.getItem('nigoh-theme');
      return stored === 'light' || stored === 'dark';
    } catch (error) {
      return false;
    }
  }

  /* То интихоби корбар тағйироти зиндаи мавзӯи системаро татбиқ мекунад. */
  function followSystemTheme(event) {
    if (hasStoredTheme()) return;
    var theme = event.matches ? 'dark' : 'light';
    root.setAttribute('data-theme', theme);
    if (themeToggle) themeToggle.checked = event.matches;
  }
  if (colorQuery.addEventListener) {
    colorQuery.addEventListener('change', followSystemTheme);
  } else {
    colorQuery.addListener(followSystemTheme);
  }

  /* Header, сатри пешрафти scroll ва тугмаи бозгашт ба болоро омода мекунад. */
  var header = document.querySelector('.site-header');
  var backToTop = document.querySelector('.back-to-top');
  var progress = document.createElement('span');
  progress.className = 'scroll-progress';
  progress.setAttribute('aria-hidden', 'true');
  if (header) header.appendChild(progress);
  var scrollQueued = false;
  /* Ҳолати header ва сатри пешрафтро аз мавқеи ҷории scroll нав мекунад. */
  function paintScroll() {
    var y = window.scrollY || document.documentElement.scrollTop;
    var max = Math.max(1, document.documentElement.scrollHeight - innerHeight);
    if (header) header.classList.toggle('is-scrolled', y > 8);
    if (backToTop) backToTop.classList.toggle('is-visible', y > innerHeight);
    progress.style.transform = 'scaleX(' + Math.min(1, y / max) + ')';
    scrollQueued = false;
  }
  /* Навсозии scroll-ро то кадри навбатии animation маҳдуд мекунад. */
  function queueScroll() {
    if (!scrollQueued) {
      scrollQueued = true;
      requestAnimationFrame(paintScroll);
    }
  }
  addEventListener('scroll', queueScroll, { passive: true });
  addEventListener('resize', queueScroll, { passive: true });
  queueScroll();

  /* Танҳо ҳангоми иҷозаи ҳаракат class-и motion-ро фаъол мекунад. */
  if (!reduced) root.classList.add('js-motion');

  /* Қисмҳои hero-ро барои пайдоиши пайдарпай бе тағйири муҳтаво омода мекунад. */
  var hero = document.querySelector('main .hero');
  var heroVisual = hero && hero.querySelector('.hero-visual');
  if (!reduced && hero) {
    var heroParts = hero.querySelectorAll('.wrap > :first-child > .eyebrow, .wrap > :first-child > h1, .wrap > :first-child > .lead, .wrap > :first-child > .btn-row, .wrap > :first-child > .hero-meta');
    heroParts.forEach(function (item, index) {
      item.classList.add('motion-hero-item');
      item.style.setProperty('--motion-delay', (index * 75) + 'ms');
      revealItems.push(item);
    });
    if (heroVisual) {
      heroVisual.classList.add('motion-hero-visual');
      revealItems.push(heroVisual);
    }
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        heroParts.forEach(reveal);
        if (heroVisual) reveal(heroVisual);
      });
    });
  }

  /* Барои pointer-и дақиқ parallax-и телефонро бо transform идора мекунад.
     Агар телефони интерактивӣ бошад, parallax хомӯш аст, то пахш осон бошад. */
  var heroInteractive = heroVisual && heroVisual.querySelector('[data-demo]');
  if (!reduced && heroVisual && !heroInteractive && matchMedia('(hover: hover) and (pointer: fine)').matches) {
    var visualBox;
    var pointerQueued = false;
    var tiltX = 0;
    var tiltY = 0;
    /* Кунҷи ҳисобшудаи pointer-ро ба намуди hero татбиқ мекунад. */
    function paintPointer() {
      heroVisual.style.setProperty('--tilt-x', tiltX.toFixed(2) + 'deg');
      heroVisual.style.setProperty('--tilt-y', tiltY.toFixed(2) + 'deg');
      pointerQueued = false;
    }
    heroVisual.addEventListener('pointerenter', function () {
      visualBox = heroVisual.getBoundingClientRect();
      heroVisual.classList.add('is-parallax-ready');
    }, { passive: true });
    heroVisual.addEventListener('pointermove', function (event) {
      if (!visualBox) return;
      tiltY = ((event.clientX - visualBox.left) / visualBox.width - .5) * 7;
      tiltX = (.5 - (event.clientY - visualBox.top) / visualBox.height) * 6;
      if (!pointerQueued) {
        pointerQueued = true;
        requestAnimationFrame(paintPointer);
      }
    }, { passive: true });
    heroVisual.addEventListener('pointerleave', function () {
      tiltX = 0;
      tiltY = 0;
      if (!pointerQueued) {
        pointerQueued = true;
        requestAnimationFrame(paintPointer);
      }
    }, { passive: true });
  }

  /* Унсурҳои бахшҳоро ёфта, ҳангоми scroll ҳар кадомро як бор нишон медиҳад. */
  if (!reduced) {
    var selector = [
      '.page-hero .wrap > *', '.section-head > *',
      '.grid-2 > *', '.grid-3 > *', '.grid-4 > *',
      '.split > *', '.steps > .step', '.feature-list > li',
      '.faq > details', '.qr-card > *', '.cta > *',
      '.wrap > .callout', '.wrap > .stats', '.wrap > table'
    ].join(',');
    var seen = new Set();
    document.querySelectorAll('main section:not(.hero)').forEach(function (section) {
      var delay = 0;
      section.querySelectorAll(selector).forEach(function (item) {
        if (seen.has(item) || item.closest('.motion-reveal')) return;
        seen.add(item);
        item.classList.add('motion-reveal');
        item.style.setProperty('--motion-delay', Math.min(delay, 280) + 'ms');
        delay += 55;
        revealItems.push(item);
      });
    });
    var footer = document.querySelector('.site-footer');
    if (footer) {
      footer.classList.add('motion-reveal');
      revealItems.push(footer);
      seen.add(footer);
    }

    if ('IntersectionObserver' in window) {
      var observer = new IntersectionObserver(function (entries) {
        entries.forEach(function (entry) {
          if (!entry.isIntersecting) return;
          reveal(entry.target);
          observer.unobserve(entry.target);
        });
      }, { rootMargin: '0px 0px -7% 0px', threshold: .04 });
      seen.forEach(function (item) { observer.observe(item); });
    } else {
      seen.forEach(reveal);
    }
  }

  /* Кушодану бастани FAQ-ро бо тағйири нарми баландӣ иҷро мекунад.
     Ҳангоми reduced motion гузариш фавран ва бо рафтори аслии браузер анҷом меёбад. */
  if (Element.prototype.animate) {
    document.querySelectorAll('.faq details').forEach(function (details) {
      var summary = details.querySelector('summary');
      var answer = summary && summary.nextElementSibling;
      if (!summary || !answer) return;
      var running = null;
      summary.addEventListener('click', function (event) {
        if (reduceQuery.matches) return; // Гузариши аслиро бе animation истифода мебарад.
        event.preventDefault();
        if (running) running.cancel();
        var opening = !details.open;
        if (opening) details.open = true;
        var full = answer.scrollHeight;
        var from = opening ? 0 : answer.getBoundingClientRect().height;
        var to = opening ? full : 0;
        answer.style.overflow = 'hidden';
        running = answer.animate([
          { height: from + 'px', opacity: opening ? 0 : 1 },
          { height: to + 'px', opacity: opening ? 1 : 0 }
        ], { duration: opening ? 240 : 190, easing: 'cubic-bezier(.2,.8,.2,1)' });
        running.onfinish = function () {
          if (!opening) details.open = false;
          answer.style.overflow = '';
          running = null;
        };
        running.oncancel = function () { answer.style.overflow = ''; };
      });
    });
  }

  /* Агар боршавӣ ё observer дер кунад, ҳама муҳтавои пинҳонро маҷбуран нишон медиҳад. */
  setTimeout(function () { revealItems.forEach(reveal); }, 1500);
}());
