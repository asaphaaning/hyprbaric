import Link from '@docusaurus/Link';

import styles from './index.module.css';

const icons = {
  download: <path d="M12 3v12m-4-4 4 4 4-4M5 16v4h14v-4" />,
  modules: <path d="M4 4h6v6H4zm10 0h6v6h-6zM4 14h6v6H4zm10 0h6v6h-6z" />,
  guide: <path d="M12 6c-3-2-6-2-9-1v14c3-1 6-1 9 1m0-14c3-2 6-2 9-1v14c-3-1-6-1-9 1V6" />,
  settings: <path d="M5 3v18M12 3v18M19 3v18M2 8h6m1 8h6m1-9h6" />,
};

/** Web navigation counterpart of HyprPlateButton's gasket, face, and icon well. */
export default function PlateLink({to, icon, children, primary = false}) {
  return (
    <Link
      to={to}
      className={`${styles.plate} ${primary ? styles.primary : ''}`}
      data-plate=""
      onClick={(event) => {
        if (typeof to === 'string' && to.startsWith('#')) {
          event.currentTarget.blur();
        }
      }}>
      <span className={styles.face}>
        <span className={styles.icon} aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">{icons[icon]}</svg>
        </span>
        <span className={styles.label}>{children}</span>
        <span className={styles.chevron} aria-hidden="true">›</span>
      </span>
    </Link>
  );
}
