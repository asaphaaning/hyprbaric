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

  // One engine hosts every preview on the page. Each preview is a view added
  // through `app.addView`, so this promise is resolved exactly once and the
  // host waits on it rather than booting an engine of its own.
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
              multiViewEnabled: true,
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
