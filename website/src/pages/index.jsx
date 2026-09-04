import {useEffect, useState} from 'react';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import Layout from '@theme/Layout';

import FlutterDemo from '../components/FlutterDemo';
import styles from './index.module.css';

const installOptions = [
  {
    name: 'Automatic',
    tool: 'Recommended',
    label: 'Linux · auto-detect',
    detail: 'Detects your distribution and installs its verified release package.',
    command: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/Hyprbaric/master/install.sh | sh",
  },
  {
    name: 'Debian / Ubuntu',
    tool: 'DEB package',
    label: 'Debian · Ubuntu',
    detail: 'Downloads the latest DEB and installs its runtime dependencies with apt.',
    command: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/Hyprbaric/master/install.sh | sh",
  },
  {
    name: 'Arch / Manjaro',
    tool: 'Pacman package',
    label: 'Arch · Manjaro',
    detail: 'Downloads the latest Pacman package and installs it with pacman.',
    command: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/Hyprbaric/master/install.sh | sh",
  },
  {
    name: 'Fedora / openSUSE',
    tool: 'RPM package',
    label: 'Fedora · openSUSE',
    detail: 'Downloads the latest RPM and installs it with dnf or zypper.',
    command: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/Hyprbaric/master/install.sh | sh",
  },
  {
    name: 'Other Linux',
    tool: 'AppImage',
    label: 'Linux · AppImage',
    detail: 'Uses the self-contained AppImage when no native package matches.',
    command: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/Hyprbaric/master/install.sh | sh",
  },
];

const modules = [
  {
    label: 'Network',
    title: 'Traffic and Wi-Fi',
    text: 'Throughput and ping, the Wi-Fi networks in range, and your interface addresses.',
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

const barWidth = 3840;
const segment = {
  left: {offset: 13, width: 768},
  right: {offset: 3010, width: 818},
};

function barPart(id, start, end, details) {
  const cluster = start < 1000 ? 'left' : 'right';
  const bounds = segment[cluster];

  return {
    id,
    ...details,
    cluster,
    sourceStart: start,
    sourceEnd: end,
    left: `${((start - bounds.offset) / bounds.width) * 100}%`,
    width: `${((end - start) / bounds.width) * 100}%`,
  };
}

const barParts = [
  barPart('launcher', 23, 64, {label: 'Launcher', title: 'App launcher', text: 'Opens hyprbaric’s searchable desktop-entry launcher.', key: 'Super'}),
  barPart('previous', 80, 110, {label: 'Workspace step', title: 'Previous workspace', text: 'Moves focus one workspace to the left and dims when no target is available.', key: 'Super + ←'}),
  barPart('workspaces', 126, 420, {label: 'Workspaces', title: 'Workspace strip', text: 'Roman or numeric indicators keep the active workspace centered in a configurable visible range.', key: 'Super + 1…9'}),
  barPart('next', 430, 460, {label: 'Workspace step', title: 'Next workspace', text: 'Moves focus one workspace to the right and dims when no target is available.', key: 'Super + →'}),
  barPart('tray', 3300, 3351, {label: 'Tray', title: 'System tray', text: 'StatusNotifier tray items appear here, each with its own menu.', key: '—'}),
  barPart('network', 3351, 3398, {label: 'Network', title: 'Network', text: 'Throughput and ping, Wi-Fi networks in range, and interface addresses.', key: 'Super + N'}),
  barPart('audio', 3398, 3438, {label: 'Volume', title: 'Volume & brightness', text: 'Output and input levels with live meters, and screen brightness.', key: '—'}),
  barPart('power', 3438, 3477, {label: 'Power', title: 'Battery & power profiles', text: 'Charge level and time remaining, and the active power profile.', key: '—'}),
  barPart('controls', 3477, 3516, {label: 'Controls', title: 'Controls & toggles', text: 'Colour picking, do not disturb, night light, caffeine, capture, and recording actions.', key: 'Super + S'}),
  barPart('notifications', 3516, 3568, {label: 'Notifications', title: 'Notification centre', text: 'A compact current-session inbox with per-item dismissal and a clear-all action.', key: 'Super + Shift + D'}),
  barPart('clock', 3576, 3760, {label: 'Clock', title: 'Date & time', text: 'The current date and time open a full calendar popover on click.', key: '—'}),
  barPart('session', 3775, 3822, {label: 'Session', title: 'Session actions', text: 'Lock, log out, suspend, reboot, and power off.', key: 'Super + Escape'}),
];

function CopyButton({value, label = 'Copy'}) {
  const [copied, setCopied] = useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      setCopied(false);
    }
  };

  return <button className={styles.copy} type="button" onClick={copy}>{copied ? 'Copied' : label}</button>;
}

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
      <div className={styles.installCommand}>
        <button
          aria-expanded={open}
          className={styles.commandBadge}
          onClick={() => setOpen((value) => !value)}
          type="button">
          <span>{selected.label}</span><span aria-hidden="true">▾</span>
        </button>
        <span className={styles.commandDivider} />
        <code><b>$</b> {selected.command}</code>
        <CopyButton value={selected.command} />
      </div>
      <div className={styles.installDetail}>
        <span>{selected.detail}</span>
        <a href="https://github.com/asaphaaning/Hyprbaric/releases/latest">Direct downloads →</a>
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

function Terminal({children, title = 'Shell'}) {
  return (
    <div className={styles.terminal}>
      <div className={styles.terminalHeader}><span>{title}</span><CopyButton value={children} /></div>
      <pre>{children}</pre>
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

function BarCloseup() {
  const [part, setPart] = useState();
  const leftBar = useBaseUrl('img/reference/bar-seg-a-cut.png');
  const rightBar = useBaseUrl('img/reference/bar-seg-b-cut.png');
  const barStrip = useBaseUrl('img/reference/bar-strip.png');
  const leftParts = barParts.filter((item) => item.cluster === 'left');
  const rightParts = barParts.filter((item) => item.cluster === 'right');

  const cluster = (name, image, alt, parts) => {
    const selected = part?.cluster === name ? part : undefined;
    const maskClass = name === 'left' ? styles.barImageMaskLeft : styles.barImageMaskRight;

    return (
      <div className={`${styles.barCluster} ${styles[`barCluster${name === 'left' ? 'Left' : 'Right'}`]}`}>
        <span className={styles.barShadow} />
        <div className={maskClass}>
          <img src={image} alt={alt} />
          <span className={name === 'left' ? styles.clusterFadeLeft : styles.clusterFadeRight} />
          {part && !selected && <span className={styles.barVeilAll} />}
          {selected && (
            <>
              <span className={styles.barVeilBefore} style={{left: 0, width: selected.left}} />
              <span className={styles.barVeilAfter} style={{left: `calc(${selected.left} + ${selected.width})`, right: 0}} />
            </>
          )}
        </div>
        {selected && <span className={styles.barSelection} style={{left: selected.left, width: selected.width}} />}
        {parts.map((item) => (
          <button
            aria-label={item.title}
            className={styles.hotspot}
            key={item.id}
            onBlur={() => setPart(undefined)}
            onFocus={() => setPart(item)}
            onMouseEnter={() => setPart(item)}
            onMouseLeave={() => setPart(undefined)}
            style={{left: item.left, width: item.width}}
            type="button"
          />
        ))}
      </div>
    );
  };

  const loupeStyle = part ? (() => {
    const boxWidth = 255;
    const scale = Math.max(1.05, Math.min(2.3, ((boxWidth - 26) / (part.sourceEnd - part.sourceStart)) * .78));
    const center = ((part.sourceStart + part.sourceEnd) / 2) * scale;
    return {
      backgroundImage: `url(${barStrip})`,
      backgroundPosition: `${Math.round(boxWidth / 2 - center)}px center`,
      backgroundSize: `${Math.round(barWidth * scale)}px auto`,
    };
  })() : undefined;

  return (
    <section className={styles.closeup}>
      <div className={styles.closeupHeading}>
        <span>The bar, up close</span>
        <p>Tap or hover an element to see what it does.</p>
      </div>
      <div className={styles.barPreview}>
        {cluster('left', leftBar, 'hyprbaric launcher and workspace cluster', leftParts)}
        <span className={styles.barBreak}><i /><i /><i /></span>
        {cluster('right', rightBar, 'hyprbaric controls, clock, and session cluster', rightParts)}
      </div>
      <div className={styles.barExplanation}>
        {part ? (
          <>
            <span className={styles.barLoupe} style={loupeStyle} />
            <div><span>{part.label}</span><strong>{part.title}</strong><p>{part.text}</p></div>
            <kbd>{part.key}</kbd>
          </>
        ) : <div className={styles.barIdle}><span>Idle</span><p>Tap or hover an element on the bar above.</p></div>}
      </div>
    </section>
  );
}

export default function Home() {
  const desktop = useBaseUrl('img/reference/desktop.png');
  const config = `[appearance]\nposition = "top"\nopacity = 77\ncorner_radius = 12\naccent_hue = 197\n\n[workspaces]\nindicator_style = "roman"\nclickable = true\nvisible_range = "medium"\n\n[network]\ntraffic_refresh_interval = "1s"\nfull_refresh_interval = "8s"`;

  return (
    <Layout title="hyprbaric" description="A native status bar for Hyprland, built with Flutter and Rust.">
      <main className={styles.page}>
        <section className={styles.hero}>
          <div className={styles.heroCopy}>
            <h1>A status bar for Hyprland</h1>
            <p>Built on Flutter and Rust.</p>
            <div className={styles.actions}>
              <Link className={styles.primaryAction} to="/docs/installation">Install the latest release</Link>
              <a className={styles.secondaryAction} href="https://github.com/asaphaaning/Hyprbaric/releases/latest">Download packages</a>
            </div>
            <InstallCommand />
          </div>
          <DesktopPreview desktop={desktop} />
        </section>

        <BarCloseup />

        <section className={styles.modules} id="modules">
          <div className={styles.sectionHeading}><h2>Modules</h2><span /></div>
          <p>Each module opens its own panel with the readouts and controls for that area.</p>
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
              <Link to="/docs/intro">Browse the docs</Link>
            </aside>
          </div>
        </section>

        <section className={styles.configuration} id="config">
          <div>
            <span className={styles.cardLabel}>Configuration</span>
            <h2>Everything lives in one TOML file</h2>
            <p>hyprbaric reads a single TOML file at startup. The settings window edits that same file, leaving your comments and unrelated tables intact.</p>
            <ul><li>Configuration covers appearance, module visibility, workspaces, shortcuts, and the behaviour of each module.</li><li>Timing values, such as refresh intervals and DDC discovery and debounce, have no GUI control.</li><li>A file that fails to parse stops startup rather than falling back to defaults.</li></ul>
            <Link to="/docs/configuration">Read the configuration guide</Link>
          </div>
          <Terminal title="~/.config/hyprbaric/config.toml">{config}</Terminal>
        </section>
      </main>
    </Layout>
  );
}
