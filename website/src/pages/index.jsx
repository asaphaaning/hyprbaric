import {useEffect, useState} from 'react';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import Layout from '@theme/Layout';
import CodeBlock from '@theme/CodeBlock';

import FlutterDemo from '../components/FlutterDemo';
import PlateLink from '../components/PlateLink';
import styles from './index.module.css';

const installOptions = [
  {
    name: 'Automatic',
    tool: 'Recommended',
    label: 'Linux · auto-detect',
    detail: 'Detects your distribution and installs its verified release package.',
    command: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh",
  },
  {
    name: 'Debian / Ubuntu',
    tool: 'DEB package',
    label: 'Debian · Ubuntu',
    detail: 'Downloads the latest DEB and installs its runtime dependencies with apt.',
    command: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh",
  },
  {
    name: 'Arch / Manjaro',
    tool: 'Pacman package',
    label: 'Arch · Manjaro',
    detail: 'Downloads the latest Pacman package and installs it with pacman.',
    command: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh",
  },
  {
    name: 'Fedora / openSUSE',
    tool: 'RPM package',
    label: 'Fedora · openSUSE',
    detail: 'Downloads the latest RPM and installs it with dnf or zypper.',
    command: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh",
  },
  {
    name: 'Other Linux',
    tool: 'AppImage',
    label: 'Linux · AppImage',
    detail: 'Uses the self-contained AppImage when no native package matches.',
    command: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh",
  },
];

const modules = [
  {
    label: 'Network',
    title: 'Traffic and Wi-Fi',
    text: 'A glowing minute of download and upload history, plus Wi-Fi and connection details. Explore the simulated traffic below.',
  },
  {
    label: 'Volume',
    title: 'Volume and brightness',
    text: 'Output and input levels with live meters, and backlight or DDC brightness.',
    image: 'img/reference/pop-audio-cut.png',
  },
  {
    label: 'Controls',
    title: 'Capture and toggles',
    text: 'Region, window, and full-screen capture, recording, colour picking, night light, DND, and caffeine.',
    image: 'img/reference/pop-controls-cut.png',
  },
  {
    label: 'Power',
    title: 'Battery and power profiles',
    text: 'Charge level and time remaining, and the active power profile.',
  },
];

function InstallCommand() {
  const [selected, setSelected] = useState(installOptions[0]);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const close = () => setOpen(false);
    const closeWithEscape = (event) => {
      if (event.key === 'Escape') setOpen(false);
    };
    document.addEventListener('click', close);
    document.addEventListener('keydown', closeWithEscape);
    return () => {
      document.removeEventListener('click', close);
      document.removeEventListener('keydown', closeWithEscape);
    };
  }, []);

  return (
    <div className={styles.installPicker} onClick={(event) => event.stopPropagation()}>
      <CodePanel language="bash" title="Install Hyprbaric" controls={(
        <button
          aria-expanded={open}
          className={styles.commandBadge}
          onClick={() => setOpen((value) => !value)}
          type="button">
          <span>{selected.label}</span><span aria-hidden="true">▾</span>
        </button>
      )}>
        {selected.command}
      </CodePanel>
      <div className={styles.installDetail}>
        <span>{selected.detail}</span>
        <a href="https://github.com/asaphaaning/hyprbaric/releases/latest">Direct downloads →</a>
      </div>
      {open && (
        <div className={styles.installMenu}>
          <span className={styles.installMenuLabel}>Installation route</span>
          {installOptions.map((option) => (
            <button
              className={option.label === selected.label ? styles.installMenuItemActive : styles.installMenuItem}
              key={option.label}
              onClick={() => {
                setSelected(option);
                setOpen(false);
              }}
              type="button">
              <span>{option.name}</span><small>{option.tool}</small>
            </button>
          ))}
          <Link to="/docs/installation">Installation details →</Link>
        </div>
      )}
    </div>
  );
}

/** A recessed code display using the documentation's Prism and copy controls. */
function CodePanel({children, title, language, controls}) {
  return (
    <div className={styles.codePanel}>
      <div className={styles.codePanelHeader}>
        <span className={styles.codePanelTitle}>{title}</span>
        {controls ?? <span className={styles.codeLanguage}>{language}</span>}
      </div>
      <CodeBlock language={language}>{children}</CodeBlock>
    </div>
  );
}

function ModuleCard({module}) {
  const imageUrl = useBaseUrl(module.image);

  return (
    <article className={styles.moduleCard}>
      <span className={styles.cardLabel}>{module.label}</span>
      <h3>{module.title}</h3>
      <p>{module.text}</p>
      {module.label === 'Network' ? (
        <FlutterDemo className={styles.networkPreview} preview="network" />
      ) : module.label === 'Volume' ? (
        <FlutterDemo className={styles.mixerPreview} />
      ) : module.label === 'Controls' ? (
        <FlutterDemo className={styles.controlsPreview} preview="controls" />
      ) : module.label === 'Power' ? (
        <FlutterDemo className={styles.powerPreview} preview="power" />
      ) : (
        <div className={styles.panelPreview}><img src={imageUrl} alt={`${module.label} panel`} /></div>
      )}
    </article>
  );
}

function DesktopPreview({desktop}) {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const closeWithEscape = (event) => {
      if (event.key === 'Escape') setOpen(false);
    };
    document.addEventListener('keydown', closeWithEscape);
    return () => document.removeEventListener('keydown', closeWithEscape);
  }, []);

  return (
    <>
      <div className={styles.desktopFrame}>
        <button className={styles.desktopShot} onClick={() => setOpen(true)} type="button">
          <img src={desktop} alt="hyprbaric running on a Hyprland desktop" />
        </button>
        <div><span>Hyprland · 3840 × 2160</span><span>Bar height 40 px</span></div>
      </div>
      {open && (
        <div
          aria-label="Expanded hyprbaric desktop preview"
          aria-modal="true"
          className={styles.lightbox}
          onClick={() => setOpen(false)}
          role="dialog">
          <div className={styles.lightboxFrame}>
            <img src={desktop} alt="hyprbaric running on a Hyprland desktop" />
            <div><span>Hyprland · 3840 × 2160</span><span>Esc to close</span></div>
          </div>
        </div>
      )}
    </>
  );
}

export default function Home() {
  const desktop = useBaseUrl('img/reference/desktop.png');
  const config = `[appearance]\nposition = "top"\nopacity = 77\ncorner_radius = 12\naccent_hue = 218\n\n[workspaces]\nindicator_style = "roman"\nclickable = true\nvisible_range = "medium"\n\n[network]\ntraffic_refresh_interval = "1s"\nfull_refresh_interval = "8s"`;

  return (
    <Layout title="hyprbaric" description="A native status bar for Hyprland, built with Flutter and Rust.">
      <main className={styles.page}>
        <section className={styles.hero} id="hero">
          <div className={styles.heroCopy}>
            <span className={styles.eyebrow}>A status bar for Hyprland</span>
            <h1>hyprbaric<span aria-hidden="true">.</span></h1>
            <p>Audio, network, workspaces, and the usual controls in one bar.</p>
            <div className={styles.actions}>
              <PlateLink to="/docs/installation" icon="download" primary>Get Hyprbaric</PlateLink>
              <PlateLink to="#modules" icon="modules">Explore the modules</PlateLink>
            </div>
            <p className={styles.heroNote}>Open source. Built with Flutter and Rust.</p>
          </div>
          <section className={styles.installSection} id="install">
            <h2>Install</h2>
            <p>Packages for Debian, Arch, Fedora, and an AppImage for everything else.</p>
            <InstallCommand />
            <PlateLink to="/docs/installation" icon="guide">Read the installation guide</PlateLink>
          </section>
        </section>


        <section className={styles.modules} id="modules">
          <span className={styles.eyebrow}>Modules</span>
          <div className={styles.sectionHeading}><h2>What’s in the bar</h2><span /></div>
          <div className={styles.moduleGrid}>
            {modules.map((module) => <ModuleCard key={module.label} module={module} />)}
            <div className={styles.stack}>
              <article className={styles.smallCard}>
                <span className={styles.cardLabel}>Workspaces</span>
                <h3>Workspace indicators</h3>
                <p>Labels follow whichever style you pick: roman numerals by default, plain numbers otherwise. Click to focus, and set how many stay visible.</p>
                <FlutterDemo className={styles.workspacePreview} preview="workspaces" />
              </article>
              <article className={styles.smallCard}>
                <span className={styles.cardLabel}>Notifications</span>
                <h3>Notification centre</h3>
                <p>A compact current-session inbox with a clear-all action.</p>
                <FlutterDemo className={styles.notificationPreview} preview="notifications" />
              </article>
            </div>
            <aside className={styles.guideCard}>
              <span className={styles.cardLabel}>Docs</span>
              <h3>Documentation</h3>
              <p>Installation, configuration, keybinds, and the full reference.</p>
              <PlateLink to="/docs/intro" icon="guide" primary>Browse the docs</PlateLink>
            </aside>
          </div>
        </section>

        <section className={styles.desktopSection} id="desktop">
          <div><h2>On Hyprland</h2><p>A 40px bar at the top of the workspace.</p></div>
          <DesktopPreview desktop={desktop} />
        </section>

        <section className={styles.configuration} id="config">
          <div>
            <span className={styles.cardLabel}>Configuration</span>
            <h2>Configuration</h2>
            <p>hyprbaric reads a single TOML file at startup. The settings window edits that same file, leaving your comments and unrelated tables intact.</p>
            <ul><li>Configuration covers appearance, module visibility, workspaces, shortcuts, and the behaviour of each module.</li><li>Timing values, such as refresh intervals and DDC discovery and debounce, have no GUI control.</li><li>A file that fails to parse stops startup rather than falling back to defaults.</li></ul>
            <PlateLink to="/docs/configuration" icon="settings">Read the configuration guide</PlateLink>
          </div>
          <CodePanel language="toml" title="~/.config/hyprbaric/config.toml">{config}</CodePanel>
        </section>
      </main>
    </Layout>
  );
}
