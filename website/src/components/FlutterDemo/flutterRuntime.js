let runtime;

export function loadFlutterRuntime(source) {
  if (runtime) return runtime;

  runtime = new Promise((resolve, reject) => {
    const existing = document.querySelector(`script[data-hyprbaric-embeds="${source}"]`);
    const script = existing ?? document.createElement('script');

    const ready = () => {
      if (!window.hyprbaricEmbedsReady) {
        reject(new Error('Flutter preview runtime did not initialize.'));
        return;
      }
      window.hyprbaricEmbedsReady.then(resolve, reject);
    };

    if (existing) {
      ready();
      return;
    }

    script.async = true;
    script.dataset.hyprbaricEmbeds = source;
    script.src = source;
    script.addEventListener('load', ready, {once: true});
    script.addEventListener('error', () => reject(new Error('Unable to load Flutter preview runtime.')), {once: true});
    document.head.append(script);
  });

  return runtime;
}
