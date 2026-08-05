/* DARC Dungeon — Dark-mode toggle
 * Switches between the Just-the-Docs light and dark stylesheets and remembers
 * the choice in localStorage. No build step. No dependencies.
 *
 * Split of responsibilities:
 *   - the inline script in _includes/head_custom.html resolves the theme and
 *     applies it *before first paint* (so there is no flash of the wrong theme);
 *   - this script, deferred, wires up the button in _includes/header_custom.html
 *     and handles clicks afterwards.
 * Both must agree on STORAGE_KEY and on the stylesheet selector below.
 *
 * We deliberately do not call jtd.setTheme(): it targets the first
 * [rel="stylesheet"] in the document, and depends on just-the-docs.js having
 * run. Swapping the href directly is the same operation, minus both risks.
 */
(function () {
  'use strict';

  var STORAGE_KEY = 'dungeon.v1.theme';
  var THEME_LINK_SELECTOR =
    'link[rel="stylesheet"][href*="/just-the-docs-"]:not(#jtd-head-nav-stylesheet)';

  var LABELS = {
    light: { icon: '☾', text: 'Dark mode' },  // ☾ — offers the switch to dark
    dark:  { icon: '☀', text: 'Light mode' }, // ☀ — offers the switch back
  };

  // ── Storage ────────────────────────────────────────────────────────────────

  function savedTheme() {
    try {
      var v = localStorage.getItem(STORAGE_KEY);
      return (v === 'light' || v === 'dark') ? v : null;
    } catch (_) {
      return null;
    }
  }

  function saveTheme(theme) {
    try {
      localStorage.setItem(STORAGE_KEY, theme);
    } catch (_) { /* private mode / quota — the toggle still works this session */ }
  }

  // ── Applying a theme ───────────────────────────────────────────────────────

  function currentTheme() {
    return document.documentElement.getAttribute('data-theme') === 'dark' ? 'dark' : 'light';
  }

  function stylesheetHref(theme) {
    var link = document.querySelector(THEME_LINK_SELECTOR);
    if (!link) return null;
    // Rewrite in place so we inherit whatever baseurl Jekyll produced.
    return link.getAttribute('href').replace(
      /just-the-docs-[a-z]+\.css/, 'just-the-docs-' + theme + '.css'
    );
  }

  function applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);

    var link = document.querySelector(THEME_LINK_SELECTOR);
    var href = stylesheetHref(theme);
    if (link && href) link.setAttribute('href', href);

    document.dispatchEvent(new CustomEvent('theme:changed', { detail: { theme: theme } }));
  }

  function syncButton(btn, theme) {
    var label = LABELS[theme];
    btn.setAttribute('aria-checked', theme === 'dark' ? 'true' : 'false');
    btn.querySelector('.theme-toggle-icon').textContent = label.icon;
    btn.querySelector('.theme-toggle-label').textContent = label.text;
  }

  // ── Wiring ─────────────────────────────────────────────────────────────────

  function init() {
    var btn = document.getElementById('theme-toggle');
    if (!btn) return;

    // Rendered hidden so a no-JS reader is not shown a control that cannot work.
    btn.hidden = false;
    syncButton(btn, currentTheme());

    btn.addEventListener('click', function () {
      var next = currentTheme() === 'dark' ? 'light' : 'dark';
      applyTheme(next);
      saveTheme(next);
      syncButton(btn, next);
    });

    // Follow the OS only while the reader has not made an explicit choice.
    if (window.matchMedia) {
      var mq = window.matchMedia('(prefers-color-scheme: dark)');
      var onChange = function (e) {
        if (savedTheme()) return;
        var theme = e.matches ? 'dark' : 'light';
        applyTheme(theme);
        syncButton(btn, theme);
      };
      if (mq.addEventListener) mq.addEventListener('change', onChange);
      else if (mq.addListener) mq.addListener(onChange);  // Safari < 14
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
