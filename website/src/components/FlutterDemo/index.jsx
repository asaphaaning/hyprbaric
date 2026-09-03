import {useEffect, useRef, useState} from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';

import {loadPreviewEngine} from './previewEngine';

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

const SKELETONS = {
  mixer: MixerSkeleton,
  controls: ControlsSkeleton,
  network: NetworkSkeleton,
  power: PowerSkeleton,
  notifications: NotificationsSkeleton,
};

/**
 * The preview names this page can render.
 *
 * Kept in step with `LandingPreview` in widgetbook/lib/stories/preview_registry.dart
 * by preview_registry_test.dart, which reads this file.
 */
export const PREVIEW_NAMES = Object.keys(SKELETONS);

function useFlutterPreviewVersion() {
  const versionUrl = useBaseUrl('flutter/previews/version.json');
  const [state, setState] = useState({version: null, missing: false});

  useEffect(() => {
    let cancelled = false;

    const refresh = async () => {
      try {
        const response = await fetch(`${versionUrl}?now=${Date.now()}`, {cache: 'no-store'});
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const next = await response.json();

        if (!cancelled) setState({version: String(next.version), missing: false});
      } catch (error) {
        // A rebuild replaces these files, so a miss is expected mid-build and
        // the current preview should stay up. A miss with nothing loaded yet
        // means the embed was never built, which the caller has to surface
        // rather than sit on a skeleton forever.
        if (cancelled) return;
        setState((current) => current.version
          ? current
          : {version: null, missing: true});
        console.warn(`[hyprbaric] Flutter previews unavailable at ${versionUrl}.`, error);
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

  return state;
}

/** Defers work until the element is near the viewport. */
function useNearViewport(ref) {
  const [near, setNear] = useState(false);

  useEffect(() => {
    const element = ref.current;
    if (!element) return undefined;
    if (typeof IntersectionObserver !== 'function') {
      setNear(true);
      return undefined;
    }

    const observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        setNear(true);
        observer.disconnect();
      }
    }, {rootMargin: '200px'});

    observer.observe(element);
    return () => observer.disconnect();
  }, [ref]);

  return near;
}

export default function FlutterDemo({className = '', preview = 'mixer'}) {
  const bootstrapPath = useBaseUrl('flutter/previews/flutter_bootstrap.js');
  const {version, missing} = useFlutterPreviewVersion();
  const host = useRef(null);
  const near = useNearViewport(host);
  const [status, setStatus] = useState('pending');

  const Skeleton = SKELETONS[preview] ?? MixerSkeleton;

  useEffect(() => {
    if (!version || !near) return undefined;

    const element = host.current;
    if (!element) return undefined;

    let cancelled = false;
    let attached = null;
    let engine = null;

    setStatus('pending');

    loadPreviewEngine(`${bootstrapPath}?v=${version}`)
      .then((app) => {
        if (cancelled) return;
        engine = app;
        attached = app.addView({
          hostElement: element,
          initialData: {
            preview,
            onReady: (error) => {
              if (cancelled) return;
              if (error) {
                console.error(`[hyprbaric] ${error}: ${preview}`);
                setStatus('error');
                return;
              }
              setStatus('ready');
            },
          },
        });
      })
      .catch((error) => {
        if (cancelled) return;
        console.error('[hyprbaric] Flutter preview engine failed to start.', error);
        setStatus('error');
      });

    return () => {
      cancelled = true;
      // Views outlive the React tree unless they are handed back, which leaks
      // a rendering surface per navigation on a client-routed site.
      if (engine && attached !== null) engine.removeView(attached);
    };
  }, [bootstrapPath, version, near, preview]);

  const failed = status === 'error' || missing;

  return (
    <div className={`${styles.frame} ${className}`}>
      {status !== 'ready' && !failed && <Skeleton />}
      {failed && (
        <div className={styles.unavailable} role="status">
          <p className={styles.unavailableTitle}>Preview unavailable</p>
          <p className={styles.unavailableBody}>
            The {preview} preview could not be loaded. Run
            {' '}<code>npm run build:flutter-embed</code>{' '}
            in <code>website/</code> to build it.
          </p>
        </div>
      )}
      <div
        aria-label={`${preview} module preview`}
        className={status === 'ready' ? styles.hostReady : styles.host}
        ref={host}
        role="img"
      />
    </div>
  );
}
