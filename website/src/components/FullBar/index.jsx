import {useEffect, useRef, useState} from 'react';
import {useHistory, useLocation} from '@docusaurus/router';
import useBaseUrl from '@docusaurus/useBaseUrl';

import styles from './index.module.css';

/** The experiment's isolated Flutter bar, clipped to its actual input regions. */
export default function FullBar({onReady, onError}) {
  const history = useHistory();
  const {pathname} = useLocation();
  const siteRoot = useBaseUrl('/');
  const barPage = useBaseUrl('flutter/bar/index.html');
  const versionUrl = useBaseUrl('flutter/bar/version.json');
  const frame = useRef(null);
  const [version, setVersion] = useState(null);
  const [ready, setReady] = useState(false);
  const [frost, setFrost] = useState(null);
  const [hint, setHint] = useState(null);

  useEffect(() => { setHint(null); }, [pathname]);

  useEffect(() => {
    let cancelled = false;
    fetch(versionUrl, {cache: 'no-store'})
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return response.json();
      })
      .then((data) => {
        if (!cancelled) setVersion(String(data.version));
      })
      .catch((error) => {
        console.warn('[hyprbaric] Website bar unavailable.', error);
        if (!cancelled) onError();
      });
    return () => { cancelled = true; };
  }, [versionUrl, onError]);

  useEffect(() => {
    const receive = (event) => {
      if (event.origin !== window.location.origin || event.source !== frame.current?.contentWindow) return;
      const data = event.data;
      if (!data || typeof data !== 'object') return;
      if (data.source === 'hyprbaric-bar-ready') {
        setReady(true);
        onReady();
      } else if (data.source === 'hyprbaric-module-hint') {
        const hint = data.hint;
        setHint(hint && typeof hint.title === 'string' && typeof hint.description === 'string'
          && Number.isFinite(hint.x) && Number.isFinite(hint.bottom) ? hint : null);
      } else if (data.source === 'hyprbaric-bar-frost') {
        setFrost(validFrost(data.rect) ? data.rect : null);
      } else if (data.source === 'hyprbaric-bar' && typeof data.url === 'string') {
        try {
          const target = new URL(data.url, window.location.origin);
          if (target.origin === window.location.origin && target.pathname.startsWith(siteRoot)) {
            history.push(target.pathname + target.search + target.hash);
            scrollToAnchor(target.hash);
          } else if (target.origin === 'https://github.com' && (target.pathname === '/asaphaaning/hyprbaric' || target.pathname.startsWith('/asaphaaning/hyprbaric/'))) {
            window.location.assign(target.href);
          }
        } catch (error) {
          console.warn('[hyprbaric] Invalid website bar destination.', error);
        }
      }
    };
    const search = (event) => {
      if (event.key === 'Escape') setHint(null);
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        history.push(`${siteRoot}search`);
      }
    };
    window.addEventListener('message', receive);
    window.addEventListener('keydown', search);
    return () => {
      window.removeEventListener('message', receive);
      window.removeEventListener('keydown', search);
    };
  }, [history, siteRoot, onReady]);

  useEffect(() => {
    if (!ready || pathname.replace(/\/$/, '') !== siteRoot.replace(/\/$/, '')) return;
    const anchors = ['hero', 'install', 'modules', 'desktop', 'config'];
    let pending = 0;
    let previous = null;
    const update = () => {
      pending = 0;
      let active = anchors[0];
      for (const anchor of anchors) {
        const section = document.getElementById(anchor);
        if (section && section.getBoundingClientRect().top <= 81) active = anchor;
      }
      // The final section may be too short to reach the header.
      if (window.scrollY > 0 && window.scrollY + window.innerHeight >= document.documentElement.scrollHeight - 2) {
        active = anchors[anchors.length - 1];
      }
      if (active !== previous) {
        frame.current?.contentWindow?.postMessage(
          {source: 'hyprbaric-section', anchor: active}, window.location.origin);
        previous = active;
      }
    };
    const schedule = () => { if (!pending) pending = requestAnimationFrame(update); };
    const observer = new ResizeObserver(schedule);
    observer.observe(document.body);
    window.addEventListener('scroll', schedule, {passive: true});
    window.addEventListener('resize', schedule);
    window.addEventListener('hashchange', schedule);
    schedule();
    return () => {
      cancelAnimationFrame(pending);
      observer.disconnect();
      window.removeEventListener('scroll', schedule);
      window.removeEventListener('resize', schedule);
      window.removeEventListener('hashchange', schedule);
    };
  }, [ready, pathname, siteRoot]);

  // An open popup owns a dismissal backdrop. Closed, only the bar accepts input.
  const clipPath = frost ? 'none' : 'inset(10px 10px calc(100% - 54px) 10px round 16px)';

  return (
    <div className={styles.shell}>
      <div aria-hidden="true" className={styles.strip} />
      {!ready && <BarSkeleton />}
      {frost && <div aria-hidden="true" className={styles.frost} style={{left: frost.x, top: frost.y, width: frost.w, height: frost.h, borderRadius: frost.r.map((radius) => `${radius}px`).join(' ')}} />}
      {version && <iframe
        ref={frame}
        title="Hyprbaric website navigation"
        src={`${barPage}?view=bar&base=${encodeURIComponent(siteRoot)}&v=${encodeURIComponent(version)}`}
        className={ready ? styles.frameReady : styles.frame}
        style={{clipPath}}
        aria-hidden={!ready}
        onError={onError}
      />}
      {hint && <div role="tooltip" className={styles.moduleHint}
        style={{left: `clamp(12px, ${hint.x - 150}px, calc(100% - 312px))`, top: hint.bottom + 12}}>
        <strong>{hint.title}</strong>
        <p>{hint.description}</p>
        <span>Explore the modules</span>
      </div>}
    </div>
  );
}

function BarSkeleton() {
  return (
    <div className={styles.skeleton} role="status" aria-label="Loading the hyprbaric bar">
      <span className={styles.nav} />
      <span className={styles.nav} />
      <span className={styles.workspace} />
      <span className={styles.workspace} />
      <span className={styles.workspace} />
      <span className={styles.workspace} />
      <span className={styles.workspace} />
      <span className={styles.menu} />
      <span className={styles.menu} />
      <span className={styles.menu} />
      <span className={styles.grow} />
      <span className={styles.title} />
      <span className={styles.search} />
      <span className={styles.grow} />
      <span className={styles.module} />
      <span className={styles.module} />
      <span className={styles.module} />
      <span className={styles.module} />
      <span className={styles.module} />
      <span className={styles.clock} />
    </div>
  );
}

function scrollToAnchor(hash) {
  if (!hash || hash.length < 2) return;
  const id = hash.slice(1);
  const jump = () => {
    const section = document.getElementById(id);
    if (!section) return false;
    section.scrollIntoView({block: 'start'});
    return true;
  };
  if (jump()) return;
  requestAnimationFrame(() => {
    if (!jump()) window.setTimeout(jump, 80);
  });
}

function validFrost(rect) {
  return !!rect && [rect.x, rect.y, rect.w, rect.h].every(Number.isFinite)
    && rect.x >= 0 && rect.y >= 0 && rect.w > 0 && rect.h > 0
    && Array.isArray(rect.r) && rect.r.length === 4
    && rect.r.every((radius) => Number.isFinite(radius) && radius >= 0);
}
