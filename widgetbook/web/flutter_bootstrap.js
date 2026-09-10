{{flutter_js}}
{{flutter_build_config}}

(() => {
  const scriptUrl = document.currentScript?.src ?? window.location.href;
  const assetRoot = new URL('./', scriptUrl).href;
  const config = {
    assetBase: assetRoot,
    canvasKitBaseUrl: new URL('canvaskit/', assetRoot).href,
    entrypointBaseUrl: assetRoot,
  };

  // The standalone catalog owns an implicit view. Embedded previews share
  // one engine and attach their views explicitly through `app.addView`.
  // The host waits for this promise instead of starting another engine.
  //
  // The site bar instead owns its engine outright: several engine views can
  // no longer be trusted to keep their own sizes (every view converges onto
  // the latest one's), so the bar renders into an iframe viewport as the
  // implicit single view, which the host page sizes exactly. The iframe
  // requests this mode with `?view=bar`.
  const barView = new URLSearchParams(window.location.search).get('view') === 'bar';

  if (barView) {
    document.documentElement.style.background = 'transparent';
    document.body.style.margin = '0';
    document.body.style.background = 'transparent';
    document.body.style.overflow = 'hidden';
  }

  window.hyprbaricEmbedsReady = new Promise((resolve, reject) => {
    const fail = (error) => reject(
      error instanceof Error ? error : new Error(String(error)),
    );

    try {
      _flutter.loader.load({
        config,
        onEntrypointLoaded: async (engineInitializer) => {
          try {
            const runner = await engineInitializer.initializeEngine({
              ...config,
              // Single-view mode leaves the implicit view alone; the iframe
              // viewport sizes it.
              multiViewEnabled: !barView && !document.body.hasAttribute('data-hyprbaric-catalog'),
            });
            const app = await runner.runApp();
            window.hyprbaricEmbedsApp = app;
            resolve(app);
          } catch (error) {
            fail(error);
          }
        },
      });
    } catch (error) {
      // `load` throws synchronously when the build config is missing or the
      // browser cannot support the renderer at all.
      fail(error);
    }
  });

  // The host attaches its own handler. Without this a boot failure also
  // surfaces as an unhandled rejection in the page's console.
  window.hyprbaricEmbedsReady.catch(() => {});
})();
