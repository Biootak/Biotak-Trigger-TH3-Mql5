(function initCopilotRTLFix(global) {
  'use strict';

  const STYLE_OWNER = 'copilot-rtl-fix';

  const DEFAULT_CONFIG = Object.freeze({
    styleId: 'copilot-rtl-fix',
    preset: 'balanced',
    autoApply: true,
    autoHeal: true,
    observeSubtree: true,
    supportsShadowDom: true,
    supportsIframes: true,
    enableBidiFallback: true,
    persistConfig: true,
    storageKey: 'copilot-rtl-fix:config:v1',
    log: true,
    logPrefix: 'CopilotRTL',
    observerDebounceMs: 80,
    maxMutationsPerWindow: 500,
    mutationBurstWindowMs: 500,
    maxHealsPerMinute: 24,
    watchHints: [
      'interactive-item-container',
      'monaco-list-row',
      'monaco-editor',
      'code-block-container',
      'rendered-markdown',
      'codicon'
    ],
    rules: {
      containers: {
        selectors: [
          '.interactive-item-container',
          '.monaco-list-row',
          'div[role="log"]'
        ],
        declarations: {
          direction: 'rtl',
          'text-align': 'right',
          'unicode-bidi': 'isolate'
        }
      },
      mixedText: {
        selectors: ['p', 'li', 'span', 'h1', 'h2', 'h3'],
        declarations: {
          'unicode-bidi': 'plaintext',
          'text-align': 'start'
        }
      },
      inlineCodeSafety: {
        selectors: ['span[class*="token"]', 'code:not(pre code)'],
        declarations: {
          direction: 'ltr',
          display: 'inline-block',
          'unicode-bidi': 'isolate'
        }
      },
      blockCodeSafety: {
        selectors: ['pre', '.monaco-editor', '.code-block-container', '.rendered-markdown code'],
        declarations: {
          direction: 'ltr',
          'text-align': 'left',
          'unicode-bidi': 'normal',
          display: 'block'
        }
      },
      iconSafety: {
        selectors: ['.codicon'],
        declarations: { direction: 'ltr' }
      }
    }
  });

  const PRESET_OVERRIDES = Object.freeze({
    balanced: {
      preset: 'balanced'
    },
    safe: {
      preset: 'safe',
      supportsIframes: false,
      maxMutationsPerWindow: 250,
      maxHealsPerMinute: 12,
      watchHints: [
        'interactive-item-container',
        'monaco-editor',
        'code-block-container',
        'rendered-markdown'
      ],
      rules: {
        containers: DEFAULT_CONFIG.rules.containers,
        inlineCodeSafety: DEFAULT_CONFIG.rules.inlineCodeSafety,
        blockCodeSafety: DEFAULT_CONFIG.rules.blockCodeSafety,
        iconSafety: DEFAULT_CONFIG.rules.iconSafety
      }
    },
    aggressive: {
      preset: 'aggressive',
      observerDebounceMs: 50,
      maxMutationsPerWindow: 900,
      maxHealsPerMinute: 40,
      watchHints: [
        ...DEFAULT_CONFIG.watchHints,
        'chat',
        'markdown',
        'message',
        'interactive'
      ]
    }
  });

  const PERSISTABLE_KEYS = Object.freeze([
    'preset',
    'autoHeal',
    'observeSubtree',
    'supportsShadowDom',
    'supportsIframes',
    'enableBidiFallback',
    'log',
    'logPrefix',
    'observerDebounceMs',
    'maxMutationsPerWindow',
    'mutationBurstWindowMs',
    'maxHealsPerMinute',
    'watchHints',
    'rules'
  ]);

  const state = {
    config: { ...DEFAULT_CONFIG },
    applied: false,
    observers: [],
    observedShadowRoots: new WeakSet(),
    observedIframes: new WeakSet(),
    deniedIframes: new WeakSet(),
    deniedIframeCount: 0,
    observedShadowRootCount: 0,
    observedIframeCount: 0,
    healTimer: null,
    healCount: 0,
    mutationStats: {
      windowStart: Date.now(),
      count: 0
    },
    healTimestamps: [],
    frameLoadHooks: []
  };

  const logger = {
    info(msg, ...rest) { if (state.config.log) console.log(`✅ ${state.config.logPrefix}: ${msg}`, ...rest); },
    warn(msg, ...rest) { if (state.config.log) console.warn(`⚠️ ${state.config.logPrefix}: ${msg}`, ...rest); },
    error(msg, ...rest) { console.error(`❌ ${state.config.logPrefix}: ${msg}`, ...rest); }
  };

  function deepClone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function getPresetConfig(name) {
    const preset = PRESET_OVERRIDES[name] ? name : 'balanced';
    const merged = {
      ...DEFAULT_CONFIG,
      ...(PRESET_OVERRIDES[preset] || {})
    };

    merged.rules = deepClone((PRESET_OVERRIDES[preset] && PRESET_OVERRIDES[preset].rules) || DEFAULT_CONFIG.rules);
    merged.watchHints = deepClone((PRESET_OVERRIDES[preset] && PRESET_OVERRIDES[preset].watchHints) || DEFAULT_CONFIG.watchHints);
    return merged;
  }

  function canUseStorage() {
    try {
      return Boolean(global.localStorage);
    } catch (_) {
      return false;
    }
  }

  function pickPersistableConfig(config) {
    const snapshot = {};
    for (const key of PERSISTABLE_KEYS) {
      if (key in config) snapshot[key] = config[key];
    }
    return snapshot;
  }

  function saveConfig() {
    if (!state.config.persistConfig || !canUseStorage()) return false;
    try {
      const payload = pickPersistableConfig(state.config);
      global.localStorage.setItem(state.config.storageKey, JSON.stringify(payload));
      return true;
    } catch (err) {
      logger.warn('Failed to save config to localStorage.', err);
      return false;
    }
  }

  function loadSavedConfig() {
    if (!canUseStorage()) return null;
    try {
      const raw = global.localStorage.getItem(DEFAULT_CONFIG.storageKey);
      if (!raw) return null;
      const parsed = JSON.parse(raw);
      if (!parsed || typeof parsed !== 'object') return null;
      return parsed;
    } catch (err) {
      logger.warn('Failed to load saved config from localStorage.', err);
      return null;
    }
  }

  function clearSavedConfig() {
    if (!canUseStorage()) return false;
    try {
      global.localStorage.removeItem(state.config.storageKey);
      return true;
    } catch (err) {
      logger.warn('Failed to clear saved config.', err);
      return false;
    }
  }

  function buildConfigFromSaved(saved) {
    const base = getPresetConfig(saved && typeof saved.preset === 'string' ? saved.preset : DEFAULT_CONFIG.preset);
    return {
      ...base,
      ...saved,
      rules: { ...base.rules, ...((saved && saved.rules) || {}) },
      watchHints: Array.isArray(saved && saved.watchHints) ? deepClone(saved.watchHints) : deepClone(base.watchHints)
    };
  }

  function toCssRule(selectors, declarations) {
    const body = Object.entries(declarations)
      .map(([prop, value]) => `  ${prop}: ${value} !important;`)
      .join('\n');
    return `${selectors.join(',\n')} {\n${body}\n}`;
  }

  function buildStyleText(rules) {
    const css = Object.values(rules).map(rule => toCssRule(rule.selectors, rule.declarations)).join('\n\n');

    if (!state.config.enableBidiFallback) return css;

    const fallback = [
      '@supports not (unicode-bidi: plaintext) {',
      '  p,',
      '  li,',
      '  span,',
      '  h1,',
      '  h2,',
      '  h3 {',
      '    unicode-bidi: isolate !important;',
      '  }',
      '}'
    ].join('\n');

    return `${css}\n\n${fallback}`;
  }

  function getStyleElFromRoot(root, styleId) {
    if (root instanceof Document) {
      return root.getElementById(styleId);
    }

    if (root instanceof ShadowRoot) {
      return root.querySelector(`style[id="${styleId}"][data-owner="${STYLE_OWNER}"]`);
    }

    return null;
  }

  function createStyleEl(cssText, styleId) {
    const style = document.createElement('style');
    style.id = styleId;
    style.setAttribute('data-owner', STYLE_OWNER);
    style.textContent = cssText;
    return style;
  }

  function appendStyleToRoot(root, styleEl) {
    if (root instanceof Document) {
      const container = root.head || root.documentElement;
      if (!container) return false;
      container.appendChild(styleEl);
      return true;
    }

    if (root instanceof ShadowRoot) {
      root.appendChild(styleEl);
      return true;
    }

    return false;
  }

  function ensureStyleInRoot(root, { force = false, styleId = state.config.styleId } = {}) {
    const existing = getStyleElFromRoot(root, styleId);
    if (existing && !force) {
      return false;
    }
    if (existing) existing.remove();

    const styleEl = createStyleEl(buildStyleText(state.config.rules), styleId);
    return appendStyleToRoot(root, styleEl);
  }

  function getMainStyleEl() {
    return getStyleElFromRoot(document, state.config.styleId);
  }

  function ensureMainStyle({ force = false } = {}) {
    const changed = ensureStyleInRoot(document, { force, styleId: state.config.styleId });
    state.applied = Boolean(getMainStyleEl());
    return changed;
  }

  function isRateLimitedHeal() {
    const now = Date.now();
    const oneMinuteAgo = now - 60000;
    state.healTimestamps = state.healTimestamps.filter(ts => ts >= oneMinuteAgo);
    return state.healTimestamps.length >= state.config.maxHealsPerMinute;
  }

  function markHeal() {
    state.healTimestamps.push(Date.now());
  }

  function observeTarget(target, callback, options) {
    const observer = new MutationObserver(callback);
    observer.observe(target, options);
    state.observers.push(observer);
    return observer;
  }

  function removeStyleFromRoot(root, styleId) {
    const style = getStyleElFromRoot(root, styleId);
    if (style) style.remove();
  }

  function forEachElementWithShadowRoot(root, callback) {
    const elements = root.querySelectorAll('*');
    for (const el of elements) {
      if (el.shadowRoot) callback(el.shadowRoot);
    }
  }

  function forEachAccessibleIframe(root, callback) {
    const frames = root.querySelectorAll('iframe');
    for (const frame of frames) {
      try {
        const frameDoc = frame.contentDocument;
        if (!frameDoc) continue;
        callback(frame, frameDoc);
      } catch (_) {
        if (!state.deniedIframes.has(frame)) {
          state.deniedIframes.add(frame);
          state.deniedIframeCount += 1;
          logger.warn('Skipped a cross-origin iframe (cannot access document).');
        }
      }
    }
  }

  function shadowStyleId() {
    return `${state.config.styleId}-shadow`;
  }

  function iframeStyleId() {
    return `${state.config.styleId}-iframe`;
  }

  function observeShadowRoot(shadowRoot) {
    if (!state.config.supportsShadowDom) return;
    if (state.observedShadowRoots.has(shadowRoot)) return;

    state.observedShadowRoots.add(shadowRoot);
    state.observedShadowRootCount += 1;
    ensureStyleInRoot(shadowRoot, { styleId: shadowStyleId() });

    observeTarget(shadowRoot, (mutations) => {
      processMutations(mutations, 'shadow-root');
    }, {
      childList: true,
      subtree: true
    });

    if (state.config.supportsIframes) {
      forEachAccessibleIframe(shadowRoot, (frame) => observeIframe(frame));
    }
  }

  function observeIframe(frame) {
    if (!state.config.supportsIframes) return;
    if (state.observedIframes.has(frame)) return;

    let frameDoc;
    try {
      frameDoc = frame.contentDocument;
    } catch (_) {
      return;
    }

    if (!frameDoc) return;
    state.observedIframes.add(frame);
    state.observedIframeCount += 1;

    ensureStyleInRoot(frameDoc, { styleId: iframeStyleId() });

    const frameBody = frameDoc.body || frameDoc.documentElement;
    if (frameBody) {
      observeTarget(frameBody, (mutations) => {
        processMutations(mutations, 'iframe');
      }, {
        childList: true,
        subtree: true
      });
    }

    if (state.config.supportsShadowDom) {
      forEachElementWithShadowRoot(frameDoc, (root) => observeShadowRoot(root));
    }

    const onFrameLoad = () => {
      if (!state.applied) return;
      try {
        const loadedDoc = frame.contentDocument;
        if (!loadedDoc) return;
        ensureStyleInRoot(loadedDoc, { force: true, styleId: iframeStyleId() });
        if (state.config.supportsShadowDom) {
          forEachElementWithShadowRoot(loadedDoc, (root) => observeShadowRoot(root));
        }
      } catch (_) {
        // Ignore cross-origin transitions
      }
    };

    frame.addEventListener('load', onFrameLoad);
    state.frameLoadHooks.push({ frame, onFrameLoad });
  }

  function scanDynamicRoots(root = document) {
    if (state.config.supportsShadowDom) {
      forEachElementWithShadowRoot(root, (shadowRoot) => observeShadowRoot(shadowRoot));
    }

    if (state.config.supportsIframes) {
      forEachAccessibleIframe(root, (frame) => observeIframe(frame));
    }
  }

  function discoverTargetsFromMutations(mutations) {
    if (!state.config.supportsShadowDom && !state.config.supportsIframes) return;

    for (const mutation of mutations) {
      if (mutation.type !== 'childList') continue;
      for (const node of mutation.addedNodes) {
        if (!(node instanceof Element)) continue;

        if (state.config.supportsShadowDom && node.shadowRoot) {
          observeShadowRoot(node.shadowRoot);
        }

        if (state.config.supportsShadowDom) {
          const descendants = node.querySelectorAll('*');
          for (const el of descendants) {
            if (el.shadowRoot) observeShadowRoot(el.shadowRoot);
          }
        }

        if (state.config.supportsIframes) {
          if (node.tagName === 'IFRAME') {
            observeIframe(node);
          }
          const nestedFrames = node.querySelectorAll('iframe');
          for (const frame of nestedFrames) observeIframe(frame);
        }
      }
    }
  }

  function isMutationBurst(mutations) {
    const now = Date.now();
    const elapsed = now - state.mutationStats.windowStart;
    if (elapsed > state.config.mutationBurstWindowMs) {
      state.mutationStats.windowStart = now;
      state.mutationStats.count = 0;
    }

    state.mutationStats.count += mutations.length;
    return state.mutationStats.count > state.config.maxMutationsPerWindow;
  }

  function shouldHealFromMutations(mutations) {
    const hints = state.config.watchHints || [];
    if (!hints.length) return true;

    for (const m of mutations) {
      if (m.type !== 'childList') continue;
      for (const node of m.addedNodes) {
        if (!(node instanceof Element)) continue;
        const cls = typeof node.className === 'string' ? node.className : '';
        if (hints.some(h => cls.includes(h))) return true;

        if (node.querySelector) {
          for (const h of hints) {
            if (node.querySelector(`[class*="${h}"]`)) return true;
          }
        }
      }
    }
    return false;
  }

  function ensureStylesEverywhere() {
    ensureMainStyle({ force: false });

    if (state.config.supportsShadowDom) {
      forEachElementWithShadowRoot(document, (root) => {
        ensureStyleInRoot(root, { force: false, styleId: shadowStyleId() });
      });
    }

    if (state.config.supportsIframes) {
      forEachAccessibleIframe(document, (_, frameDoc) => {
        ensureStyleInRoot(frameDoc, { force: false, styleId: iframeStyleId() });
      });
    }
  }

  function processMutations(mutations, source) {
    const burst = isMutationBurst(mutations);
    discoverTargetsFromMutations(mutations);

    const styleMissing = !getMainStyleEl();
    if (styleMissing) {
      scheduleHeal(`${source}:style-missing`);
      return;
    }

    if (burst) {
      scheduleHeal(`${source}:burst`);
      return;
    }

    if (shouldHealFromMutations(mutations)) {
      scheduleHeal(`${source}:hint`);
    }
  }

  function scheduleHeal(reason = 'mutation') {
    if (state.healTimer) clearTimeout(state.healTimer);

    state.healTimer = setTimeout(() => {
      state.healTimer = null;
      if (!state.applied) return;

       if (isRateLimitedHeal()) {
        logger.warn(`Heal skipped due to rate-limit (${reason}).`);
        return;
      }

      const hadMainStyle = Boolean(getMainStyleEl());
      ensureStylesEverywhere();
      const changed = ensureMainStyle({ force: false });
      const hasMainStyleNow = Boolean(getMainStyleEl());
      const healed = (!hadMainStyle && hasMainStyleNow) || changed;

      if (healed || !hasMainStyleNow) {
        ensureMainStyle({ force: true });
        state.healCount += 1;
        markHeal();
        logger.info(`Self-heal executed (${reason}). count=${state.healCount}`);
      }
    }, state.config.observerDebounceMs);
  }

  function onVisibilityChange() {
    if (document.visibilityState === 'visible' && state.applied) {
      scheduleHeal('visibilitychange');
    }
  }

  function startObserver() {
    if (state.observers.length) return;
    if (!document.body) {
      logger.warn('document.body not ready; observer skipped for now.');
      return;
    }

    observeTarget(document.body, (mutations) => {
      processMutations(mutations, 'document');
    }, {
      childList: true,
      subtree: Boolean(state.config.observeSubtree)
    });

    scanDynamicRoots(document);

    document.addEventListener('visibilitychange', onVisibilityChange, { passive: true });
    logger.info('Observer started.');
  }

  function stopObserver() {
    if (state.observers.length) {
      for (const observer of state.observers) observer.disconnect();
      state.observers = [];
    }

    state.observedShadowRoots = new WeakSet();
    state.observedIframes = new WeakSet();
    state.deniedIframes = new WeakSet();
    state.observedShadowRootCount = 0;
    state.observedIframeCount = 0;
    state.deniedIframeCount = 0;

    if (state.frameLoadHooks.length) {
      for (const hook of state.frameLoadHooks) {
        hook.frame.removeEventListener('load', hook.onFrameLoad);
      }
      state.frameLoadHooks = [];
    }

    if (state.healTimer) {
      clearTimeout(state.healTimer);
      state.healTimer = null;
    }
    document.removeEventListener('visibilitychange', onVisibilityChange);
    logger.info('Observer stopped.');
  }

  function apply(options = {}) {
    try {
      const changed = ensureMainStyle(options);
      ensureStylesEverywhere();
      scanDynamicRoots(document);

      if (changed || getMainStyleEl()) logger.info('RTL style applied.');
      if (state.config.autoHeal) startObserver();
      return { ok: true, changed };
    } catch (err) {
      logger.error('Failed to apply style.', err);
      return { ok: false, error: err };
    }
  }

  function remove() {
    removeStyleFromRoot(document, state.config.styleId);

    forEachElementWithShadowRoot(document, (root) => {
      removeStyleFromRoot(root, shadowStyleId());
    });

    forEachAccessibleIframe(document, (_, frameDoc) => {
      removeStyleFromRoot(frameDoc, iframeStyleId());
      if (state.config.supportsShadowDom) {
        forEachElementWithShadowRoot(frameDoc, (root) => {
          removeStyleFromRoot(root, shadowStyleId());
        });
      }
    });

    state.applied = false;
    stopObserver();
    logger.info('RTL style removed.');
    return { ok: true };
  }

  function toggle(enabled) {
    return enabled ? apply() : remove();
  }

  function update(partialConfig = {}) {
    const nextPreset = typeof partialConfig.preset === 'string' ? partialConfig.preset : state.config.preset;
    const presetBase = getPresetConfig(nextPreset);

    state.config = {
      ...presetBase,
      ...state.config,
      ...partialConfig,
      rules: {
        ...presetBase.rules,
        ...state.config.rules,
        ...(partialConfig.rules || {})
      },
      watchHints: Array.isArray(partialConfig.watchHints)
        ? deepClone(partialConfig.watchHints)
        : deepClone(state.config.watchHints || presetBase.watchHints)
    };

    if (state.config.persistConfig) saveConfig();

    if (state.applied) apply({ force: true });
    if (!state.config.autoHeal) stopObserver();
    return { ok: true };
  }

  function setPreset(name, { applyNow = true } = {}) {
    const presetName = PRESET_OVERRIDES[name] ? name : 'balanced';
    const presetConfig = getPresetConfig(presetName);

    state.config = {
      ...presetConfig,
      ...state.config,
      ...presetConfig,
      persistConfig: state.config.persistConfig,
      storageKey: state.config.storageKey,
      log: state.config.log,
      logPrefix: state.config.logPrefix
    };

    if (state.config.persistConfig) saveConfig();
    if (applyNow && state.applied) apply({ force: true });

    logger.info(`Preset switched to "${presetName}".`);
    return { ok: true, preset: presetName };
  }

  function listPresets() {
    return Object.keys(PRESET_OVERRIDES);
  }

  function getCoverageSnapshot() {
    const snapshot = {
      hasMainStyle: Boolean(getMainStyleEl()),
      shadowRootsDetected: 0,
      shadowRootsStyled: 0,
      iframesAccessible: 0,
      iframesStyled: 0,
      deniedIframes: state.deniedIframeCount
    };

    if (state.config.supportsShadowDom) {
      forEachElementWithShadowRoot(document, (root) => {
        snapshot.shadowRootsDetected += 1;
        if (getStyleElFromRoot(root, shadowStyleId())) snapshot.shadowRootsStyled += 1;
      });
    }

    if (state.config.supportsIframes) {
      forEachAccessibleIframe(document, (_, frameDoc) => {
        snapshot.iframesAccessible += 1;
        if (getStyleElFromRoot(frameDoc, iframeStyleId())) snapshot.iframesStyled += 1;
      });
    }

    return snapshot;
  }

  function healthCheck() {
    const coverage = getCoverageSnapshot();
    const checks = {
      domReady: document.readyState !== 'loading',
      appliedFlag: state.applied,
      mainStylePresent: coverage.hasMainStyle,
      observerActive: state.observers.length > 0,
      shadowCoverageOk: coverage.shadowRootsDetected === coverage.shadowRootsStyled,
      iframeCoverageOk: coverage.iframesAccessible === coverage.iframesStyled
    };

    const issues = [];
    if (!checks.mainStylePresent) issues.push('Main style is missing.');
    if (state.config.autoHeal && !checks.observerActive) issues.push('Auto-heal enabled but observer is not active.');
    if (!checks.shadowCoverageOk) issues.push('Some shadow roots are not styled yet.');
    if (!checks.iframeCoverageOk) issues.push('Some accessible iframes are not styled yet.');

    return {
      ok: issues.length === 0,
      checks,
      coverage,
      issues
    };
  }

  function restoreConfig({ applyNow = true } = {}) {
    const saved = loadSavedConfig();
    if (!saved) {
      return { ok: false, message: 'No saved config found.' };
    }

    state.config = buildConfigFromSaved(saved);
    if (applyNow && state.applied) apply({ force: true });
    return { ok: true, preset: state.config.preset };
  }

  function status() {
    return {
      applied: state.applied,
      preset: state.config.preset,
      hasStyleElement: Boolean(getMainStyleEl()),
      observerActive: state.observers.length > 0,
      observerCount: state.observers.length,
      observedShadowRootCount: state.observedShadowRootCount,
      observedIframeCount: state.observedIframeCount,
      deniedIframeCount: state.deniedIframeCount,
      healCount: state.healCount,
      styleId: state.config.styleId
    };
  }

  function uninstall() {
    remove();
    const styleIds = [state.config.styleId, 'copilot-rtl-fix-style'];
    for (const id of styleIds) {
      document.getElementById(id)?.remove();
    }

    try {
      delete global.CopilotRTLFix;
    } catch (_) {
      global.CopilotRTLFix = undefined;
    }

    console.log('🧹 CopilotRTLFix fully uninstalled.');
  }

  const savedConfig = loadSavedConfig();
  if (savedConfig) {
    state.config = buildConfigFromSaved(savedConfig);
  } else {
    state.config = getPresetConfig(DEFAULT_CONFIG.preset);
  }

  global.CopilotRTLFix = Object.freeze({
    apply,
    remove,
    toggle,
    update,
    setPreset,
    listPresets,
    startObserver,
    stopObserver,
    saveConfig,
    loadSavedConfig,
    restoreConfig,
    clearSavedConfig,
    healthCheck,
    status,
    uninstall
  });

  if (state.config.autoApply) {
    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', () => apply(), { once: true });
    } else {
      apply();
    }
  }
})(window);
