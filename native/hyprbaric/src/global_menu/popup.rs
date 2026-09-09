//! Announced popup ownership and descendant-first dismissal.
use super::{SectionId, endpoint::Endpoint};
/// A D-BusMenu the bar announced as open, so dismiss can send `closed`
/// to the same exporter even after focus has moved on.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(in crate::global_menu) struct Opened {
    pub endpoint: Endpoint,
    pub id: i32,
    pub path: Vec<String>,
    /// The address Dart is watching. Firefox may have issued a new `id`.
    pub section: SectionId,
}

impl Opened {
    pub(in crate::global_menu) fn belongs(&self, id: i32, path: &[String]) -> bool {
        self.id == id || (!path.is_empty() && self.path.starts_with(path))
    }
}

/// Which announced menus close with this heading, nested flyouts first.
pub(in crate::global_menu) fn closing(
    opened: Vec<Opened>,
    id: i32,
    path: &[String],
) -> (Vec<Opened>, Vec<Opened>) {
    let mut close = Vec::new();
    let mut keep = Vec::new();
    for menu in opened {
        if menu.belongs(id, path) {
            close.push(menu);
        } else {
            keep.push(menu);
        }
    }
    close.sort_by(|left, right| right.path.len().cmp(&left.path.len()));
    (close, keep)
}
