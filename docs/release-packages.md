# Release packages

Tags named `v<pubspec version>` build AppImage, DEB, RPM and Pacman artifacts on
Ubuntu 24.04. The Flutter, native and hub versions must agree. Tag a commit that
contains the current release workflow and build fixes: rebuilding an older tag
still checks out that tag's old source.

Changes to packaging, the Linux runner or the AppMenu companion also run the
release workflow on pull requests. These runs retain validated packages as an
Actions artifact without publishing a GitHub release.

To exercise the same package path locally with the workflow's prerequisites:

```sh
./tool/resolve-flutter-dependencies
rinf gen
./tool/verify-dart-sources
flutter analyze
flutter test
cargo fmt --all -- --check
cargo test --workspace --locked
./packaging/build-linux-packages
./packaging/verify-linux-packages
```

Use Flutter 3.47.2, Rust 1.94.1, RINF CLI 8.10.0 and Fastforge 0.6.12. The
verification script additionally requires `squashfs-tools`, `libarchive-tools`,
`rpm` and `dpkg-deb`. It checks all four formats, launchers, package metadata,
permissions and the bundled AppMenu source needed for a compositor-local build.

The bar itself builds without Hyprland development headers. When `hyprland.pc`
is available, CMake also builds the precompiled AppMenu companion. Otherwise,
packages retain its source and the existing runtime rebuilds it against the
installed compositor, falling back to hyprpm. This preserves ABI compatibility
instead of shipping a plugin compiled for an arbitrary CI compositor. Global
menus require the matching development headers and CMake or a working hyprpm
setup; other bar features do not require that toolchain.
