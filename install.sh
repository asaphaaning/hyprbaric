#!/usr/bin/env sh
# Hyprbaric's release installer. Fetch this file over HTTPS and pipe it to sh.
set -eu

repository='asaphaaning/hyprbaric'
api_base="${HYPRBARIC_INSTALL_API_BASE:-https://api.github.com/repos/${repository}}"
os_release="${HYPRBARIC_INSTALL_OS_RELEASE:-/etc/os-release}"

usage() {
  cat <<'EOF'
Install the latest Hyprbaric Linux release package.

Usage:
  curl --proto '=https' --tlsv1.2 -sSf \
    https://raw.githubusercontent.com/asaphaaning/hyprbaric/master/install.sh | sh

Options:
  --version TAG  Install a specific release tag, for example v0.1.0.
  --help         Show this help.

The installer supports x86_64 Debian/Ubuntu (.deb), Arch (.pkg.tar.xz),
Fedora/RHEL/openSUSE (.rpm), and an AppImage fallback for other Linux systems.
EOF
}

say() {
  printf '%s\n' "hyprbaric: $*"
}

die() {
  say "$*" >&2
  exit 1
}

has() {
  command -v "$1" >/dev/null 2>&1
}

download() {
  source_url=$1
  destination=$2

  if has curl; then
    curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
      --output "$destination" "$source_url"
  elif has wget; then
    wget --https-only --secure-protocol=TLSv1_2 --quiet \
      --output-document="$destination" "$source_url"
  else
    die 'curl or wget is required to download Hyprbaric.'
  fi
}

with_privileges() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif has sudo; then
    sudo "$@"
  else
    die "Installing a system package requires root privileges. Re-run with sudo or install sudo."
  fi
}

release_tag='latest'
while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      [ "$#" -ge 2 ] || die '--version needs a release tag.'
      release_tag=$2
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

case "$(uname -s)" in
  Linux) ;;
  *) die 'Hyprbaric currently supports Linux only.' ;;
esac

case "$(uname -m)" in
  x86_64|amd64) ;;
  *) die "Hyprbaric release packages currently support x86_64 only (found $(uname -m))." ;;
esac

[ -r "$os_release" ] || die "cannot read Linux distribution information at ${os_release}."
# shellcheck disable=SC1090
. "$os_release"
distribution=${ID:-unknown}
distribution_like=${ID_LIKE:-}

case "${distribution} ${distribution_like}" in
  *arch*) package_kind='pacman' ;;
  *debian*|*ubuntu*) package_kind='deb' ;;
  *fedora*|*rhel*|*suse*) package_kind='rpm' ;;
  *) package_kind='appimage' ;;
esac

case "$release_tag" in
  latest) release_endpoint="${api_base}/releases/latest" ;;
  *) release_endpoint="${api_base}/releases/tags/${release_tag}" ;;
esac

temporary_directory=$(mktemp -d "${TMPDIR:-/tmp}/hyprbaric.XXXXXX")
trap 'rm -rf "$temporary_directory"' EXIT HUP INT TERM
release_json="${temporary_directory}/release.json"
release_urls="${temporary_directory}/release-urls"

say "looking up ${release_tag} release"
if ! download "$release_endpoint" "$release_json"; then
  die 'could not fetch a published Hyprbaric release. See https://github.com/asaphaaning/hyprbaric/releases for available downloads.'
fi

sed -n 's/^[[:space:]]*"browser_download_url":[[:space:]]*"\(https:\/\/github\.com\/[^"]*\)".*/\1/p' \
  "$release_json" > "$release_urls"
[ -s "$release_urls" ] || die 'the release has no downloadable assets.'

select_asset() {
  suffix=$1
  while IFS= read -r candidate; do
    case "$candidate" in
      *"$suffix")
        printf '%s\n' "$candidate"
        return 0
        ;;
    esac
  done < "$release_urls"
  return 1
}

select_named_asset() {
  name=$1
  while IFS= read -r candidate; do
    case "$candidate" in
      */"$name")
        printf '%s\n' "$candidate"
        return 0
        ;;
    esac
  done < "$release_urls"
  return 1
}

verify_checksum() {
  manifest_url=$1
  asset_name=$2
  asset_path=$3
  manifest_path="${temporary_directory}/SHA256SUMS"

  say 'verifying release checksum'
  download "$manifest_url" "$manifest_path"
  expected=$(awk -v name="$asset_name" '$2 == name || $2 == "*" name { print $1; exit }' "$manifest_path")
  [ -n "$expected" ] || die "checksum manifest does not contain ${asset_name}."

  if has sha256sum; then
    actual=$(sha256sum "$asset_path" | awk '{print $1}')
  elif has shasum; then
    actual=$(shasum -a 256 "$asset_path" | awk '{print $1}')
  else
    die 'sha256sum or shasum is required to verify the downloaded release.'
  fi

  [ "$actual" = "$expected" ] || die "checksum verification failed for ${asset_name}."
}

case "$package_kind" in
  deb) asset_url=$(select_asset '.deb') || asset_url='' ;;
  pacman) asset_url=$(select_asset '.pkg.tar.xz') || asset_url='' ;;
  rpm) asset_url=$(select_asset '.rpm') || asset_url='' ;;
  appimage) asset_url=$(select_asset '.AppImage') || asset_url='' ;;
esac

if [ -z "$asset_url" ] && [ "$package_kind" != 'appimage' ]; then
  say "no ${package_kind} package is attached to this release; using the AppImage fallback."
  asset_url=$(select_asset '.AppImage') || asset_url=''
  package_kind='appimage'
fi

[ -n "$asset_url" ] || die 'this release does not include a compatible package for your system.'

checksums_url=$(select_named_asset 'SHA256SUMS') || checksums_url=''
[ -n "$checksums_url" ] || die 'this release does not include a SHA256SUMS checksum manifest.'

asset_name=$(printf '%s\n' "${asset_url##*/}" | sed 's/%2[Bb]/+/g')
asset_path="${temporary_directory}/${asset_name}"
say "downloading ${asset_name}"
download "$asset_url" "$asset_path"
verify_checksum "$checksums_url" "$asset_name" "$asset_path"

case "$package_kind" in
  deb)
    has apt-get || die 'apt-get is required to install the Debian package.'
    with_privileges apt-get install --yes "$asset_path"
    ;;
  pacman)
    has pacman || die 'pacman is required to install the Arch package.'
    with_privileges pacman --upgrade --needed --noconfirm "$asset_path"
    ;;
  rpm)
    if has dnf; then
      with_privileges dnf install --assumeyes "$asset_path"
    elif has zypper; then
      with_privileges zypper --non-interactive install "$asset_path"
    else
      die 'dnf or zypper is required to install the RPM package.'
    fi
    ;;
  appimage)
    install_directory="${HOME}/.local/bin"
    mkdir -p "$install_directory"
    install -m 755 "$asset_path" "${install_directory}/hyprbaric.AppImage"
    ln -sfn 'hyprbaric.AppImage' "${install_directory}/hyprbaric"
    say "installed ${install_directory}/hyprbaric (ensure ~/.local/bin is on PATH)."
    ;;
esac

say 'installation complete. Start it with: hyprbaric'
