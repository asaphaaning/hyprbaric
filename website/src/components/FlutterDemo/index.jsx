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

function NetworkSkeleton() {
  return (
    <div aria-hidden="true" className={`${styles.skeleton} ${styles.networkSkeleton}`}>
      <span className={styles.networkScope} />
      <span className={styles.networkParameters} />
      <span className={styles.networkWifi} />
      <span className={styles.networkInterfaces} />
      <span className={styles.networkSettings} />
    </div>
  );
}

function PowerSkeleton() {
  return (
    <div aria-hidden="true" className={`${styles.skeleton} ${styles.powerSkeleton}`}>
      <span className={styles.powerMeter} />
      <span className={styles.powerReadouts} />
      <span className={styles.powerTelemetry} />
      <span className={styles.powerProfiles} />
    </div>
  );
}

function NotificationsSkeleton() {
  return (
    <div aria-hidden="true" className={`${styles.skeleton} ${styles.notificationsSkeleton}`}>
      <span className={styles.notificationsHeader} />
      <span className={styles.notificationRowOne} />
      <span className={styles.notificationRowTwo} />
      <span className={styles.notificationRowThree} />
    </div>
  );
}

function WorkspaceSkeleton() {
  return (
    <div aria-hidden="true" className={`${styles.skeleton} ${styles.workspaceSkeleton}`}>
      <span className={styles.workspacePrevious} />
      <span className={styles.workspaceIndicators} />
      <span className={styles.workspaceNext} />
    </div>
  );
}

function useFlutterPreviewVersion() {
  const versionUrl = useBaseUrl('flutter/previews/version.json');
  const [version, setVersion] = useState(null);

  useEffect(() => {
    let cancelled = false;

    const refresh = async () => {
      try {
        const response = await fetch(`${versionUrl}?now=${Date.now()}`, {cache: 'no-store'});
        const next = await response.json();

        if (!cancelled) setVersion(String(next.version));
      } catch {
        // Keep the current preview visible while a rebuild is replacing its files.
      }
    };

    refresh();
    const interval = process.env.NODE_ENV === 'development'
      ? window.setInterval(refresh, 1000)
      : undefined;

    return () => {
      cancelled = true;
      if (interval) window.clearInterval(interval);
    };
  }, [versionUrl]);

  return version;
}

export default function FlutterDemo({className = '', preview = 'mixer'}) {
  const shell = useBaseUrl('flutter-preview/');
  const version = useFlutterPreviewVersion();
  const source = version ? `${shell}?preview=${preview}&version=${version}` : null;
  const frame = useRef(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!source) return undefined;

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
      {!ready && (
        preview === 'network' ? <NetworkSkeleton /> : preview === 'controls' ? <ControlsSkeleton /> : preview === 'power' ? <PowerSkeleton /> : preview === 'notifications' ? <NotificationsSkeleton /> : preview === 'workspaces' ? <WorkspaceSkeleton /> : <MixerSkeleton />
      )}
      {source && (
        <iframe
          aria-label={`${preview} module preview`}
          className={ready ? styles.hostReady : styles.host}
          loading="lazy"
          onError={() => setReady(false)}
          ref={frame}
          src={source}
          title={`${preview} module preview`}
        />
      )}
    </div>
  );
}
