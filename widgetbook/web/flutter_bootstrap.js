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

  window.hyprbaricEmbedsReady = new Promise((resolve, reject) => {
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
          reject(error);
        }
      },
    });
  });
})();
