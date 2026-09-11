import React, {useCallback, useEffect, useState} from 'react';
import Link from '@docusaurus/Link';
import {useLocation} from '@docusaurus/router';
import useBaseUrl from '@docusaurus/useBaseUrl';
import SearchBar from '@theme/SearchBar';

import FullBar from '../../components/FullBar';

const items = [
  {label: 'Home', to: '/', active: (path, homePath) => path === homePath},
  {label: 'Documentation', to: '/docs/intro', active: (path) => path.includes('/docs/')},
];

/**
 * How long the live bar gets to paint before the classic header takes over.
 *
 * Generous cold-boot budget for the engine; once the fallback is in, it stays
 * for the session rather than swapping chrome mid-visit.
 */
const BAR_READY_TIMEOUT_MS = 5000;

function useDesktopBar() {
  // Server and first paint assume the bar: desktop is the primary audience
  // and hydrates without a flicker. Small screens remount onto the classic
  // header once (a dev-only hydration warning that self-heals).
  const [desktop, setDesktop] = useState(
    () => typeof window === 'undefined' || window.matchMedia('(min-width: 997px)').matches,
  );

  useEffect(() => {
    const query = window.matchMedia('(min-width: 997px)');
    const sync = () => setDesktop(query.matches);
    sync();
    query.addEventListener('change', sync);
    return () => query.removeEventListener('change', sync);
  }, []);

  return desktop;
}

function ClassicHeader() {
  const location = useLocation();
  const logo = useBaseUrl('img/reference/logo.png');
  const homePath = useBaseUrl('/');

  return (
    <header className="navbar hyprNavbar" data-glass="true">
      <div className="hyprNavbarInner">
        <Link className="hyprNavbarBrand" to="/">
          <span className="hyprNavbarLogo"><img src={logo} alt="" /></span>
          <span>hyprbaric</span>
        </Link>
        <nav aria-label="Primary" className="hyprNavbarNav">
          {items.map((item) => (
            <Link
              className={item.active(location.pathname, homePath) ? 'hyprNavbarTab hyprNavbarTabActive' : 'hyprNavbarTab'}
              key={item.label}
              to={item.to}>
              {item.label}
            </Link>
          ))}
        </nav>
        <div className="hyprNavbarSearch"><SearchBar /></div>
        <a className="hyprGithubButton" href="https://github.com/asaphaaning/hyprbaric">GitHub</a>
      </div>
    </header>
  );
}

export default function Navbar() {
  const desktop = useDesktopBar();
  const [barReady, setBarReady] = useState(false);
  const [fallback, setFallback] = useState(false);
  const handleBarReady = useCallback(() => setBarReady(true), []);

  useEffect(() => {
    if (!desktop || barReady || fallback) return undefined;
    const timer = window.setTimeout(() => setFallback(true), BAR_READY_TIMEOUT_MS);
    return () => window.clearTimeout(timer);
  }, [desktop, barReady, fallback]);

  // Every sticky offset keys off --hypr-bar-height; without the live bar it
  // must collapse so the classic header docks at the top.
  console.log('[navdbg] render', {desktop, barReady, fallback});
  useEffect(() => {
    console.log('[navdbg] class effect', {desktop, fallback});
    document.documentElement.classList.toggle('hypr-no-live-bar', !desktop || fallback);
    return () => {
      console.log('[navdbg] class cleanup');
      document.documentElement.classList.remove('hypr-no-live-bar');
    };
  }, [desktop, fallback]);

  if (!desktop || fallback) return <ClassicHeader />;
  return <FullBar onReady={handleBarReady} />;
}
