import {useState} from 'react';

import styles from './index.module.css';

const options = [
  {
    id: 'quick',
    label: 'Automatic',
    description: 'Detects your distribution, downloads its native package, verifies it, and installs it.',
    copy: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh",
    code: (
      <>
        <span className={styles.comment}># download the latest package for this Linux distribution</span>{'\n'}
        curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh
      </>
    ),
  },
  {
    id: 'deb',
    label: 'Debian · Ubuntu',
    description: 'Installs the release DEB with apt, including its declared runtime dependencies.',
    copy: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh",
    code: (
      <>
        <span className={styles.comment}># Debian and Ubuntu are detected automatically; the installer selects the DEB</span>{'\n'}
        curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh
      </>
    ),
  },
  {
    id: 'pacman',
    label: 'Arch · Manjaro',
    description: 'Installs the release Pacman package with pacman.',
    copy: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh",
    code: (
      <>
        <span className={styles.comment}># Arch-based distributions are detected automatically; the installer selects the Pacman package</span>{'\n'}
        curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh
      </>
    ),
  },
  {
    id: 'rpm',
    label: 'Fedora · openSUSE',
    description: 'Installs the release RPM with dnf or zypper.',
    copy: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh",
    code: (
      <>
        <span className={styles.comment}># Fedora and openSUSE are detected automatically; the installer selects the RPM</span>{'\n'}
        curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh
      </>
    ),
  },
  {
    id: 'appimage',
    label: 'Other Linux',
    description: 'Installs the AppImage in ~/.local/bin when no native package matches.',
    copy: "curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh",
    code: (
      <>
        <span className={styles.comment}># Other x86_64 Linux distributions receive the self-contained AppImage</span>{'\n'}
        curl --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh
      </>
    ),
  },
];

export default function InstallTabs() {
  const [selected, setSelected] = useState(options[0]);
  const [copied, setCopied] = useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(selected.copy);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      setCopied(false);
    }
  };

  return (
    <div className={styles.install}>
      <div aria-label="Installation route" className={styles.tabs} role="tablist">
        {options.map((option) => (
          <button
            aria-selected={selected.id === option.id}
            className={selected.id === option.id ? styles.tabActive : styles.tab}
            key={option.id}
            onClick={() => setSelected(option)}
            role="tab"
            type="button">
            {option.label}
          </button>
        ))}
      </div>
      <p className={styles.description}>{selected.description}</p>
      <div className={styles.terminal}>
        <div className={styles.terminalHeader}>
          <span>shell</span>
          <button onClick={copy} type="button">{copied ? 'Copied' : 'Copy'}</button>
        </div>
        <pre>{selected.code}</pre>
      </div>
    </div>
  );
}
