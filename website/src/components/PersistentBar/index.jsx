import React, {createContext, useCallback, useContext, useEffect, useState} from 'react';
import FullBar from '../FullBar';

const BarContext = createContext({visible: false, loading: false});

/** Desktop and large-tablet landscape. Smaller views keep the HTML header. */
const DESKTOP_BAR_QUERY = '(min-width: 1280px)';

/** How long the skeleton waits for first paint before restoring the HTML header. */
const LOAD_TIMEOUT_MS = 10000;

/** True when the persistent desktop bar replaces the route's normal header. */
export function usePersistentBar() {
  return useContext(BarContext);
}

/** Owns one iframe on wide viewports, outside route-specific layouts. */
export default function PersistentBar({children}) {
  const [desktop, setDesktop] = useState(false);
  const [status, setStatus] = useState('loading');
  const ready = useCallback(() => setStatus('ready'), []);
  const failed = useCallback(() => setStatus('failed'), []);

  useEffect(() => {
    const query = window.matchMedia(DESKTOP_BAR_QUERY);
    const sync = () => {
      setDesktop(query.matches);
      if (!query.matches) setStatus('loading');
    };
    sync();
    query.addEventListener('change', sync);
    return () => query.removeEventListener('change', sync);
  }, []);

  useEffect(() => {
    if (!desktop || status !== 'loading') return undefined;
    const timeout = window.setTimeout(failed, LOAD_TIMEOUT_MS);
    return () => window.clearTimeout(timeout);
  }, [desktop, status, failed]);

  const visible = desktop && status === 'ready';
  const loading = desktop && status === 'loading';
  return (
    <BarContext.Provider value={{visible, loading}}>
      {children}
      {desktop && status !== 'failed' && (
        <div style={{position: 'fixed', top: 0, left: 0, right: 0, zIndex: 60,
          pointerEvents: visible ? 'auto' : 'none'}}>
          <FullBar onReady={ready} onError={failed} />
        </div>
      )}
    </BarContext.Provider>
  );
}
