import React, {useState} from 'react';
import clsx from 'clsx';
import {useDocsSidebar} from '@docusaurus/plugin-content-docs/client';
import BackToTopButton from '@theme/BackToTopButton';
import DocRootLayoutMain from '@theme/DocRoot/Layout/Main';
import DocRootLayoutSidebar from '@theme/DocRoot/Layout/Sidebar';

export default function DocRootLayout({children}) {
  const sidebar = useDocsSidebar();
  const [hiddenSidebarContainer, setHiddenSidebarContainer] = useState(false);
  const [isNavigationOpen, setNavigationOpen] = useState(false);

  const closeAfterNavigation = (event) => {
    if (event.target.closest('a')) setNavigationOpen(false);
  };

  return (
    <div className="hyprDocsWrapper">
      <BackToTopButton />
      <div className="hyprDocRoot">
        {sidebar && (
          <>
            <button
              aria-controls="hypr-docs-navigation"
              aria-expanded={isNavigationOpen}
              className="hyprDocMobileNav"
              onClick={() => setNavigationOpen((isOpen) => !isOpen)}
              type="button">
              <span>Browse documentation</span>
              <span aria-hidden="true">{isNavigationOpen ? '−' : '+'}</span>
            </button>
            <div
              className={clsx('hyprDocSidebar', isNavigationOpen && 'hyprDocSidebarOpen')}
              id="hypr-docs-navigation"
              onClickCapture={closeAfterNavigation}>
              <DocRootLayoutSidebar
                sidebar={sidebar.items}
                hiddenSidebarContainer={hiddenSidebarContainer}
                setHiddenSidebarContainer={setHiddenSidebarContainer}
              />
              <div className="hyprDocMenuToc" id="hypr-doc-menu-toc" />
            </div>
          </>
        )}
        <DocRootLayoutMain hiddenSidebarContainer={hiddenSidebarContainer}>
          {children}
        </DocRootLayoutMain>
      </div>
    </div>
  );
}
