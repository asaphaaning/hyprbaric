/**
 * Loads the shared Flutter engine that hosts every landing-page preview.
 *
 * The previews used to run one engine per iframe, which downloaded CanvasKit
 * and the app bundle once per preview. The build already enables Flutter's
 * multi-view mode, so a single engine can host all of them as views.
 *
 * Views outlive the React tree. Leaving the landing page parks each host
 * element instead of calling `removeView`, so returning home reattaches the
 * same surfaces instead of adding a new view per card.
 */

let pending = null;
let loadedFrom = null;

/** @type {Map<string, PreviewSlot>} */
const previews = new Map();

const READY_TIMEOUT_MS = 20000;

/**
 * @typedef {object} PreviewSlot
 * @property {string} bootstrapUrl
 * @property {HTMLElement} element
 * @property {unknown} app
 * @property {unknown} viewId
 */

function loadScript(url) {
  let absolute = url;
  try {
    absolute = new URL(url, document.baseURI || window.location?.href || 'http://localhost/').href;
  } catch {
    absolute = url;
  }

  const scripts = typeof document.querySelectorAll === 'function'
    ? [...document.querySelectorAll('script')]
    : [];
  const existing = scripts.find((script) => script.src === absolute || script.src === url);
  if (existing) {
    if (window.hyprbaricEmbedsReady) return Promise.resolve();
    return new Promise((resolve, reject) => {
      existing.addEventListener('load', resolve, {once: true});
      existing.addEventListener(
        'error',
        () => reject(new Error(`Could not load the Flutter preview bundle at ${url}.`)),
        {once: true},
      );
    });
  }

  return new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = url;
    script.addEventListener('load', resolve, {once: true});
    script.addEventListener(
      'error',
      () => reject(new Error(`Could not load the Flutter preview bundle at ${url}.`)),
      {once: true},
    );
    document.head.append(script);
  });
}

function withTimeout(promise, message) {
  return new Promise((resolve, reject) => {
    const timer = window.setTimeout(() => reject(new Error(message)), READY_TIMEOUT_MS);
    promise.then(
      (value) => {
        window.clearTimeout(timer);
        resolve(value);
      },
      (error) => {
        window.clearTimeout(timer);
        reject(error);
      },
    );
  });
}

function parkingLot() {
  let node = document.getElementById('hyprbaric-preview-parking');
  if (!node) {
    node = document.createElement('div');
    node.id = 'hyprbaric-preview-parking';
    node.setAttribute('hidden', '');
    node.setAttribute('aria-hidden', 'true');
    node.style.cssText = 'position:absolute;left:0;top:0;width:0;height:0;overflow:hidden;pointer-events:none';
    document.body.append(node);
  }
  return node;
}

function fillHost(element) {
  element.style.position = 'absolute';
  element.style.inset = '0';
  element.style.width = '100%';
  element.style.height = '100%';
}

/**
 * True when this preview already has a live view for `bootstrapUrl`.
 *
 * Landing-page cards use this to skip the skeleton on a client-side return.
 */
export function canReusePreview(preview, bootstrapUrl) {
  const existing = previews.get(preview);
  return Boolean(existing && existing.bootstrapUrl === bootstrapUrl && existing.viewId != null);
}

/**
 * Resolves with the shared Flutter app handle.
 *
 * Repeated calls share one load. A rejected load is not cached, so a preview
 * mounted later can retry rather than inheriting an earlier failure.
 */
export function loadPreviewEngine(bootstrapUrl) {
  if (pending && loadedFrom === bootstrapUrl) return pending;

  if (window.hyprbaricEmbedsReady && window.__hyprbaricPreviewBootstrap === bootstrapUrl) {
    loadedFrom = bootstrapUrl;
    pending = Promise.resolve(window.hyprbaricEmbedsReady);
    return pending;
  }

  loadedFrom = bootstrapUrl;
  pending = withTimeout(
    loadScript(bootstrapUrl).then(() => {
      const ready = window.hyprbaricEmbedsReady;
      if (!ready) {
        throw new Error('The Flutter preview bundle did not start an engine.');
      }
      window.__hyprbaricPreviewBootstrap = bootstrapUrl;
      return ready;
    }),
    'The Flutter previews did not finish starting.',
  );

  pending.catch(() => {
    if (loadedFrom === bootstrapUrl) {
      pending = null;
      loadedFrom = null;
    }
  });

  return pending;
}

/**
 * Puts an existing preview view into [parent], or starts one.
 *
 * A matching parked view is moved, not recreated. A newer bootstrap URL
 * replaces the previous view so a rebuilt bundle cannot leave stale canvases.
 *
 * @param {{preview: string, parent: HTMLElement, bootstrapUrl: string, onReady?: Function, onError?: Function}} options
 * @returns {Promise<void>}
 */
export function attachPreview({preview, parent, bootstrapUrl, onReady, onError}) {
  const existing = previews.get(preview);
  if (existing && existing.bootstrapUrl === bootstrapUrl && existing.viewId != null) {
    fillHost(existing.element);
    parent.append(existing.element);
    onReady?.();
    return Promise.resolve();
  }

  if (existing) {
    try {
      if (existing.app && existing.viewId != null) existing.app.removeView(existing.viewId);
    } catch (error) {
      console.warn('[hyprbaric] Could not replace a stale preview view.', error);
    }
    existing.element.remove();
    previews.delete(preview);
  }

  const element = document.createElement('div');
  fillHost(element);
  parent.append(element);
  const slot = {bootstrapUrl, element, app: null, viewId: null};
  previews.set(preview, slot);

  return loadPreviewEngine(bootstrapUrl)
    .then((app) => {
      if (previews.get(preview) !== slot) return;
      slot.app = app;
      slot.viewId = app.addView({
        hostElement: element,
        initialData: {preview, onReady},
      });
    })
    .catch((error) => {
      if (previews.get(preview) === slot) {
        slot.element.remove();
        previews.delete(preview);
      }
      onError?.(error);
      throw error;
    });
}

/**
 * Parks a preview view without destroying it, so the next attach can reuse it.
 *
 * @param {string} preview
 */
export function detachPreview(preview) {
  const slot = previews.get(preview);
  if (!slot) return;
  // React removes the card from the document before effect cleanups run, so
  // `isConnected` is already false. The slot still holds the host; move it
  // into the parking lot instead of letting the engine drop the view.
  slot.element.style.width = '1px';
  slot.element.style.height = '1px';
  parkingLot().append(slot.element);
}

export {READY_TIMEOUT_MS};
