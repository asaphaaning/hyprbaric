// @ts-check

const config = {
  title: 'hyprbaric',
  tagline: 'A status bar for Hyprland',
  favicon: 'img/logo.png',

  url: 'https://asaphaaning.github.io',
  baseUrl: '/hyprbaric/',
  organizationName: 'asaphaaning',
  projectName: 'hyprbaric',
  trailingSlash: false,

  onBrokenLinks: 'throw',
  markdown: {
    hooks: {
      onBrokenMarkdownLinks: 'warn',
    },
  },

  i18n: {
    defaultLocale: 'en',
    locales: ['en'],
  },

  presets: [
    [
      'classic',
      {
        docs: {
          sidebarPath: require.resolve('./sidebars.js'),
          routeBasePath: 'docs',
        },
        blog: false,
        theme: {
          customCss: require.resolve('./src/css/custom.css'),
        },
      },
    ],
  ],

  themes: [
    [
      require.resolve('@easyops-cn/docusaurus-search-local'),
      {
        hashed: true,
        indexDocs: true,
        indexPages: true,
        highlightSearchTermsOnTargetPage: true,
        searchBarShortcut: true,
        searchBarShortcutHint: true,
        searchBarShortcutKeymap: 'mod+k',
        // The reference design shows the full path under every top level hit.
        explicitSearchResultPath: true,
      },
    ],
  ],

  themeConfig: {
    image: 'img/hyprbaric.png',
    navbar: {
      title: 'hyprbaric',
      logo: {
        alt: 'hyprbaric logo',
        src: 'img/logo.png',
      },
      items: [
        {
          type: 'search',
          position: 'right',
        },
        {
          to: '/',
          label: 'Modules',
          position: 'right',
        },
        {
          to: '/docs/configuration',
          label: 'Config',
          position: 'right',
        },
        {
          href: 'https://github.com/asaphaaning/hyprbaric',
          label: 'GitHub',
          position: 'right',
        },
      ],
    },
    footer: {
      style: 'dark',
      logo: {
        alt: 'hyprbaric',
        src: 'img/logo.png',
        href: '/',
      },
      links: [
        {
          title: 'Documentation',
          items: [
            {
              label: 'Get started',
              to: '/docs/intro',
            },
            {
              label: 'Configuration',
              to: '/docs/configuration',
            },
            {
              label: 'Shortcuts',
              to: '/docs/shortcuts',
            },
          ],
        },
        {
          title: 'Project',
          items: [
            {
              label: 'GitHub',
              href: 'https://github.com/asaphaaning/hyprbaric',
            },
            {
              label: 'Issues',
              href: 'https://github.com/asaphaaning/hyprbaric/issues',
            },
          ],
        },
        {
          title: 'Community',
          items: [
            {
              label: 'Discussions',
              href: 'https://github.com/asaphaaning/hyprbaric/discussions',
            },
          ],
        },
      ],
      copyright: `Copyright © ${new Date().getFullYear()} hyprbaric contributors.`,
    },
    prism: {
      additionalLanguages: ['toml', 'bash'],
    },
  },
};

module.exports = config;
