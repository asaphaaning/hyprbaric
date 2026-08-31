let runtime;

export function loadFlutterRuntime(source) {
  if (runtime) return runtime;

  runtime = new Promise((resolve, reject) => {
    const existing = document.querySelector(`script[data-hyprbaric-mixer="${source}"]`);
    const script = existing ?? document.createElement('script');

    const ready = () => {
      if (!window.hyprbaricMixerReady) {
        reject(new Error('Flutter mixer runtime did not initialize.'));
        return;
      }
      window.hyprbaricMixerReady.then(resolve, reject);
    };

    if (existing) {
      ready();
      return;
    }

    script.async = true;
    script.dataset.hyprbaricMixer = source;
    script.src = source;
    script.addEventListener('load', ready, {once: true});
    script.addEventListener('error', () => reject(new Error('Unable to load Flutter mixer runtime.')), {once: true});
    document.head.append(script);
  });

  return runtime;
}
