import {useEffect, useRef, useState} from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';

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
  const source = `${useBaseUrl('flutter-preview/')}?preview=${preview}`;
  const frame = useRef(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const element = frame.current;
    if (!element) return undefined;

    setReady(false);

    const receiveStatus = (event) => {
      if (event.origin !== window.location.origin || event.source !== element.contentWindow) return;
      if (event.data?.type !== 'hyprbaric-preview-ready') return;

      setReady(true);
    };

    window.addEventListener('message', receiveStatus);

    return () => {
      window.removeEventListener('message', receiveStatus);
    };
  }, [source]);

  return (
    <div className={`${styles.frame} ${className}`}>
      {!ready && (preview === 'controls' ? <ControlsSkeleton /> : <MixerSkeleton />)}
      <iframe
        aria-label={`${preview} module preview`}
        className={ready ? styles.hostReady : styles.host}
        loading="lazy"
        onError={() => setReady(false)}
        ref={frame}
        src={source}
        title={`${preview} module preview`}
      />
    </div>
  );
}
