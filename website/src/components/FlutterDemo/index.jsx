import {useEffect, useLayoutEffect, useRef, useState} from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';

import {attachPreview, canReusePreview, detachPreview} from './previewEngine';

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

const SKELETONS = {
  mixer: MixerSkeleton,
  controls: ControlsSkeleton,
  network: NetworkSkeleton,
  power: PowerSkeleton,
  notifications: NotificationsSkeleton,
  workspaces: WorkspaceSkeleton,
};

/**
 * The preview names this page can render.
 *
 * Kept in step with `LandingPreview` in widgetbook/lib/stories/preview_registry.dart
 * by preview_registry_test.dart, which reads this file.
 */
export const PREVIEW_NAMES = Object.keys(SKELETONS);

/** Survives leaving the landing page so a return already knows the embed version. */
const versionCache = new Map();

function useFlutterPreviewVersion() {
  const versionUrl = useBaseUrl('flutter/previews/version.json');
  const [state, setState] = useState(
    () => versionCache.get(versionUrl) ?? {version: null, missing: false},
  );

  useEffect(() => {
    let cancelled = false;

    const refresh = async () => {
      try {
        const response = await fetch(`${versionUrl}?now=${Date.now()}`, {cache: 'no-store'});
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const next = await response.json();

        if (!cancelled) {
          const version = String(next.version);
          const resolved = {version, missing: false};
          versionCache.set(versionUrl, resolved);
          setState((current) => current.version === version && !current.missing
            ? current
            : resolved);
        }
      } catch (error) {
        // A rebuild replaces these files, so a miss is expected mid-build and
        // the current preview should stay up. A miss with nothing loaded yet
        // means the embed was never built, which the caller has to surface
        // rather than sit on a skeleton forever.
        if (cancelled) return;
        setState((current) => {
          if (current.version) return current;
          const missing = {version: null, missing: true};
          versionCache.set(versionUrl, missing);
          return missing;
        });
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

const VIEWPORT_MARGIN_PX = 200;

function isNearViewport(element) {
  const rect = element.getBoundingClientRect();
  return rect.bottom >= -VIEWPORT_MARGIN_PX
    && rect.top <= window.innerHeight + VIEWPORT_MARGIN_PX;
}

/** Defers work until the element is near the viewport. */
function useNearViewport(ref) {
  const [near, setNear] = useState(false);

  useEffect(() => {
    const element = ref.current;
    if (!element) return undefined;

    let observer;
    let finished = false;
    const stop = () => {
      if (finished) return;
      finished = true;
      observer?.disconnect();
      window.removeEventListener('scroll', mark);
      window.removeEventListener('resize', mark);
    };
    const mark = () => {
      if (!isNearViewport(element)) return;
      setNear(true);
      stop();
    };

    if (typeof IntersectionObserver !== 'function') {
      setNear(true);
      return undefined;
    }

    observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        setNear(true);
        stop();
      }
    }, {rootMargin: `${VIEWPORT_MARGIN_PX}px`});

    observer.observe(element);
    window.addEventListener('scroll', mark, {passive: true});
    window.addEventListener('resize', mark);
    mark();
    return stop;
  }, [ref]);

  return near;
}

export default function FlutterDemo({className = '', preview = 'mixer'}) {
  const bootstrapPath = useBaseUrl('flutter/previews/flutter_bootstrap.js');
  const {version, missing} = useFlutterPreviewVersion();
  const host = useRef(null);
  const near = useNearViewport(host);
  const bootstrapUrl = version ? `${bootstrapPath}?v=${version}` : '';
  const [status, setStatus] = useState(
    () => (bootstrapUrl && canReusePreview(preview, bootstrapUrl) ? 'ready' : 'pending'),
  );

  const Skeleton = SKELETONS[preview] ?? MixerSkeleton;

  useLayoutEffect(() => {
    if (!version || !near) return undefined;

    const element = host.current;
    if (!element) return undefined;

    let cancelled = false;
    const url = `${bootstrapPath}?v=${version}`;
    if (!canReusePreview(preview, url)) {
      setStatus('pending');
    }

    attachPreview({
      preview,
      parent: element,
      bootstrapUrl: url,
      onReady: (error) => {
        if (cancelled) return;
        if (error) {
          console.error(`[hyprbaric] ${error}: ${preview}`);
          setStatus('error');
          return;
        }
        setStatus('ready');
      },
      onError: (error) => {
        if (cancelled) return;
        console.error('[hyprbaric] Flutter preview engine failed to start.', error);
        setStatus('error');
      },
    }).catch(() => {});

    return () => {
      cancelled = true;
      detachPreview(preview);
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
