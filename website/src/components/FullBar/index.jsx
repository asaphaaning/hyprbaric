import {useEffect, useState} from 'react';
import {useHistory} from '@docusaurus/router';

import FlutterDemo from '../FlutterDemo';
import styles from './index.module.css';

/**
 * The production bar, pinned to the top of every page as living site chrome.
 *
 * The global menu carries documentation navigation, the centered title goes
 * home, and every other cluster keeps its catalog behaviour. The Flutter
 * canvas only needs popup room while the pointer is over the bar: collapsed
 * the shell is a plain strip that never swallows page clicks, expanded it
 * overlays the page like a real menu layer. Desktop only; smaller screens
 * keep the classic navbar and never pay for the engine.
 */
export default function FullBar() {
  const history = useHistory();
  const [expanded, setExpanded] = useState(false);
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

  useEffect(() => {
    if (!desktop) return undefined;

    window.hyprbaricNavigate = (url) => {
      try {
        const parsed = new URL(url, window.location.origin);
        if (parsed.origin === window.location.origin) {
          history.push(parsed.pathname + parsed.search + parsed.hash);
          return;
        }
      } catch {
        // Unparseable targets fall through to a full navigation below.
      }
      window.location.assign(url);
    };

    return () => {
      delete window.hyprbaricNavigate;
    };
  }, [desktop, history]);

  // The Flutter canvas only needs popup room while the pointer is over the
  // bar; collapsed it is a plain strip that never swallows page clicks.
  // Leave detection sits on the stage (which is tall while expanded) so
  // reaching into an open menu does not collapse it mid-gesture.
  if (!desktop) return null;

  return (
    <div
      className={styles.shell}
      onMouseEnter={() => setExpanded(true)}>
      <div
        className={expanded ? styles.stageExpanded : styles.stage}
        onMouseLeave={() => setExpanded(false)}>
        <FlutterDemo
          className={expanded ? styles.hostExpanded : styles.host}
          preview="bar"
        />
      </div>
    </div>
  );
}
