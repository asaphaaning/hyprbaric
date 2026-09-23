//! Tray icon resolution and pixmap encoding.

use std::{
    collections::HashMap,
    env, fs,
    io::Cursor,
    path::{Path, PathBuf},
};

use image::{ColorType, ImageEncoder, codecs::png::PngEncoder};
use system_tray::item::{IconPixmap, Status as NotifierStatus, StatusNotifierItem};

use super::{Error, Icon};

const PRIMARY_ICON_CONTEXTS: &[&str] = &["status", "apps", "devices", "legacy"];
const FALLBACK_ICON_CONTEXTS: &[&str] = &[
    "actions",
    "categories",
    "mimetypes",
    "places",
    "preferences",
];

/// Cached icon-theme lookup.
pub(super) struct Index {
    primary_directories: Vec<IconDirectory>,
    fallback_directories: Option<Vec<IconDirectory>>,
    pixmap_directories: Vec<IconDirectory>,
    cache: HashMap<String, Option<PathBuf>>,
    encoded_pixmaps: HashMap<String, EncodedPixmap>,
}

/// Last pixmap and PNG for one notifier address.
struct EncodedPixmap {
    source: IconPixmap,
    png: Vec<u8>,
}

impl Index {
    /// Builds an icon lookup index from XDG icon roots.
    pub(super) fn new() -> Self {
        let mut primary_directories = Vec::new();
        let mut pixmap_directories = Vec::new();

        for (root_priority, root) in icon_theme_roots().into_iter().enumerate() {
            collect_icon_theme_directories(
                &root,
                root_priority,
                PRIMARY_ICON_CONTEXTS,
                &mut primary_directories,
            );
        }

        for (root_priority, root) in icon_pixmap_roots().into_iter().enumerate() {
            pixmap_directories.push(IconDirectory {
                root_priority,
                path: root,
            });
        }

        Self {
            primary_directories,
            fallback_directories: None,
            pixmap_directories,
            cache: HashMap::new(),
            encoded_pixmaps: HashMap::new(),
        }
    }

    fn encode(&mut self, address: &str, pixmap: &IconPixmap) -> Result<Vec<u8>, Error> {
        if let Some(cached) = self.encoded_pixmaps.get(address)
            && cached.source == *pixmap
        {
            return Ok(cached.png.clone());
        }

        let png = encode_pixmap(pixmap)?;
        tracing::debug!(
            address,
            width = pixmap.width,
            height = pixmap.height,
            "Encoded tray pixmap"
        );
        self.encoded_pixmaps.insert(
            address.to_owned(),
            EncodedPixmap {
                source: pixmap.clone(),
                png: png.clone(),
            },
        );
        Ok(png)
    }

    /// Releases cached pixmaps when their notifier leaves the tray.
    pub(super) fn retain(&mut self, mut contains: impl FnMut(&str) -> bool) {
        self.encoded_pixmaps.retain(|address, _| contains(address));
    }

    fn resolve(&mut self, icon: &str) -> Option<PathBuf> {
        let direct = Path::new(icon);
        if (direct.is_absolute() || icon.contains('/')) && direct.exists() {
            return Some(direct.to_path_buf());
        }

        let name = icon_name(icon)?;
        if let Some(candidate) = self.cache.get(name.cache_key()) {
            return candidate.clone();
        }

        let candidate = self.resolve_name(&name);
        self.cache
            .insert(name.cache_key().to_string(), candidate.clone());
        candidate
    }

    fn resolve_name(&mut self, name: &IconName) -> Option<PathBuf> {
        Self::resolve_in_directories(
            name,
            self.primary_directories
                .iter()
                .chain(&self.pixmap_directories),
        )
        .or_else(|| {
            if self.fallback_directories.is_none() {
                self.fallback_directories = Some(collect_fallback_icon_directories());
            }
            Self::resolve_in_directories(
                name,
                self.fallback_directories
                    .as_deref()
                    .unwrap_or_default()
                    .iter(),
            )
        })
    }

    fn resolve_in_directories<'a>(
        name: &IconName,
        directories: impl IntoIterator<Item = &'a IconDirectory>,
    ) -> Option<PathBuf> {
        let mut best = None::<IconCandidate>;

        for directory in directories {
            for stem in name.stems() {
                for extension in ["svg", "png", "xpm"] {
                    let path = directory.path.join(format!("{stem}.{extension}"));
                    if !path.exists() {
                        continue;
                    }

                    let candidate = IconCandidate {
                        score: icon_score(&path, directory.root_priority),
                        path,
                    };

                    match &best {
                        Some(existing) if existing.score >= candidate.score => {}
                        _ => best = Some(candidate),
                    }
                }
            }
        }

        best.map(|candidate| candidate.path)
    }
}

/// Resolves a notifier item's display icon.
pub(super) fn resolve(address: &str, item: &StatusNotifierItem, icons: &mut Index) -> Icon {
    if item.status == NotifierStatus::NeedsAttention {
        if let Some(icon) = resolve_icon(
            address,
            item.attention_icon_name.as_deref(),
            item.attention_icon_pixmap.as_deref(),
            icons,
        ) {
            return icon;
        }
    }

    resolve_icon(
        address,
        item.icon_name.as_deref(),
        item.icon_pixmap.as_deref(),
        icons,
    )
    .or_else(|| {
        resolve_icon(
            address,
            item.overlay_icon_name.as_deref(),
            item.overlay_icon_pixmap.as_deref(),
            icons,
        )
    })
    .unwrap_or(Icon::None)
}

fn resolve_icon(
    address: &str,
    icon_name: Option<&str>,
    icon_pixmap: Option<&[IconPixmap]>,
    icons: &mut Index,
) -> Option<Icon> {
    if let Some(name) = icon_name {
        if let Some(path) = icons.resolve(name) {
            return Some(Icon::Theme {
                symbolic: is_symbolic(name, Some(&path)),
                path,
            });
        }
    }

    icon_pixmap
        .and_then(best_pixmap)
        .and_then(|pixmap| icons.encode(address, pixmap).ok())
        .map(|bytes| Icon::Png {
            bytes,
            symbolic: false,
        })
}

fn best_pixmap(pixmaps: &[IconPixmap]) -> Option<&IconPixmap> {
    pixmaps.iter().max_by_key(|pixmap| {
        let width = i64::from(pixmap.width.max(0));
        let height = i64::from(pixmap.height.max(0));
        width * height
    })
}

fn encode_pixmap(pixmap: &IconPixmap) -> Result<Vec<u8>, Error> {
    let width = u32::try_from(pixmap.width).map_err(|_| Error::InvalidPixmapDimensions {
        width: pixmap.width,
        height: pixmap.height,
    })?;
    let height = u32::try_from(pixmap.height).map_err(|_| Error::InvalidPixmapDimensions {
        width: pixmap.width,
        height: pixmap.height,
    })?;

    let expected = width as usize * height as usize * 4;
    if pixmap.pixels.len() != expected {
        return Err(Error::InvalidPixmapLength {
            expected,
            actual: pixmap.pixels.len(),
        });
    }

    let mut rgba = Vec::with_capacity(expected);
    for chunk in pixmap.pixels.chunks_exact(4) {
        rgba.extend_from_slice(&[chunk[1], chunk[2], chunk[3], chunk[0]]);
    }

    let mut encoded = Cursor::new(Vec::new());
    PngEncoder::new(&mut encoded)
        .write_image(&rgba, width, height, ColorType::Rgba8.into())
        .map_err(Error::PngEncode)?;
    Ok(encoded.into_inner())
}

fn is_symbolic(name: &str, path: Option<&Path>) -> bool {
    name.to_ascii_lowercase().contains("symbolic")
        || path.is_some_and(|value| {
            value
                .file_stem()
                .and_then(|stem| stem.to_str())
                .is_some_and(|stem| stem.to_ascii_lowercase().contains("symbolic"))
        })
}

fn collect_fallback_icon_directories() -> Vec<IconDirectory> {
    let mut directories = Vec::new();

    for (root_priority, root) in icon_theme_roots().into_iter().enumerate() {
        collect_icon_theme_directories(
            &root,
            root_priority,
            FALLBACK_ICON_CONTEXTS,
            &mut directories,
        );
    }

    directories
}

struct IconDirectory {
    path: PathBuf,
    root_priority: usize,
}

struct IconCandidate {
    path: PathBuf,
    score: i32,
}

#[derive(Clone, Debug, PartialEq, Eq)]
struct IconName {
    cache_key: String,
    stems: Vec<String>,
}

impl IconName {
    fn cache_key(&self) -> &str {
        &self.cache_key
    }

    fn stems(&self) -> &[String] {
        &self.stems
    }
}

fn collect_icon_theme_directories(
    root: &Path,
    root_priority: usize,
    contexts: &[&str],
    directories: &mut Vec<IconDirectory>,
) {
    for theme in child_directories(root) {
        push_icon_context_directories(&theme, root_priority, contexts, directories);
        push_icon_context_directories(
            &theme.join("symbolic"),
            root_priority,
            contexts,
            directories,
        );

        for size in child_directories(&theme) {
            push_icon_context_directories(&size, root_priority, contexts, directories);
            push_icon_context_directories(
                &size.join("symbolic"),
                root_priority,
                contexts,
                directories,
            );
        }
    }
}

fn push_icon_context_directories(
    root: &Path,
    root_priority: usize,
    contexts: &[&str],
    directories: &mut Vec<IconDirectory>,
) {
    for context in contexts {
        push_icon_directory_branch(root.join(context), root_priority, directories);
    }
}

fn push_icon_directory_branch(
    path: PathBuf,
    root_priority: usize,
    directories: &mut Vec<IconDirectory>,
) {
    push_icon_directory(path.clone(), root_priority, directories);

    for child in child_directories(&path) {
        push_icon_directory(child, root_priority, directories);
    }
}

fn push_icon_directory(path: PathBuf, root_priority: usize, directories: &mut Vec<IconDirectory>) {
    if path.is_dir() && !directories.iter().any(|directory| directory.path == path) {
        directories.push(IconDirectory {
            path,
            root_priority,
        });
    }
}

fn child_directories(root: &Path) -> Vec<PathBuf> {
    let mut directories = fs::read_dir(root)
        .into_iter()
        .flat_map(|entries| entries.flatten())
        .filter_map(|entry| {
            entry
                .file_type()
                .ok()
                .filter(|kind| kind.is_dir())
                .map(|_| entry.path())
        })
        .collect::<Vec<_>>();
    directories.sort();
    directories
}

fn icon_theme_roots() -> Vec<PathBuf> {
    let mut roots = Vec::new();
    roots.push(user_data_directory().join("icons"));
    if let Some(home) = env::var_os("HOME") {
        roots.push(PathBuf::from(home).join(".icons"));
    }

    for data_dir in xdg_data_dirs() {
        roots.push(data_dir.join("icons"));
    }

    roots
}

fn icon_pixmap_roots() -> Vec<PathBuf> {
    xdg_data_dirs()
        .into_iter()
        .map(|data_dir| data_dir.join("pixmaps"))
        .collect()
}

fn user_data_directory() -> PathBuf {
    env::var_os("XDG_DATA_HOME")
        .map(PathBuf::from)
        .or_else(|| env::var_os("HOME").map(|home| PathBuf::from(home).join(".local/share")))
        .unwrap_or_else(|| PathBuf::from("/tmp"))
}

fn xdg_data_dirs() -> Vec<PathBuf> {
    env::var_os("XDG_DATA_DIRS")
        .map(|paths| env::split_paths(&paths).collect())
        .filter(|paths: &Vec<PathBuf>| !paths.is_empty())
        .unwrap_or_else(|| {
            vec![
                PathBuf::from("/usr/local/share"),
                PathBuf::from("/usr/share"),
            ]
        })
}

fn icon_name(icon: &str) -> Option<IconName> {
    let value = icon.trim();
    if value.is_empty() {
        return None;
    }

    let stem = icon_stem(value);
    let lowercase = stem.to_ascii_lowercase();
    let mut stems = vec![stem.clone()];
    if lowercase != stem {
        stems.push(lowercase);
    }

    Some(IconName {
        cache_key: stem,
        stems,
    })
}

fn icon_stem(icon: &str) -> String {
    let name = Path::new(icon)
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or(icon);

    for extension in [".svg", ".png", ".xpm"] {
        if name
            .get(name.len().saturating_sub(extension.len())..)
            .is_some_and(|suffix| suffix.eq_ignore_ascii_case(extension))
        {
            return name[..name.len() - extension.len()].to_string();
        }
    }

    name.to_string()
}

fn icon_score(path: &Path, root_priority: usize) -> i32 {
    let extension_score = match path
        .extension()
        .and_then(|extension| extension.to_str())
        .map(|extension| extension.to_ascii_lowercase())
        .as_deref()
    {
        Some("svg") => 3_000,
        Some("png") => 2_800,
        Some("xpm") => 1_000,
        _ => 0,
    };

    let size_score = path
        .components()
        .filter_map(|component| component.as_os_str().to_str())
        .map(icon_size_score)
        .max()
        .unwrap_or_default();
    let root_score = 500_i32.saturating_sub(root_priority as i32);

    extension_score + size_score + root_score
}

fn icon_size_score(component: &str) -> i32 {
    let Some((width, height)) = component.split_once('x') else {
        return 0;
    };
    let Ok(width) = width.parse::<i32>() else {
        return 0;
    };
    let Ok(height) = height.parse::<i32>() else {
        return 0;
    };
    let size = width.max(height);
    if size >= 32 { 240 + size } else { 120 + size }
}

#[cfg(test)]
mod tests {
    use system_tray::item::IconPixmap;

    use super::{Index, encode_pixmap};
    use crate::tray::Error;

    #[test]
    fn argb_pixmap_encodes_as_png() {
        let bytes = encode_pixmap(&IconPixmap {
            width: 1,
            height: 1,
            pixels: vec![0xFF, 0x11, 0x22, 0x33],
        })
        .expect("pixmap should encode");
        let decoded = image::load_from_memory(&bytes)
            .expect("png should decode")
            .to_rgba8();
        assert_eq!(decoded.into_raw(), vec![0x11, 0x22, 0x33, 0xFF]);
    }

    #[test]
    fn invalid_pixmap_length_errors() {
        let error = encode_pixmap(&IconPixmap {
            width: 1,
            height: 1,
            pixels: vec![0xFF, 0x11],
        })
        .expect_err("pixmap should fail");
        assert!(matches!(
            error,
            Error::InvalidPixmapLength {
                expected: 4,
                actual: 2
            }
        ));
    }

    #[test]
    fn encoded_pixmap_tracks_content_and_notifier_lifetime() {
        let mut icons = Index {
            primary_directories: Vec::new(),
            fallback_directories: None,
            pixmap_directories: Vec::new(),
            cache: Default::default(),
            encoded_pixmaps: Default::default(),
        };
        let first = IconPixmap {
            width: 1,
            height: 1,
            pixels: vec![0xFF, 0x11, 0x22, 0x33],
        };

        let original = icons.encode(":1.10", &first).expect("valid pixmap");
        let cached = icons.encoded_pixmaps[":1.10"].png.as_ptr();
        assert_eq!(
            icons.encode(":1.10", &first).expect("cached pixmap"),
            original
        );
        assert_eq!(icons.encoded_pixmaps[":1.10"].png.as_ptr(), cached);

        let changed = IconPixmap {
            pixels: vec![0xFF, 0x44, 0x55, 0x66],
            ..first
        };
        let replacement = icons.encode(":1.10", &changed).expect("changed pixmap");
        assert_ne!(replacement, original);
        assert_eq!(icons.encoded_pixmaps[":1.10"].source, changed);

        icons.encode(":1.11", &changed).expect("other notifier");
        icons.retain(|address| address == ":1.11");
        assert!(!icons.encoded_pixmaps.contains_key(":1.10"));
        assert!(icons.encoded_pixmaps.contains_key(":1.11"));
    }
}
