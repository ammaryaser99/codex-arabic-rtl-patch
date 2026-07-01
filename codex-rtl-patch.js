(() => {
  const VERSION = '1.3.1';
  const STYLE_ID = 'codex-arabic-rtl-patch';
  const RTL_ATTR = 'data-codex-rtl';
  const FORCE_ATTR = 'data-codex-direction';
  const previous = window.__codexArabicRtlPatch;
  if (previous?.version === VERSION) return;
  previous?.cleanup?.();
  document.getElementById(STYLE_ID)?.remove();

  const arabic = /[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff\ufb50-\ufdff\ufe70-\ufeff]/;
  const latin = /[A-Za-z]/;

  const style = document.createElement('style');
  style.id = STYLE_ID;
  style.textContent = [
    '[' + RTL_ATTR + '="true"] { direction: rtl !important; text-align: right !important; unicode-bidi: isolate !important; }',
    '[' + RTL_ATTR + '="false"] { direction: ltr !important; text-align: left !important; unicode-bidi: isolate !important; }',
    '[' + RTL_ATTR + '="true"] pre,',
    '[' + RTL_ATTR + '="true"] pre code,',
    '[' + RTL_ATTR + '="true"] [class*="terminal" i] { direction: ltr !important; text-align: left !important; unicode-bidi: isolate !important; }',
    '[' + RTL_ATTR + '="true"] :not(pre) > code,',
    '[' + RTL_ATTR + '="true"] kbd,',
    '[' + RTL_ATTR + '="true"] samp { direction: ltr !important; unicode-bidi: isolate !important; }',
    '.ProseMirror { unicode-bidi: plaintext !important; caret-color: currentColor; }',
    '.ProseMirror[' + RTL_ATTR + '="true"] { unicode-bidi: isolate !important; padding-inline: 0.125rem; }',
    '[class*="markdownContent"][' + RTL_ATTR + '="true"] { width: 100%; }',
    '[class*="markdownContent"][' + RTL_ATTR + '="true"] > * { text-align: right; }'
  ].join('\n');
  (document.head || document.documentElement).appendChild(style);

  const selector = [
    'p', 'ol', 'ul', 'li', 'dl', 'dt', 'dd',
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote', 'td', 'th',
    '[contenteditable="true"]', '[role="textbox"]', '[class*="truncate"]',
    '[class*="markdownContent"]', '[class*="whitespace-pre-wrap"]'
  ].join(',');
  const textBlockSelector = [
    'p', 'li', 'blockquote', 'td', 'th',
    '[contenteditable="true"]', '[role="textbox"]',
    '[class*="markdownContent"]', '[class*="whitespace-pre-wrap"]',
    'div'
  ].join(',');

  function textDirection(text) {
    if (arabic.test(text || '')) return 'rtl';
    for (const char of text || '') {
      if (latin.test(char)) return 'ltr';
    }
    return null;
  }

  function applyDirection(element) {
    if (!(element instanceof HTMLElement)) return;
    const forced = element.getAttribute(FORCE_ATTR);
    const direction = forced || textDirection(element.innerText || element.textContent || '');
    if (!direction) {
      element.removeAttribute(RTL_ATTR);
      element.setAttribute('dir', 'auto');
      return;
    }
    element.setAttribute(RTL_ATTR, direction === 'rtl' ? 'true' : 'false');
    element.setAttribute('dir', direction);
    if (direction === 'rtl') element.setAttribute('lang', 'ar');
    else if (element.getAttribute('lang') === 'ar') element.removeAttribute('lang');
  }

  function applyTextNodeDirection(textNode) {
    const text = textNode.nodeValue || '';
    if (!arabic.test(text)) return;
    const parent = textNode.parentElement;
    if (!parent || parent.closest('pre, code, kbd, samp, script, style')) return;
    const block = parent.closest(textBlockSelector);
    if (block) applyDirection(block);
  }

  function scan(root = document) {
    if (root instanceof HTMLElement && root.matches(selector)) applyDirection(root);
    root.querySelectorAll?.(selector).forEach(applyDirection);
    const walkerRoot = root instanceof Document ? root.body : root;
    if (!walkerRoot) return;
    const walker = document.createTreeWalker(walkerRoot, NodeFilter.SHOW_TEXT);
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      applyTextNodeDirection(node);
    }
  }

  let queued = false;
  const queueScan = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      scan();
    });
  };

  const onInput = (event) => {
    const editor = event.target?.closest?.('[contenteditable="true"],[role="textbox"]');
    if (editor) applyDirection(editor);
  };

  const onKeydown = (event) => {
    if (!event.ctrlKey || event.key !== 'Shift') return;
    const editor = event.target?.closest?.('[contenteditable="true"],[role="textbox"]');
    if (!editor) return;
    if (event.location === KeyboardEvent.DOM_KEY_LOCATION_RIGHT) {
      editor.setAttribute(FORCE_ATTR, 'rtl');
      applyDirection(editor);
    } else if (event.location === KeyboardEvent.DOM_KEY_LOCATION_LEFT) {
      editor.setAttribute(FORCE_ATTR, 'ltr');
      applyDirection(editor);
    }
  };

  document.addEventListener('input', onInput, true);
  document.addEventListener('keydown', onKeydown, true);

  const observer = new MutationObserver(queueScan);
  observer.observe(document.documentElement, {
    subtree: true, childList: true, characterData: true
  });
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
