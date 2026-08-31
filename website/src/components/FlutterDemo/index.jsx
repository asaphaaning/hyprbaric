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

function ControlsSkeleton() {
  return (
    <div aria-hidden="true" className={`${styles.skeleton} ${styles.controlsSkeleton}`}>
      <span className={styles.controlsCapture} />
      <span className={styles.controlsInspect} />
      <span className={styles.controlsToggles} />
      <span className={styles.controlsSettings} />
    </div>
  );
}

export default function FlutterDemo({className = '', preview = 'mixer'}) {
  const source = useBaseUrl('flutter/previews/flutter_bootstrap.js');
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
            viewId = app.addView({hostElement: element, initialData: {preview}});
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
      if (viewId !== undefined && window.hyprbaricEmbedsApp) {
        window.hyprbaricEmbedsApp.removeView(viewId);
      }
    };
  }, [preview, source]);

  return (
    <div className={`${styles.frame} ${className}`}>
      {!ready && (preview === 'controls' ? <ControlsSkeleton /> : <MixerSkeleton />)}
      <div className={ready ? styles.hostReady : styles.host} ref={host} />
    </div>
  );
}
