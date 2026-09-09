//! D-BusMenu layout decoding and stable label-path lookup.
use super::Node;
use crate::global_menu::{
    Error, Item, ItemId, ItemKind, Menu, Section, SectionId,
    model::{strip_mnemonics, without_empty_dividers},
};
use std::collections::HashMap;
use zbus::zvariant::{OwnedValue, Structure, Value};
impl Item {
    pub(in crate::global_menu) fn from(node: Node) -> Self {
        let kind = node.item_kind();
        let chrome = matches!(kind, ItemKind::Separator | ItemKind::Group);
        let submenu =
            (!chrome && node.opens_submenu()).then_some(SectionId::DbusMenu { id: node.id });

        Self {
            label: match kind {
                ItemKind::Separator => String::new(),
                ItemKind::Group => node.titled().unwrap_or_default(),
                _ => node.label(),
            },
            enabled: !chrome && node.enabled(),
            kind,
            shortcut: if chrome { None } else { node.shortcut() },
            activation: (!chrome && submenu.is_none()).then_some(ItemId::DbusMenu { id: node.id }),
            submenu,
            ..Self::empty()
        }
    }

    /// The neutral row every projection starts from.
    pub(in crate::global_menu) fn empty() -> Self {
        Self {
            label: String::new(),
            enabled: false,
            kind: ItemKind::Standard,
            shortcut: None,
            activation: None,
            submenu: None,
        }
    }
}

impl Node {
    pub(in crate::global_menu) fn property(&self, name: &str) -> Option<&str> {
        self.properties
            .get(name)
            .and_then(|value| value.downcast_ref::<&str>().ok())
    }

    pub(in crate::global_menu) fn flag(&self, name: &str) -> Option<bool> {
        self.properties
            .get(name)
            .and_then(|value| value.downcast_ref::<bool>().ok())
    }

    pub(in crate::global_menu) fn titled(&self) -> Option<String> {
        self.property("label")
            .map(strip_mnemonics)
            .filter(|label| !label.is_empty())
            .or_else(|| self.kde_title())
    }

    /// KDE section captions: a string `x-kde-title`, or boolean true with `label`.
    pub(in crate::global_menu) fn kde_title(&self) -> Option<String> {
        if self.flag("x-kde-title") == Some(true) {
            return self
                .property("label")
                .map(strip_mnemonics)
                .filter(|label| !label.is_empty());
        }

        self.property("x-kde-title")
            .map(strip_mnemonics)
            .filter(|label| !label.is_empty())
    }

    pub(in crate::global_menu) fn label(&self) -> String {
        self.titled().unwrap_or_else(|| "Untitled".to_owned())
    }

    pub(in crate::global_menu) fn enabled(&self) -> bool {
        self.flag("enabled").unwrap_or(true)
    }

    pub(in crate::global_menu) fn kind(&self) -> Option<&str> {
        self.property("type")
    }

    pub(in crate::global_menu) fn opens_submenu(&self) -> bool {
        self.property("children-display") == Some("submenu")
    }

    /// A menubar heading is a labeled submenu, not a command, divider, or caption.
    pub(in crate::global_menu) fn is_menubar_heading(&self) -> bool {
        self.visible()
            && !self.is_placeholder()
            && !matches!(self.item_kind(), ItemKind::Separator | ItemKind::Group)
            && self.titled().is_some()
            && (self.opens_submenu() || !self.children.is_empty())
    }

    /// Rows need a label unless they are a divider.
    pub(in crate::global_menu) fn is_row(&self) -> bool {
        self.visible()
            && !self.is_placeholder()
            && (self.item_kind() == ItemKind::Separator || self.titled().is_some())
    }

    pub(in crate::global_menu) fn visible(&self) -> bool {
        self.flag("visible").unwrap_or(true)
    }

    /// Firefox inserts an unlabeled dummy row so a still-empty popup counts as
    /// a submenu. It is not a real entry.
    pub(in crate::global_menu) fn is_placeholder(&self) -> bool {
        self.property("label").is_none()
            && self.kind().is_none()
            && self.property("children-display").is_none()
            && self.properties.get("x-kde-title").is_none()
    }

    pub(in crate::global_menu) fn child_nodes(&self) -> Result<Vec<Self>, Error> {
        self.children.iter().map(Self::try_from).collect()
    }

    pub(in crate::global_menu) fn item_kind(&self) -> ItemKind {
        if self.kde_title().is_some() {
            return ItemKind::Group;
        }

        if self.kind() == Some("separator") {
            return ItemKind::Separator;
        }

        // Absent toggle state means "unknown", which reads the same as off.
        let toggled = self
            .properties
            .get("toggle-state")
            .and_then(|value| value.downcast_ref::<i32>().ok())
            == Some(1);

        match self.property("toggle-type") {
            Some("checkmark") => ItemKind::Checkmark { checked: toggled },
            Some("radio") => ItemKind::Radio { selected: toggled },
            _ => ItemKind::Standard,
        }
    }

    /// Formats the first chord the application offers, as `Ctrl+Shift+N`.
    pub(in crate::global_menu) fn shortcut(&self) -> Option<String> {
        let chords = self.properties.get("shortcut")?;
        let chords = chords.downcast_ref::<&zbus::zvariant::Array>().ok()?;
        let first = chords.first()?;
        let keys = first.downcast_ref::<&zbus::zvariant::Array>().ok()?;

        let chord = keys
            .iter()
            .filter_map(|key| key.downcast_ref::<&str>().ok())
            .map(|key| match key {
                "Control" => "Ctrl",
                "Meta" => "Super",
                other => other,
            })
            .collect::<Vec<_>>()
            .join("+");

        (!chord.is_empty()).then_some(chord)
    }
}

impl TryFrom<&OwnedValue> for Node {
    type Error = Error;

    fn try_from(value: &OwnedValue) -> Result<Self, Self::Error> {
        let structure = value
            .downcast_ref::<&Structure>()
            .map_err(Error::DecodeLayout)?;
        let mut fields = structure.fields().iter();
        let id = match fields.next() {
            Some(Value::I32(id)) => *id,
            _ => return Err(Error::InvalidNode),
        };
        let properties = match fields.next() {
            Some(Value::Dict(properties)) => properties
                .iter()
                .filter_map(|(key, value)| {
                    let key = key.downcast_ref::<&str>().ok()?;
                    let value = OwnedValue::try_from(value).ok()?;
                    Some((key.to_owned(), value))
                })
                .collect(),
            _ => return Err(Error::InvalidNode),
        };
        let children = match fields.next() {
            Some(Value::Array(children)) => children
                .iter()
                .map(OwnedValue::try_from)
                .collect::<Result<Vec<_>, _>>()
                .map_err(Error::DecodeLayout)?,
            _ => return Err(Error::InvalidNode),
        };

        Ok(Self {
            id,
            properties,
            children,
        })
    }
}

pub(in crate::global_menu) fn items_from(parent: &Node) -> Result<Vec<Item>, Error> {
    Ok(without_empty_dividers(
        parent
            .child_nodes()?
            .into_iter()
            .filter(Node::is_row)
            .map(Item::from)
            .collect(),
    ))
}

/// Drops separators that do not sit between two real rows.
///
/// Applications pad menus with leading, trailing, and stacked dividers —
/// often because the rows beside them are hidden. A divider with nothing
/// before or after it is not a grouping, it is leftover chrome.
pub(in crate::global_menu) fn dbusmenu_tree(
    root: &Node,
) -> Result<(Menu, HashMap<SectionId, Vec<Item>>), Error> {
    let children = root.child_nodes()?;
    let mut sections = HashMap::new();
    let mut headings = Vec::new();

    for node in children.iter().filter(|node| node.is_menubar_heading()) {
        let id = SectionId::DbusMenu { id: node.id };
        headings.push(Section {
            id: id.clone(),
            label: node.titled().unwrap_or_default(),
            enabled: node.enabled(),
        });
        let items = items_from(node)?;
        dbusmenu_submenus(&items, root, &mut sections)?;
        sections.insert(id, items);
    }

    if headings.is_empty() {
        return dbusmenu_list(root);
    }

    Ok((Menu { sections: headings }, sections))
}

/// Root children are commands, not File/Edit/View. One menu, not one heading
/// per row.
pub(in crate::global_menu) fn dbusmenu_list(
    root: &Node,
) -> Result<(Menu, HashMap<SectionId, Vec<Item>>), Error> {
    let items = items_from(root)?;
    if items.is_empty() {
        return Ok((Menu::default(), HashMap::new()));
    }

    let mut sections = HashMap::new();
    let id = SectionId::DbusMenu { id: root.id };
    dbusmenu_submenus(&items, root, &mut sections)?;
    sections.insert(id.clone(), items);

    Ok((
        Menu {
            sections: vec![Section {
                id,
                label: root.titled().unwrap_or_default(),
                enabled: true,
            }],
        },
        sections,
    ))
}

/// Names a command list that the tree exported without a heading of its own.
pub(in crate::global_menu) fn dbusmenu_submenus(
    items: &[Item],
    root: &Node,
    sections: &mut HashMap<SectionId, Vec<Item>>,
) -> Result<(), Error> {
    for item in items {
        let Some(SectionId::DbusMenu { id }) = item.submenu else {
            continue;
        };
        let submenu = SectionId::DbusMenu { id };
        if sections.contains_key(&submenu) {
            continue;
        }
        let Some(node) = find_by_id(root, id)? else {
            continue;
        };
        let nested = items_from(&node)?;
        dbusmenu_submenus(&nested, root, sections)?;
        sections.insert(submenu, nested);
    }

    Ok(())
}

pub(in crate::global_menu) fn resolve_section(
    root: &Node,
    id: i32,
    path: &[String],
) -> Result<Option<Node>, Error> {
    if let Some(node) = find_by_id(root, id)? {
        return Ok(Some(node));
    }

    at_path(root, path)
}

/// The id to announce: the one we were given, or the node now sitting at the
/// same label path after Firefox rebuilt the tree.
pub(in crate::global_menu) fn destination(
    root: &Node,
    id: i32,
    path: &[String],
) -> Result<i32, Error> {
    if find_by_id(root, id)?.is_some() {
        return Ok(id);
    }

    Ok(at_path(root, path)?.map(|node| node.id).unwrap_or(id))
}

pub(in crate::global_menu) fn find_by_id(root: &Node, id: i32) -> Result<Option<Node>, Error> {
    if root.id == id {
        return Ok(Some(root.clone()));
    }

    for child in root.child_nodes()? {
        if let Some(found) = find_by_id(&child, id)? {
            return Ok(Some(found));
        }
    }

    Ok(None)
}

pub(in crate::global_menu) fn path_to(root: &Node, id: i32) -> Result<Option<Vec<String>>, Error> {
    pub(in crate::global_menu) fn walk(
        node: &Node,
        id: i32,
        path: &mut Vec<String>,
    ) -> Result<bool, Error> {
        if node.id == id {
            return Ok(true);
        }

        for child in node.child_nodes()? {
            path.push(child.label());
            if walk(&child, id, path)? {
                return Ok(true);
            }
            path.pop();
        }

        Ok(false)
    }

    let mut path = Vec::new();
    Ok(walk(root, id, &mut path)?.then_some(path))
}

pub(in crate::global_menu) fn at_path(root: &Node, path: &[String]) -> Result<Option<Node>, Error> {
    if path.is_empty() {
        return Ok(None);
    }

    let mut current = None;
    let mut nodes = root.child_nodes()?;
    for (index, label) in path.iter().enumerate() {
        let Some(node) = nodes.into_iter().find(|child| child.label() == *label) else {
            return Ok(None);
        };
        if index + 1 == path.len() {
            current = Some(node);
            break;
        }
        nodes = node.child_nodes()?;
    }

    Ok(current)
}
