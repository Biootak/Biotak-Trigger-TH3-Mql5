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
    scopeSelectors: [
      '.interactive-item-container',
      'div[role="log"]',
      '.chat',
      '[data-testid*="chat"]',
      '[class*="chat-view"]'
    ],
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
        selectors: [
          'p',
          'li',
          'span',
          'div',
          'a',
          'label',
          'button',
          'blockquote',
          'td',
          'th',
          'h1',
          'h2',
          'h3',
          'h4',
          'h5',
          'h6'
        ],
        declarations: {
          'unicode-bidi': 'plaintext',
          'text-align': 'start'
        }
      },
      explicitRTL: {
        selectors: ['[dir="rtl"]', '[data-dir="rtl"]', '[data-direction="rtl"]'],
        declarations: {
          direction: 'rtl',
          'text-align': 'right',
          'unicode-bidi': 'isolate'
        }
      },
      explicitLTR: {
        selectors: ['[dir="ltr"]', '[data-dir="ltr"]', '[data-direction="ltr"]'],
        declarations: {
          direction: 'ltr',
          'text-align': 'left',
          'unicode-bidi': 'isolate'
        }
      },
      autoDirection: {
        selectors: ['[dir="auto"]', 'bdi'],
        declarations: {
          'unicode-bidi': 'plaintext',
          'text-align': 'start'
        }
      },
      inlineCodeSafety: {
        selectors: ['span[class*="token"]', 'code:not(pre code)'],
        declarations: {
          direction: 'ltr',
          'unicode-bidi': 'isolate'
        }
      },
      blockCodeSafety: {
        selectors: ['pre', '.monaco-editor', '.code-block-container', '.rendered-markdown pre code'],
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
      scopeSelectors: [
        '.interactive-item-container',
        'div[role="log"]',
        '[data-testid*="chat"]'
      ],
      rules: {
        containers: DEFAULT_CONFIG.rules.containers,
        mixedText: DEFAULT_CONFIG.rules.mixedText,
        explicitRTL: DEFAULT_CONFIG.rules.explicitRTL,
        explicitLTR: DEFAULT_CONFIG.rules.explicitLTR,
        autoDirection: DEFAULT_CONFIG.rules.autoDirection,
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
      scopeSelectors: [
        '.interactive-item-container',
        'div[role="log"]',
        '.chat',
        '[data-testid*="chat"]',
        '[class*="chat"]',
        '[class*="interactive"]'
      ],
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
    'scopeSelectors',
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

  const BIDI_CONTROLS = Object.freeze({
    LRI: '\u2066',
    RLI: '\u2067',
    FSI: '\u2068',
    PDI: '\u2069'
  });

  function deepClone(value) {
    return JSON.parse(JSON.stringify(value));
  }

  function normalizeDir(value, fallback = 'auto') {
    const raw = typeof value === 'string' ? value.trim().toLowerCase() : '';
    if (raw === 'rtl' || raw === 'ltr' || raw === 'auto') return raw;
    return fallback;
  }

  function toSafeText(value) {
    return value == null ? '' : String(value);
  }

  function toUnicodeIsolate(text, dir = 'auto') {
    const safeDir = normalizeDir(dir, 'auto');
    const content = toSafeText(text);
    if (!content) return content;

    if (safeDir === 'rtl') return `${BIDI_CONTROLS.RLI}${content}${BIDI_CONTROLS.PDI}`;
    if (safeDir === 'ltr') return `${BIDI_CONTROLS.LRI}${content}${BIDI_CONTROLS.PDI}`;
    return `${BIDI_CONTROLS.FSI}${content}${BIDI_CONTROLS.PDI}`;
  }

  function isElementNode(node) {
    return Boolean(node && node.nodeType === 1);
  }

  function resolveDocumentRef(documentRef) {
    if (documentRef && typeof documentRef.createElement === 'function') {
      return documentRef;
    }
    return document;
  }

  function createBidiNode(text, {
    dir = 'auto',
    tagName = 'span',
    className = '',
    documentRef = document
  } = {}) {
    const safeDir = normalizeDir(dir, 'auto');
    const safeTag = (typeof tagName === 'string' && tagName.trim()) ? tagName.trim().toLowerCase() : 'span';
    const docRef = resolveDocumentRef(documentRef);
    const el = docRef.createElement(safeTag === 'bdi' ? 'bdi' : safeTag);

    if (el.tagName !== 'BDI') {
      el.setAttribute('dir', safeDir);
    }

    if (typeof className === 'string' && className.trim()) {
      el.className = className.trim();
    }

    el.textContent = toSafeText(text);
    return el;
  }

  function appendBidiText(target, text, options = {}) {
    if (!isElementNode(target)) {
      return { ok: false, message: 'Target must be a DOM Element.' };
    }

    const node = createBidiNode(text, {
      ...options,
      documentRef: target.ownerDocument || document
    });
    target.appendChild(node);
    return { ok: true, node };
  }

  function sanitizeStringArray(value, fallback = []) {
    if (!Array.isArray(value)) return deepClone(fallback);
    const cleaned = value
      .filter((item) => typeof item === 'string')
      .map((item) => item.trim())
      .filter(Boolean);
    return cleaned.length ? Array.from(new Set(cleaned)) : deepClone(fallback);
  }

  function sanitizeDeclarations(value, fallback = {}) {
    const base = (fallback && typeof fallback === 'object') ? { ...fallback } : {};
    if (!value || typeof value !== 'object') return base;

    for (const [key, val] of Object.entries(value)) {
      if (!key || typeof key !== 'string') continue;
      if (typeof val !== 'string' && typeof val !== 'number') continue;
      base[key] = String(val).trim();
    }

    return base;
  }

  function normalizeRule(rule, fallbackRule) {
    const fallback = fallbackRule || { selectors: [], declarations: {} };
    const selectors = sanitizeStringArray(rule && rule.selectors, fallback.selectors || []);
    const declarations = sanitizeDeclarations(rule && rule.declarations, fallback.declarations || {});
    return { selectors, declarations };
  }

  function mergeRules(baseRules, overrideRules) {
    const base = (baseRules && typeof baseRules === 'object') ? baseRules : {};
    const overrides = (overrideRules && typeof overrideRules === 'object') ? overrideRules : {};
    const keys = Array.from(new Set([...Object.keys(base), ...Object.keys(overrides)]));
    const merged = {};

    for (const key of keys) {
      const fallbackRule = normalizeRule(base[key], { selectors: [], declarations: {} });
      merged[key] = normalizeRule(overrides[key], fallbackRule);
    }

    return merged;
  }

  function getStorageKey() {
    return DEFAULT_CONFIG.storageKey;
  }

  function getPresetConfig(name) {
    const preset = PRESET_OVERRIDES[name] ? name : 'balanced';
    const merged = {
      ...DEFAULT_CONFIG,
      ...(PRESET_OVERRIDES[preset] || {})
    };

    merged.rules = deepClone((PRESET_OVERRIDES[preset] && PRESET_OVERRIDES[preset].rules) || DEFAULT_CONFIG.rules);
    merged.scopeSelectors = deepClone((PRESET_OVERRIDES[preset] && PRESET_OVERRIDES[preset].scopeSelectors) || DEFAULT_CONFIG.scopeSelectors);
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
      global.localStorage.setItem(getStorageKey(), JSON.stringify(payload));
      return true;
    } catch (err) {
      logger.warn('Failed to save config to localStorage.', err);
      return false;
    }
  }

  function loadSavedConfig() {
    if (!canUseStorage()) return null;
    try {
      const raw = global.localStorage.getItem(getStorageKey());
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
      global.localStorage.removeItem(getStorageKey());
      return true;
    } catch (err) {
      logger.warn('Failed to clear saved config.', err);
      return false;
    }
  }

  function buildConfigFromSaved(saved) {
    const base = getPresetConfig(saved && typeof saved.preset === 'string' ? saved.preset : DEFAULT_CONFIG.preset);
    const normalizedRules = mergeRules(base.rules, saved && saved.rules);
    return {
      ...base,
      ...saved,
      storageKey: DEFAULT_CONFIG.storageKey,
      rules: normalizedRules,
      scopeSelectors: sanitizeStringArray(saved && saved.scopeSelectors, base.scopeSelectors),
      watchHints: sanitizeStringArray(saved && saved.watchHints, base.watchHints)
    };
  }

  function toCssRule(selectors, declarations) {
    const body = Object.entries(declarations)
      .map(([prop, value]) => `  ${prop}: ${value} !important;`)
      .join('\n');
    return `${selectors.join(',\n')} {\n${body}\n}`;
  }

  function getScopedSelectors(ruleName, selectors) {
    const cleanSelectors = sanitizeStringArray(selectors, []);
    if (!cleanSelectors.length) return [];
    if (ruleName === 'containers') return cleanSelectors;

    const scopes = sanitizeStringArray(state.config.scopeSelectors, []);
    if (!scopes.length) return cleanSelectors;

    const scoped = [];
    for (const scope of scopes) {
      for (const selector of cleanSelectors) {
        scoped.push(`${scope} ${selector}`);
      }
    }

    return Array.from(new Set(scoped));
  }

  function buildStyleText(rules) {
    const normalizedRules = Object.entries(rules)
      .map(([ruleName, rule]) => {
        const fallbackRule = (DEFAULT_CONFIG.rules && DEFAULT_CONFIG.rules[ruleName]) || { selectors: [], declarations: {} };
        const normalized = normalizeRule(rule, fallbackRule);
        const scopedSelectors = getScopedSelectors(ruleName, normalized.selectors);
        return {
          selectors: scopedSelectors,
          declarations: normalized.declarations
        };
      })
      .filter((rule) => (
        Array.isArray(rule.selectors)
        && rule.selectors.length > 0
        && rule.declarations
        && Object.keys(rule.declarations).length > 0
      ));

    const css = normalizedRules.map(rule => toCssRule(rule.selectors, rule.declarations)).join('\n\n');

    if (!state.config.enableBidiFallback) return css;

    const fallbackSelectors = Array.from(new Set(
      (rules.mixedText && Array.isArray(rules.mixedText.selectors)
        ? getScopedSelectors('mixedText', rules.mixedText.selectors)
        : ['p', 'li', 'span', 'h1', 'h2', 'h3'])
    ));

    if (!fallbackSelectors.length) return css;

    const fallback = [
      '@supports not (unicode-bidi: plaintext) {',
      ...fallbackSelectors.map((selector, index) => (
        `  ${selector}${index < fallbackSelectors.length - 1 ? ',' : ''}`
      )),
      '  {',
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

  function createStyleEl(cssText, styleId, documentRef = document) {
    const docRef = (documentRef && typeof documentRef.createElement === 'function') ? documentRef : document;
    const style = docRef.createElement('style');
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

    const docRef =
      (root instanceof Document) ? root
      : (root instanceof ShadowRoot && root.host && root.host.ownerDocument) ? root.host.ownerDocument
      : (document && document);

    const styleEl = createStyleEl(buildStyleText(state.config.rules), styleId, docRef);
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
    let changes = 0;

    if (ensureMainStyle({ force: false })) changes += 1;

    if (state.config.supportsShadowDom) {
      forEachElementWithShadowRoot(document, (root) => {
        if (ensureStyleInRoot(root, { force: false, styleId: shadowStyleId() })) changes += 1;
      });
    }

    if (state.config.supportsIframes) {
      forEachAccessibleIframe(document, (_, frameDoc) => {
        if (ensureStyleInRoot(frameDoc, { force: false, styleId: iframeStyleId() })) changes += 1;
      });
    }

    return changes;
  }

  function hasCoverageGap() {
    const coverage = getCoverageSnapshot();
    if (!coverage.hasMainStyle) return true;
    if (state.config.supportsShadowDom && coverage.shadowRootsDetected !== coverage.shadowRootsStyled) return true;
    if (state.config.supportsIframes && coverage.iframesAccessible !== coverage.iframesStyled) return true;
    return false;
  }

  function processMutations(mutations, source) {
    const burst = isMutationBurst(mutations);
    discoverTargetsFromMutations(mutations);

    if (hasCoverageGap()) {
      scheduleHeal(`${source}:coverage-gap`);
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
      const changes = ensureStylesEverywhere();
      const changed = Boolean(changes);
      const hasMainStyleNow = Boolean(getMainStyleEl());
      const coverageGap = hasCoverageGap();
      const healed = (!hadMainStyle && hasMainStyleNow) || changed || coverageGap;

      if (healed || !hasMainStyleNow || coverageGap) {
        ensureMainStyle({ force: true });
        ensureStylesEverywhere();
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
    const hasPresetOverride = typeof partialConfig.preset === 'string';
    const nextPreset = hasPresetOverride ? partialConfig.preset : state.config.preset;
    const presetBase = getPresetConfig(nextPreset);

    const baseConfig = hasPresetOverride
      ? {
        ...presetBase,
        persistConfig: state.config.persistConfig,
        storageKey: DEFAULT_CONFIG.storageKey,
        log: state.config.log,
        logPrefix: state.config.logPrefix
      }
      : { ...state.config };

    const mergedRules = mergeRules(baseConfig.rules, partialConfig.rules);

    state.config = {
      ...baseConfig,
      ...partialConfig,
      storageKey: DEFAULT_CONFIG.storageKey,
      rules: mergedRules,
      scopeSelectors: sanitizeStringArray(
        partialConfig.scopeSelectors,
        hasPresetOverride ? presetBase.scopeSelectors : baseConfig.scopeSelectors
      ),
      watchHints: sanitizeStringArray(
        partialConfig.watchHints,
        hasPresetOverride ? presetBase.watchHints : baseConfig.watchHints
      )
    };

    if (state.config.persistConfig) saveConfig();

    if (state.applied) apply({ force: true });
    if (state.config.autoHeal) {
      stopObserver();
      if (state.applied) startObserver();
    } else {
      stopObserver();
    }
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
      storageKey: DEFAULT_CONFIG.storageKey,
      log: state.config.log,
      logPrefix: state.config.logPrefix
    };

    if (state.config.persistConfig) saveConfig();
    if (applyNow && state.applied) apply({ force: true });

    if (state.config.autoHeal) {
      stopObserver();
      if (state.applied) startObserver();
    } else {
      stopObserver();
    }

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

  function runSelfCheck() {
    const health = healthCheck();
    const requiredRules = [
      'containers',
      'mixedText',
      'explicitRTL',
      'explicitLTR',
      'autoDirection',
      'inlineCodeSafety',
      'blockCodeSafety',
      'iconSafety'
    ];

    const missingRules = requiredRules.filter((ruleName) => !state.config.rules || !state.config.rules[ruleName]);
    const scopeSelectors = sanitizeStringArray(state.config.scopeSelectors, []);
    const watchHints = sanitizeStringArray(state.config.watchHints, []);

    const sample = 'نمونه Test 123';
    const isolateSamples = {
      rtl: toUnicodeIsolate(sample, 'rtl'),
      ltr: toUnicodeIsolate(sample, 'ltr'),
      auto: toUnicodeIsolate(sample, 'auto')
    };

    const isolateCheck = {
      rtlWrapped: isolateSamples.rtl.startsWith(BIDI_CONTROLS.RLI) && isolateSamples.rtl.endsWith(BIDI_CONTROLS.PDI),
      ltrWrapped: isolateSamples.ltr.startsWith(BIDI_CONTROLS.LRI) && isolateSamples.ltr.endsWith(BIDI_CONTROLS.PDI),
      autoWrapped: isolateSamples.auto.startsWith(BIDI_CONTROLS.FSI) && isolateSamples.auto.endsWith(BIDI_CONTROLS.PDI)
    };

    const issues = [...health.issues];
    if (missingRules.length) issues.push(`Missing required rules: ${missingRules.join(', ')}`);
    if (!scopeSelectors.length) issues.push('scopeSelectors is empty; styles may apply too broadly.');
    if (!watchHints.length) issues.push('watchHints is empty; mutation filtering may become noisy.');
    if (!isolateCheck.rtlWrapped || !isolateCheck.ltrWrapped || !isolateCheck.autoWrapped) {
      issues.push('Unicode isolate wrappers failed sanity check.');
    }

    return {
      ok: issues.length === 0,
      preset: state.config.preset,
      health,
      checks: {
        missingRules,
        scopeSelectorCount: scopeSelectors.length,
        watchHintCount: watchHints.length,
        isolateCheck
      },
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
    runSelfCheck,
    status,
    toUnicodeIsolate,
    createBidiNode,
    appendBidiText,
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
