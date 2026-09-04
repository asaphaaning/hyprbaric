/**
 * Loads the shared Flutter engine that hosts every landing-page preview.
 *
 * The previews used to run one engine per iframe, which downloaded CanvasKit
 * and the app bundle once per preview. The build already enables Flutter's
 * multi-view mode, so a single engine can host all of them as views.
 */

let pending = null;
let loadedFrom = null;

const READY_TIMEOUT_MS = 20000;

function loadScript(url) {
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

/**
 * Resolves with the shared Flutter app handle.
 *
 * Repeated calls share one load. A rejected load is not cached, so a preview
 * mounted later can retry rather than inheriting an earlier failure.
 */
export function loadPreviewEngine(bootstrapUrl) {
  if (pending && loadedFrom === bootstrapUrl) return pending;

  loadedFrom = bootstrapUrl;
  pending = withTimeout(
    loadScript(bootstrapUrl).then(() => {
      const ready = window.hyprbaricEmbedsReady;
      if (!ready) {
        throw new Error('The Flutter preview bundle did not start an engine.');
      }
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

export {READY_TIMEOUT_MS};
