#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
installer="${project_root}/install.sh"
test_directory=$(mktemp -d "${TMPDIR:-/tmp}/hyprbaric-installer-test.XXXXXX")
trap 'rm -rf "$test_directory"' EXIT HUP INT TERM

assert_contains() {
  needle=$1
  file=$2
  grep -F -- "$needle" "$file" >/dev/null || {
    printf 'expected %s in %s\n' "$needle" "$file" >&2
    exit 1
  }
}

"$installer" --help > "${test_directory}/help"
assert_contains 'Install the latest Hyprbaric Linux release package.' "${test_directory}/help"

mkdir "${test_directory}/bin"
cat > "${test_directory}/bin/curl" <<'EOF'
#!/usr/bin/env sh
set -eu
output=''
previous=''
for argument in "$@"; do
  if [ "$previous" = '--output' ]; then
    output=$argument
    break
  fi
  previous=$argument
done
case "$*" in
  *'/releases/latest'*|*'/releases/tags/v0.1.0'*)
    cat > "$output" <<'JSON'
{
  "assets": [
    {
      "browser_download_url": "https://github.com/asaphaaning/hyprbaric/releases/download/v0.1.0/hyprbaric-0.1.0%2B1-linux.deb"
    },
    {
      "browser_download_url": "https://github.com/asaphaaning/hyprbaric/releases/download/v0.1.0/SHA256SUMS"
    }
  ]
}
JSON
    ;;
  *'hyprbaric-0.1.0%2B1-linux.deb'*) printf package > "$output" ;;
  *'/SHA256SUMS'*)
    printf '%s  %s\n' \
      bc4a71180870f7945155fbb02f4b0a2e3faa2a62d6d31b7039013055ed19869a \
      hyprbaric-0.1.0+1-linux.deb > "$output"
    ;;
  *) : > "$output" ;;
esac
EOF
cat > "${test_directory}/bin/sudo" <<'EOF'
#!/usr/bin/env sh
exec "$@"
EOF
cat > "${test_directory}/bin/apt-get" <<'EOF'
#!/usr/bin/env sh
set -eu
printf '%s\n' "$*" > "$HYPRBARIC_TEST_LOG"
test -f "$3"
EOF
chmod +x "${test_directory}/bin/curl" "${test_directory}/bin/sudo" "${test_directory}/bin/apt-get"

cat > "${test_directory}/os-release" <<'EOF'
ID=debian
EOF
PATH="${test_directory}/bin:${PATH}" \
  HYPRBARIC_INSTALL_OS_RELEASE="${test_directory}/os-release" \
  HYPRBARIC_TEST_LOG="${test_directory}/apt-get" \
  "$installer" > "${test_directory}/install"

assert_contains 'install --yes' "${test_directory}/apt-get"
assert_contains '.deb' "${test_directory}/apt-get"
assert_contains 'installation complete' "${test_directory}/install"

PATH="${test_directory}/bin:${PATH}" \
  HYPRBARIC_INSTALL_OS_RELEASE="${test_directory}/os-release" \
  HYPRBARIC_TEST_LOG="${test_directory}/apt-get" \
  "$installer" --version v0.1.0 > "${test_directory}/pinned-install"

assert_contains 'looking up v0.1.0 release' "${test_directory}/pinned-install"
