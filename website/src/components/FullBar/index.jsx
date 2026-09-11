import {useEffect, useState} from 'react';
import {useHistory} from '@docusaurus/router';
import useBaseUrl from '@docusaurus/useBaseUrl';

import styles from './index.module.css';

function BarSkeleton() {
  return (
    <div aria-hidden="true" className={styles.skeleton}>
      <span className={styles.band} />
      <span className={styles.menu} />
      <span className={styles.title} />
      <span className={styles.cluster} />
    </div>
  );
}

/**
 * The production bar, pinned to the top of every page as living site chrome.
 *
 * The bar owns its single-view engine inside an iframe: several engine views
 * no longer keep their own sizes once they share one engine (every view
 * converges onto the latest one's), while the iframe viewport sizes a lone
 * view exactly. The global menu carries documentation navigation, the
 * centered title goes home, and every other cluster keeps its catalog
 * behaviour. Menu activations arrive as postMessage events and route
 * client-side.
 *
 * The navbar mounts this only where it belongs (desktop widths); it reports
 * first paint through `onReady` so the navbar can retire its fallback. Until
 * then a skeleton holds the strip.
 */
export default function FullBar({onReady}) {
  const history = useHistory();
  const siteRoot = useBaseUrl('/');
  const barPage = useBaseUrl('flutter/bar/index.html');
  const versionUrl = useBaseUrl('flutter/bar/version.json');
  const [expanded, setExpanded] = useState(false);
  const [version, setVersion] = useState(null);
  const [ready, setReady] = useState(false);
  const [frost, setFrost] = useState(null);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      try {
        const response = await fetch(`${versionUrl}?now=${Date.now()}`, {cache: 'no-store'});
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const next = await response.json();
        if (!cancelled) setVersion(String(next.version));
      } catch (error) {
        if (!cancelled) console.warn(`[hyprbaric] Bar preview unavailable at ${versionUrl}.`, error);
      }
    };

    load();
    const interval = process.env.NODE_ENV === 'development'
      ? window.setInterval(load, 2000)
      : undefined;

    return () => {
      cancelled = true;
      if (interval) window.clearInterval(interval);
    };
  }, [versionUrl]);

  useEffect(() => {
    const onMessage = (event) => {
      if (event.origin !== window.location.origin) return;
      const data = event.data;
      if (!data || typeof data !== 'object') return;

      if (data.source === 'hyprbaric-bar-ready') {
        onReady?.();
        return;
      }

      if (data.source === 'hyprbaric-bar-frost') {
        setFrost(validFrost(data.rect) ? data.rect : null);
        return;
      }

      if (data.source !== 'hyprbaric-bar' || typeof data.url !== 'string') return;

      try {
        const parsed = new URL(data.url, window.location.origin);
        if (parsed.origin === window.location.origin) {
          history.push(parsed.pathname + parsed.search + parsed.hash);
          return;
        }
      } catch {
        // Unparseable targets fall through to a full navigation below.
      }
      window.location.assign(data.url);
    };

    window.addEventListener('message', onMessage);
    return () => window.removeEventListener('message', onMessage);
  }, [history, onReady]);

  const src = version
    ? `${barPage}?view=bar&base=${encodeURIComponent(siteRoot)}&v=${version}`
    : null;

  // The Flutter canvas only needs popup room while the pointer is over the
  // bar; collapsed the shell is a plain strip that never swallows page
  // clicks. Leave detection sits on the stage (which is tall while
  // expanded) so reaching into an open menu does not collapse it
  // mid-gesture. Frost lives on plain siblings under the canvas: backdrop
  // filters must not nest, or the inner one silently stops filtering.
  return (
    <div
      className={styles.shell}
      onMouseEnter={() => setExpanded(true)}>
      <div aria-hidden="true" className={styles.strip} />
      {frost && expanded && (
        <div
          aria-hidden="true"
          className={styles.frost}
          style={{
            left: frost.x,
            top: frost.y,
            width: frost.w,
            height: frost.h,
            borderRadius: frost.r.map((corner) => `${corner}px`).join(' '),
          }}
        />
      )}
      <div
        className={expanded ? styles.stageExpanded : styles.stage}
        onMouseLeave={() => setExpanded(false)}>
        <BarSkeleton />
        {src && (
          <iframe
            key={version}
            title="hyprbaric status bar"
            src={src}
            className={ready ? `${styles.frame} ${styles.frameReady}` : styles.frame}
            onLoad={() => setReady(true)}
          />
        )}
      </div>
    </div>
  );
}

function validFrost(rect) {
  return !!rect
    && Number.isFinite(rect.x)
    && Number.isFinite(rect.y)
    && Number.isFinite(rect.w)
    && Number.isFinite(rect.h)
    && rect.w > 0
    && rect.h > 0
    && Array.isArray(rect.r)
    && rect.r.length === 4
    && rect.r.every(Number.isFinite);
}
