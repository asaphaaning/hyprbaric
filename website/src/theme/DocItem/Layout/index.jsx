import React, {useEffect, useState} from 'react';
import clsx from 'clsx';
import {createPortal} from 'react-dom';
import {useWindowSize} from '@docusaurus/theme-common';
import {useDoc} from '@docusaurus/plugin-content-docs/client';
import ContentVisibility from '@theme/ContentVisibility';
import DocItemContent from '@theme/DocItem/Content';
import DocItemPaginator from '@theme/DocItem/Paginator';
import DocItemTOCDesktop from '@theme/DocItem/TOC/Desktop';
import DocItemTOCMobile from '@theme/DocItem/TOC/Mobile';
import DocVersionBanner from '@theme/DocVersionBanner';

function MobileTableOfContents({visible}) {
  const [target, setTarget] = useState();

  useEffect(() => setTarget(document.getElementById('hypr-doc-menu-toc')), []);

  if (!visible || !target) return null;

  return createPortal(<DocItemTOCMobile />, target);
}

function useDocTOC() {
  const {frontMatter, toc} = useDoc();
  const windowSize = useWindowSize();
  const hidden = frontMatter.hide_table_of_contents;
  const canRender = !hidden && toc.length > 0;

  return {
    canRender,
    hidden,
    desktop: canRender && (windowSize === 'desktop' || windowSize === 'ssr') ? <DocItemTOCDesktop /> : undefined,
  };
}

export default function DocItemLayout({children}) {
  const docTOC = useDocTOC();
  const {metadata} = useDoc();

  return (
    <div className="hyprDocLayout">
      <div className={clsx('hyprDocArticleColumn', !docTOC.hidden && 'hyprDocArticleColumnWithToc')}>
        <ContentVisibility metadata={metadata} />
        <DocVersionBanner />
        <MobileTableOfContents visible={docTOC.canRender} />
        <article className="hyprDocArticle">
          <DocItemContent>{children}</DocItemContent>
        </article>
        <DocItemPaginator />
      </div>
      {docTOC.desktop && <aside className="hyprDocToc">{docTOC.desktop}</aside>}
    </div>
  );
}
