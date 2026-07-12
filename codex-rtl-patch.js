(() => {
  const VERSION = '1.5.1';
  const STYLE_ID = 'codex-arabic-rtl-patch';
  const RTL_ATTR = 'data-codex-rtl';
  const BIDI_ATTR = 'data-codex-bidi';
  const FORCE_ATTR = 'data-codex-direction';
  const LTR_RUN_ATTR = 'data-codex-ltr-run';
  const CODE_ATTR = 'data-codex-code-ltr';
  const previous = window.__codexArabicRtlPatch;
  if (previous?.version === VERSION) return;
  previous?.cleanup?.();
  document.getElementById(STYLE_ID)?.remove();

  const arabic = /[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]/;
  const latin = /[A-Za-z]/;
  const processed = new WeakMap();
  const pending = new Set();
  let scheduled = false;

  const codeSelector = [
    'pre', 'code', 'kbd', 'samp',
    '[data-testid*="code" i]', '[data-testid*="terminal" i]',
    '[class*="code" i]', '[class*="highlight" i]', '[class*="shiki" i]',
    '[class*="terminal" i]', '[class*="monaco" i]'
  ].join(',');
  const editorSelector = 'textarea,input,[contenteditable="true"],[role="textbox"]';
  const selector = [
    'p', 'ol', 'ul', 'li', 'dl', 'dt', 'dd',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote', 'td', 'th',
    editorSelector, '[class*="truncate"]', '[class*="markdown" i]',
    '[class*="whitespace-pre-wrap" i]', '[data-message-author-role]',
    '[data-testid*="message" i]'
  ].join(',');
  const textBlockSelector = [
    'p', 'li', 'blockquote', 'td', 'th', editorSelector,
    '[class*="markdown" i]', '[class*="whitespace-pre-wrap" i]',
    '[data-message-author-role]', '[data-testid*="message" i]', 'div'
  ].join(',');

  const style = document.createElement('style');
  style.id = STYLE_ID;
  style.textContent = [
    '[' + RTL_ATTR + '="true"] { direction: rtl !important; text-align: right !important; unicode-bidi: isolate !important; }',
    '[' + RTL_ATTR + '="false"] { direction: ltr !important; text-align: left !important; unicode-bidi: isolate !important; }',
    '[' + BIDI_ATTR + '="auto"] { text-align: start !important; unicode-bidi: plaintext !important; }',
    '[' + LTR_RUN_ATTR + '="true"] { direction: ltr !important; unicode-bidi: isolate !important; }',
    '[' + CODE_ATTR + '="true"], [' + CODE_ATTR + '="true"] * { direction: ltr !important; text-align: left !important; unicode-bidi: isolate !important; }',
    '[' + RTL_ATTR + '="true"] :not(pre) > code { display: inline-block; }',
    '.ProseMirror { unicode-bidi: plaintext !important; caret-color: currentColor; }',
    '.ProseMirror[' + RTL_ATTR + '="true"] { padding-inline: 0.125rem; }',
    '[class*="markdown" i][' + RTL_ATTR + '="true"] { width: 100%; }',
    'p, li, blockquote, h1, h2, h3, h4, h5, h6 { unicode-bidi: plaintext; }'
  ].join('\n');
  (document.head || document.documentElement).appendChild(style);

  function isCodeLike(element) {
    return Boolean(element?.closest?.(codeSelector));
  }

  function countCharacters(text) {
    let arabicCount = 0;
    let latinCount = 0;
    for (const character of text || '') {
      if (arabic.test(character)) arabicCount += 1;
      else if (latin.test(character)) latinCount += 1;
    }
    return { arabicCount, latinCount };
  }

  function textDirection(text) {
    const { arabicCount, latinCount } = countCharacters(text);
    if (!arabicCount) return latinCount ? 'ltr' : null;
    if (!latinCount) return 'rtl';
    return arabicCount >= Math.max(2, latinCount * 0.25) ? 'rtl' : 'auto';
  }

  function applyDirection(element) {
    if (!(element instanceof HTMLElement) || isCodeLike(element)) return;
    const text = element.innerText || element.textContent || '';
    const forced = element.getAttribute(FORCE_ATTR);
    const cacheKey = `${forced || ''}\u0000${text}`;
    if (processed.get(element) === cacheKey) return;
    processed.set(element, cacheKey);
    const direction = forced || textDirection(text);

    element.removeAttribute(BIDI_ATTR);
    if (!direction) {
      element.removeAttribute(RTL_ATTR);
      element.setAttribute('dir', 'auto');
      if (element.getAttribute('lang') === 'ar') element.removeAttribute('lang');
      return;
    }
    if (direction === 'auto') {
      element.removeAttribute(RTL_ATTR);
      element.setAttribute(BIDI_ATTR, 'auto');
      element.setAttribute('dir', 'auto');
      element.setAttribute('lang', 'ar');
      return;
    }
    element.setAttribute(RTL_ATTR, direction === 'rtl' ? 'true' : 'false');
    element.setAttribute('dir', direction);
    if (direction === 'rtl') element.setAttribute('lang', 'ar');
    else if (element.getAttribute('lang') === 'ar') element.removeAttribute('lang');
  }

  function applyTextNodeDirection(textNode) {
    if (!arabic.test(textNode.nodeValue || '')) return;
    const parent = textNode.parentElement;
    if (!parent || isCodeLike(parent) || parent.closest(`[${LTR_RUN_ATTR}]`)) return;
    const block = parent.closest(textBlockSelector);
    if (block) applyDirection(block);
  }

  function isolateLtrRuns(element) {
    if (!(element instanceof HTMLElement) || element.matches(editorSelector)) return;
    if (element.getAttribute(RTL_ATTR) !== 'true') return;
    const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
    const textNodes = [];
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      const parent = node.parentElement;
      if (!parent || isCodeLike(parent) || parent.closest(`[${LTR_RUN_ATTR}],${editorSelector}`)) continue;
      if (latin.test(node.nodeValue || '')) textNodes.push(node);
    }

    const ltrRun = /[A-Za-z][A-Za-z0-9._:/\\+@#-]*(?:[ \t]+[A-Za-z][A-Za-z0-9._:/\\+@#-]*)*/g;
    for (const textNode of textNodes) {
      const text = textNode.nodeValue || '';
      const matches = [...text.matchAll(ltrRun)];
      if (!matches.length) continue;
      const fragment = document.createDocumentFragment();
      let offset = 0;
      for (const match of matches) {
        const index = match.index || 0;
        fragment.append(text.slice(offset, index));
        const punctuation = match[0].match(/[.,;:!?]+$/)?.[0] || '';
        const run = punctuation ? match[0].slice(0, -punctuation.length) : match[0];
        if (run) {
          const bdi = document.createElement('bdi');
          bdi.setAttribute('dir', 'ltr');
          bdi.setAttribute(LTR_RUN_ATTR, 'true');
          bdi.textContent = run;
          fragment.append(bdi);
        }
        fragment.append(punctuation);
        offset = index + match[0].length;
      }
      fragment.append(text.slice(offset));
      textNode.replaceWith(fragment);
    }
  }

  function enforceCodeDirection(element) {
    if (!(element instanceof HTMLElement)) return;
    element.removeAttribute(RTL_ATTR);
    element.removeAttribute(BIDI_ATTR);
    element.setAttribute(CODE_ATTR, 'true');
    element.setAttribute('dir', 'ltr');
  }

  function scan(root = document) {
    if (root instanceof HTMLElement && root.matches(codeSelector)) enforceCodeDirection(root);
    root.querySelectorAll?.(codeSelector).forEach(enforceCodeDirection);
    if (root instanceof HTMLElement && root.matches(selector)) applyDirection(root);
    root.querySelectorAll?.(selector).forEach(applyDirection);

    const walkerRoot = root instanceof Document ? root.body : root;
    if (walkerRoot) {
      const walker = document.createTreeWalker(walkerRoot, NodeFilter.SHOW_TEXT);
      for (let node = walker.nextNode(); node; node = walker.nextNode()) applyTextNodeDirection(node);
    }

    if (root instanceof HTMLElement && root.matches(`[${RTL_ATTR}="true"]`)) isolateLtrRuns(root);
    root.querySelectorAll?.(`[${RTL_ATTR}="true"]`).forEach(isolateLtrRuns);
  }

  function scheduleScan(node) {
    const root = node?.nodeType === Node.TEXT_NODE ? node.parentElement : node;
    if (!(root instanceof HTMLElement)) return;
    pending.add(root);
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(() => {
      scheduled = false;
      const batch = [...pending];
      pending.clear();
      batch.forEach(scan);
    });
  }

  const onInput = (event) => {
    const editor = event.target?.closest?.(editorSelector);
    if (editor) applyDirection(editor);
  };

  const onKeydown = (event) => {
    if (!event.ctrlKey || event.key !== 'Shift') return;
    const editor = event.target?.closest?.(editorSelector);
    if (!editor) return;
    if (event.location === KeyboardEvent.DOM_KEY_LOCATION_RIGHT) {
      editor.setAttribute(FORCE_ATTR, 'rtl');
      processed.delete(editor);
      applyDirection(editor);
    } else if (event.location === KeyboardEvent.DOM_KEY_LOCATION_LEFT) {
      editor.setAttribute(FORCE_ATTR, 'ltr');
      processed.delete(editor);
      applyDirection(editor);
    }
  };

  document.addEventListener('input', onInput, true);
  document.addEventListener('keydown', onKeydown, true);
  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      if (mutation.type === 'characterData') scheduleScan(mutation.target);
      mutation.addedNodes.forEach(scheduleScan);
    }
  });
  observer.observe(document.documentElement, { subtree: true, childList: true, characterData: true });

  window.__codexArabicRtlPatch = {
    version: VERSION,
    cleanup() {
      observer.disconnect();
      document.removeEventListener('input', onInput, true);
      document.removeEventListener('keydown', onKeydown, true);
      style.remove();
    }
  };
  scan();
})();
