import {useEffect, useRef, useState} from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';

import {loadFlutterRuntime} from './flutterRuntime';
import styles from './index.module.css';

function MixerSkeleton() {
  return (
    <div aria-hidden="true" className={styles.skeleton}>
      <span className={styles.skeletonHeader} />
      <span className={styles.skeletonDevice} />
      <span className={styles.skeletonDeck} />
      <span className={styles.skeletonDial} />
      <span className={`${styles.skeletonRail} ${styles.skeletonRailLeft}`} />
      <span className={`${styles.skeletonRail} ${styles.skeletonRailRight}`} />
      <span className={styles.skeletonMaster} />
    </div>
  );
}

export default function FlutterDemo({className = ''}) {
  const source = useBaseUrl('flutter/mixer/flutter_bootstrap.js');
  const host = useRef(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const element = host.current;
    if (!element) return undefined;

    let cancelled = false;
    let viewId;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) return;
        observer.disconnect();
        loadFlutterRuntime(source)
          .then((app) => {
            if (cancelled) return;
            viewId = app.addView({hostElement: element});
            requestAnimationFrame(() => setReady(true));
          })
          .catch(() => setReady(false));
      },
      {rootMargin: '300px'},
    );
    observer.observe(element);

    return () => {
      cancelled = true;
      observer.disconnect();
      if (viewId !== undefined && window.hyprbaricMixerApp) {
        window.hyprbaricMixerApp.removeView(viewId);
      }
    };
  }, [source]);

  return (
    <div className={`${styles.frame} ${className}`}>
      {!ready && <MixerSkeleton />}
      <div className={ready ? styles.hostReady : styles.host} ref={host} />
    </div>
  );
}
