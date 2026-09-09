//! GTK menu links and recursive projection into domain rows.
use super::client::{GtkGroup, GtkLink};
use crate::global_menu::{
    Error, Item, ItemKind, Menu, Section, SectionId,
    model::{entitle_anonymous_list, strip_mnemonics, without_empty_dividers},
};
use std::collections::{HashMap, HashSet};
use zbus::zvariant::{OwnedValue, Structure, Value};
pub(in crate::global_menu) fn gtk_tree(
    groups: &[GtkGroup],
    actions: &super::Actions,
) -> Result<(Menu, HashMap<SectionId, Vec<Item>>), Error> {
    let mut sections = HashMap::new();
    let mut headings = Vec::new();
    gtk_collect_headings(
        groups,
        GtkLink::ROOT,
        0,
        actions,
        &mut headings,
        &mut sections,
    )?;

    if headings.is_empty() {
        return gtk_list(groups, actions, false);
    }

    Ok((Menu { sections: headings }, sections))
}

/// One GTK application menu as a single titled heading in front of the menubar.
///
/// GTK3 can publish both. They are different `org.gtk.Menus` objects that both
/// start at `(group=0, menu=0)`, so the app-menu rows keep [`SectionId::GtkAppMenu`].
pub(in crate::global_menu) fn prepend_gtk_app_menu(
    mut menubar: Menu,
    mut sections: HashMap<SectionId, Vec<Item>>,
    app_groups: &[GtkGroup],
    actions: &super::Actions,
    title: String,
) -> Result<(Menu, HashMap<SectionId, Vec<Item>>), Error> {
    let (mut app_menu, app_sections) = gtk_list(app_groups, actions, true)?;
    if app_menu.sections.is_empty() {
        return Ok((menubar, sections));
    }

    entitle_anonymous_list(&mut app_menu, title);
    menubar.sections.splice(0..0, app_menu.sections);
    sections.extend(app_sections);
    Ok((menubar, sections))
}

/// Menubar headings, walking `:section` wrappers GIMP and LibreOffice use.
pub(in crate::global_menu) fn gtk_collect_headings(
    groups: &[GtkGroup],
    link: GtkLink,
    depth: u8,
    actions: &super::Actions,
    headings: &mut Vec<Section>,
    sections: &mut HashMap<SectionId, Vec<Item>>,
) -> Result<(), Error> {
    const MAX_DEPTH: u8 = 8;

    let Ok(root) = gtk_group(groups, link) else {
        return Ok(());
    };

    for item in &root.items {
        if let Some(section) = gtk_link(item, ":section") {
            if depth < MAX_DEPTH {
                gtk_collect_headings(groups, section, depth + 1, actions, headings, sections)?;
            }
            continue;
        }

        let Some(link) = gtk_link(item, ":submenu") else {
            continue;
        };
        let Some(label) = gtk_optional_label(item) else {
            continue;
        };
        let id = SectionId::gtk(link.group, link.menu, false);
        headings.push(Section {
            id: id.clone(),
            label,
            enabled: true,
        });
        gtk_cache(groups, link, actions, sections, false)?;
    }

    Ok(())
}

pub(in crate::global_menu) fn gtk_list(
    groups: &[GtkGroup],
    actions: &super::Actions,
    app_menu: bool,
) -> Result<(Menu, HashMap<SectionId, Vec<Item>>), Error> {
    let items = gtk_menu_items(groups, GtkLink::ROOT, 0, actions, app_menu)?;
    if items.is_empty() {
        return Ok((Menu::default(), HashMap::new()));
    }

    let mut sections = HashMap::new();
    let id = SectionId::gtk(0, 0, app_menu);
    for item in &items {
        if let Some((group, menu, nested)) = item.submenu.as_ref().and_then(SectionId::as_gtk) {
            gtk_cache(
                groups,
                GtkLink { group, menu },
                actions,
                &mut sections,
                nested,
            )?;
        }
    }
    sections.insert(id.clone(), items);

    Ok((
        Menu {
            sections: vec![Section {
                id,
                label: String::new(),
                enabled: true,
            }],
        },
        sections,
    ))
}

pub(in crate::global_menu) fn gtk_cache(
    groups: &[GtkGroup],
    link: GtkLink,
    actions: &super::Actions,
    sections: &mut HashMap<SectionId, Vec<Item>>,
    app_menu: bool,
) -> Result<(), Error> {
    let id = SectionId::gtk(link.group, link.menu, app_menu);
    if sections.contains_key(&id) {
        return Ok(());
    }

    let items = gtk_menu_items(groups, link, 0, actions, app_menu)?;
    for item in &items {
        if let Some((group, menu, nested)) = item.submenu.as_ref().and_then(SectionId::as_gtk) {
            gtk_cache(groups, GtkLink { group, menu }, actions, sections, nested)?;
        }
    }
    sections.insert(id, items);

    Ok(())
}

/// Groups a `:submenu` or `:section` names that have not been Start'd yet.
pub(in crate::global_menu) fn gtk_unfetched_groups(
    groups: &[GtkGroup],
    subscribed: &HashSet<u32>,
) -> Vec<u32> {
    let mut extra = HashSet::new();
    for group in groups {
        for item in &group.items {
            for relation in [":submenu", ":section"] {
                if let Some(link) = gtk_link(item, relation)
                    && !subscribed.contains(&link.group)
                {
                    extra.insert(link.group);
                }
            }
        }
    }
    extra.into_iter().collect()
}

pub(in crate::global_menu) fn gtk_group(
    groups: &[GtkGroup],
    link: GtkLink,
) -> Result<&GtkGroup, Error> {
    groups
        .iter()
        .find(|group| group.group == link.group && group.menu == link.menu)
        .ok_or(Error::MissingGtkGroup {
            group: link.group,
            menu: link.menu,
        })
}

pub(in crate::global_menu) fn gtk_label(item: &HashMap<String, OwnedValue>) -> String {
    gtk_optional_label(item).unwrap_or_else(|| "Untitled".to_owned())
}

pub(in crate::global_menu) fn gtk_optional_label(
    item: &HashMap<String, OwnedValue>,
) -> Option<String> {
    item.get("label")
        .and_then(|value| value.downcast_ref::<&str>().ok())
        .map(strip_mnemonics)
        .filter(|label| !label.is_empty())
}

pub(in crate::global_menu) fn gtk_link(
    item: &HashMap<String, OwnedValue>,
    name: &str,
) -> Option<GtkLink> {
    let structure = item.get(name)?.downcast_ref::<&Structure>().ok()?;
    let mut fields = structure.fields().iter();
    let group = match fields.next()? {
        Value::U32(group) => *group,
        _ => return None,
    };
    let menu = match fields.next()? {
        Value::U32(menu) => *menu,
        _ => return None,
    };

    Some(GtkLink { group, menu })
}

pub(in crate::global_menu) fn gtk_menu_items(
    groups: &[GtkGroup],
    link: GtkLink,
    depth: u8,
    actions: &super::Actions,
    app_menu: bool,
) -> Result<Vec<Item>, Error> {
    // Sections nest, and a malformed menu could link itself. The protocol has
    // no notion of depth, so the reader supplies the bound.
    const MAX_DEPTH: u8 = 8;

    let Ok(group) = gtk_group(groups, link) else {
        return Ok(Vec::new());
    };

    let mut items = Vec::new();
    for entry in &group.items {
        let Some(section) = gtk_link(entry, ":section") else {
            if gtk_optional_label(entry).is_none() && gtk_link(entry, ":submenu").is_none() {
                continue;
            }
            items.push(super::item(entry, actions, app_menu));
            continue;
        };

        if depth >= MAX_DEPTH {
            continue;
        }

        match gtk_optional_label(entry) {
            Some(label) => items.push(Item {
                label,
                enabled: false,
                kind: ItemKind::Group,
                shortcut: None,
                activation: None,
                submenu: None,
            }),
            None if !items.is_empty() => items.push(Item {
                label: String::new(),
                enabled: false,
                kind: ItemKind::Separator,
                shortcut: None,
                activation: None,
                submenu: None,
            }),
            None => {}
        }

        items.extend(gtk_menu_items(
            groups,
            section,
            depth + 1,
            actions,
            app_menu,
        )?);
    }

    Ok(without_empty_dividers(items))
}
