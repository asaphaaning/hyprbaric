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
              multiViewEnabled: !document.body.hasAttribute('data-hyprbaric-catalog'),
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
