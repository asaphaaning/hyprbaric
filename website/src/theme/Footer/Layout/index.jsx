import React from 'react';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import clsx from 'clsx';
import {ThemeClassNames} from '@docusaurus/theme-common';

export default function FooterLayout({style}) {
  const modulesPath = useBaseUrl('/#modules');

  return (
    <footer className={clsx(ThemeClassNames.layout.footer.container, 'hyprFooter', {'footer--dark': style === 'dark'})}>
      <div className="hyprFooterInner">
        <div><span>hyprbaric</span><i /><small>AGPL-3.0</small></div>
        <nav aria-label="Footer"><a href={modulesPath}>Modules</a><Link to="/docs/configuration">Configuration</Link><a href="https://github.com/asaphaaning/hyprbaric">GitHub</a></nav>
      </div>
    </footer>
  );
}
