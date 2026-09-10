import React from 'react';
import Link from '@docusaurus/Link';
import {useLocation} from '@docusaurus/router';
import useBaseUrl from '@docusaurus/useBaseUrl';
import SearchBar from '@theme/SearchBar';

import FullBar from '../../components/FullBar';

const items = [
  {label: 'Home', to: '/', active: (path, homePath) => path === homePath},
  {label: 'Documentation', to: '/docs/intro', active: (path) => path.includes('/docs/')},
];

export default function Navbar() {
  const location = useLocation();
  const logo = useBaseUrl('img/reference/logo.png');
  const homePath = useBaseUrl('/');

  return (
    <>
      <FullBar />
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
    </>
  );
}
