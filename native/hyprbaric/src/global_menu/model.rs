//! Shared, pure menu presentation transforms.
use super::{Item, ItemKind, Menu};
pub(in crate::global_menu) fn without_empty_dividers(items: Vec<Item>) -> Vec<Item> {
    let mut rows = Vec::with_capacity(items.len());
    for item in items {
        if item.kind == ItemKind::Separator
            && matches!(
                rows.last(),
                None | Some(Item {
                    kind: ItemKind::Separator,
                    ..
                })
            )
        {
            continue;
        }
        rows.push(item);
    }
    while matches!(
        rows.last(),
        Some(Item {
            kind: ItemKind::Separator,
            ..
        })
    ) {
        rows.pop();
    }
    rows
}

pub(in crate::global_menu) fn entitle_anonymous_list(menu: &mut Menu, title: String) {
    if let [section] = menu.sections.as_mut_slice() {
        if section.label.is_empty() {
            section.label = title;
        }
    }
}

pub(in crate::global_menu) fn strip_mnemonics(value: &str) -> String {
    value
        .replace("__", "\0")
        .replace('_', "")
        .replace('\0', "_")
}
