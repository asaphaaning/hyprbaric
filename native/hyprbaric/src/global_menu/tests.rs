use std::collections::{HashMap, HashSet};

use zbus::zvariant::{OwnedValue, Value};

use super::{
    Error, Item, ItemId, ItemKind, Menu, SectionId,
    dbusmenu::tree::{at_path, dbusmenu_tree, destination, items_from, path_to, resolve_section},
    dbusmenu::{DbusMenuEvent, Node},
    discovery::{lineage, menu_for_address, unique_unaddressed},
    endpoint::Endpoint,
    gtk,
    gtk::{
        client::{GtkGroup, GtkLink},
        tree::{gtk_menu_items, gtk_tree, gtk_unfetched_groups, prepend_gtk_app_menu},
    },
    model::{entitle_anonymous_list, strip_mnemonics, without_empty_dividers},
};

fn endpoint(json: &str) -> Endpoint {
    serde_json::from_str(json).expect("endpoint should decode")
}

fn node(id: i32, properties: &[(&str, Value<'static>)]) -> Node {
    Node {
        id,
        properties: properties
            .iter()
            .map(|(key, value)| {
                (
                    (*key).to_owned(),
                    OwnedValue::try_from(value.clone()).expect("property should convert"),
                )
            })
            .collect(),
        children: Vec::new(),
    }
}

fn gtk_entry(
    attributes: &[(&str, Value<'static>)],
    section: Option<(u32, u32)>,
) -> HashMap<String, OwnedValue> {
    let mut entry = attributes
        .iter()
        .map(|(key, value)| {
            (
                (*key).to_owned(),
                OwnedValue::try_from(value.clone()).expect("attribute should convert"),
            )
        })
        .collect::<HashMap<_, _>>();

    if let Some((group, menu)) = section {
        let link = zbus::zvariant::StructureBuilder::new()
            .add_field(group)
            .add_field(menu)
            .build()
            .expect("a section link should build");
        entry.insert(
            ":section".to_owned(),
            OwnedValue::try_from(Value::from(link)).expect("link should convert"),
        );
    }

    entry
}

fn gtk_submenu(label: &str, group: u32, menu: u32) -> HashMap<String, OwnedValue> {
    let mut entry = gtk_entry(&[], None);
    entry.insert(
        "label".to_owned(),
        OwnedValue::try_from(Value::from(label.to_owned())).expect("label should convert"),
    );
    let link = zbus::zvariant::StructureBuilder::new()
        .add_field(group)
        .add_field(menu)
        .build()
        .expect("a submenu link should build");
    entry.insert(
        ":submenu".to_owned(),
        OwnedValue::try_from(Value::from(link)).expect("link should convert"),
    );
    entry
}

fn shortcut(chord: &[&str]) -> Value<'static> {
    let keys = chord
        .iter()
        .map(|key| (*key).to_owned())
        .collect::<Vec<_>>();

    Value::from(vec![keys])
}

#[test]
fn mnemonic_underscores_are_stripped_but_literal_ones_survive() {
    assert_eq!(strip_mnemonics("_File"), "File");
    assert_eq!(strip_mnemonics("Sele_ction"), "Selection");
    assert_eq!(strip_mnemonics("Save __All"), "Save _All");
}

#[test]
fn dbusmenu_events_use_the_protocol_names() {
    assert_eq!(DbusMenuEvent::Opened.as_str(), "opened");
    assert_eq!(DbusMenuEvent::Closed.as_str(), "closed");
    assert_eq!(DbusMenuEvent::Clicked.as_str(), "clicked");
}

#[test]
fn a_window_without_a_menu_is_an_absence_not_a_fault() {
    assert!(Error::NoFocusedWindow.is_absence());
    assert!(Error::NoMenuForFocusedWindow.is_absence());
    assert!(!Error::CompanionUnavailable.is_absence());
    assert!(!Error::InvalidNode.is_absence());
}

#[test]
fn a_row_without_a_label_is_named_rather_than_blank() {
    assert_eq!(node(1, &[]).label(), "Untitled");
    assert_eq!(node(1, &[]).titled(), None);
    assert_eq!(node(1, &[("label", Value::from("_Open"))]).label(), "Open");
}

#[test]
fn a_chord_is_spelled_the_way_the_rest_of_the_bar_spells_one() {
    assert_eq!(
        node(1, &[("shortcut", shortcut(&["Control", "Shift", "N"]))]).shortcut(),
        Some("Ctrl+Shift+N".to_owned())
    );
    assert_eq!(node(1, &[]).shortcut(), None);
}

#[test]
fn toggle_properties_become_the_row_kind_they_describe() {
    let checked = node(
        1,
        &[
            ("toggle-type", Value::from("checkmark")),
            ("toggle-state", Value::from(1i32)),
        ],
    );
    let radio = node(
        1,
        &[
            ("toggle-type", Value::from("radio")),
            ("toggle-state", Value::from(0i32)),
        ],
    );

    assert_eq!(checked.item_kind(), ItemKind::Checkmark { checked: true });
    assert_eq!(radio.item_kind(), ItemKind::Radio { selected: false });
    assert_eq!(node(1, &[]).item_kind(), ItemKind::Standard);
}

#[test]
fn an_unknown_toggle_state_reads_as_off() {
    let unknown = node(
        1,
        &[
            ("toggle-type", Value::from("checkmark")),
            ("toggle-state", Value::from(-1i32)),
        ],
    );

    assert_eq!(unknown.item_kind(), ItemKind::Checkmark { checked: false });
}

#[test]
fn a_row_that_opens_a_menu_leads_there_instead_of_activating() {
    let item = Item::from(node(
        7,
        &[
            ("label", Value::from("Open _Recent")),
            ("children-display", Value::from("submenu")),
        ],
    ));

    assert_eq!(item.submenu, Some(SectionId::DbusMenu { id: 7 }));
    assert_eq!(item.activation, None);
}

#[test]
fn an_ordinary_row_activates_by_its_own_identifier() {
    let item = Item::from(node(9, &[("label", Value::from("_New"))]));

    assert_eq!(item.activation, Some(ItemId::DbusMenu { id: 9 }));
    assert_eq!(item.submenu, None);
}

#[test]
fn a_named_gtk_section_becomes_a_caption_over_its_rows() {
    let groups = vec![
        GtkGroup {
            group: 0,
            menu: 0,
            items: vec![gtk_entry(&[("label", Value::from("Recent"))], Some((0, 1)))],
        },
        GtkGroup {
            group: 0,
            menu: 1,
            items: vec![gtk_entry(&[("label", Value::from("bar.tsx"))], None)],
        },
    ];

    let items = gtk_menu_items(&groups, GtkLink::ROOT, 0, &gtk::Actions::default(), false)
        .expect("menu should read");

    assert_eq!(items.len(), 2);
    assert_eq!(items[0].kind, ItemKind::Group);
    assert_eq!(items[0].label, "Recent");
    assert_eq!(items[1].label, "bar.tsx");
}

#[test]
fn an_unnamed_gtk_section_divides_the_rows_before_it() {
    let groups = vec![
        GtkGroup {
            group: 0,
            menu: 0,
            items: vec![
                gtk_entry(&[("label", Value::from("New"))], None),
                gtk_entry(&[], Some((0, 1))),
            ],
        },
        GtkGroup {
            group: 0,
            menu: 1,
            items: vec![gtk_entry(&[("label", Value::from("Quit"))], None)],
        },
    ];

    let items = gtk_menu_items(&groups, GtkLink::ROOT, 0, &gtk::Actions::default(), false)
        .expect("menu should read");

    assert_eq!(items.len(), 3);
    assert_eq!(items[1].kind, ItemKind::Separator);
    assert_eq!(items[2].label, "Quit");
}

#[test]
fn a_leading_unnamed_gtk_section_adds_no_divider() {
    let groups = vec![
        GtkGroup {
            group: 0,
            menu: 0,
            items: vec![gtk_entry(&[], Some((0, 1)))],
        },
        GtkGroup {
            group: 0,
            menu: 1,
            items: vec![gtk_entry(&[("label", Value::from("New"))], None)],
        },
    ];

    let items = gtk_menu_items(&groups, GtkLink::ROOT, 0, &gtk::Actions::default(), false)
        .expect("menu should read");

    assert_eq!(items.len(), 1);
    assert_eq!(items[0].label, "New");
}

#[test]
fn a_trailing_unnamed_gtk_section_adds_no_divider() {
    let groups = vec![
        GtkGroup {
            group: 0,
            menu: 0,
            items: vec![
                gtk_entry(&[("label", Value::from("New"))], None),
                gtk_entry(&[], Some((0, 1))),
            ],
        },
        GtkGroup {
            group: 0,
            menu: 1,
            items: vec![],
        },
    ];

    let items = gtk_menu_items(&groups, GtkLink::ROOT, 0, &gtk::Actions::default(), false)
        .expect("menu should read");

    assert_eq!(items.len(), 1);
    assert_eq!(items[0].label, "New");
}

#[test]
fn a_separator_neither_activates_nor_opens() {
    let item = Item::from(node(4, &[("type", Value::from("separator"))]));

    assert_eq!(item.kind, ItemKind::Separator);
    assert_eq!(item.activation, None);
    assert_eq!(item.submenu, None);
}

#[test]
fn a_kde_title_is_a_caption_not_a_command() {
    let item = Item::from(node(
        8,
        &[
            ("type", Value::from("separator")),
            ("x-kde-title", Value::from(true)),
            ("label", Value::from("_Recent")),
        ],
    ));

    assert_eq!(item.kind, ItemKind::Group);
    assert_eq!(item.label, "Recent");
    assert!(!item.enabled);
    assert_eq!(item.activation, None);
    assert_eq!(item.submenu, None);
}

#[test]
fn a_string_kde_title_without_a_label_is_still_a_caption() {
    let item = Item::from(node(8, &[("x-kde-title", Value::from("Sessions"))]));

    assert_eq!(item.kind, ItemKind::Group);
    assert_eq!(item.label, "Sessions");
    assert_eq!(item.activation, None);
}

#[test]
fn a_kde_title_flag_without_text_stays_a_separator() {
    let item = Item::from(node(
        4,
        &[
            ("type", Value::from("separator")),
            ("x-kde-title", Value::from(true)),
        ],
    ));

    assert_eq!(item.kind, ItemKind::Separator);
    assert_eq!(item.label, "");
}

#[test]
fn kde_titles_are_kept_among_the_rows() {
    let parent = Node {
        id: 1,
        properties: HashMap::new(),
        children: vec![
            encoded(2, "New", Vec::new()),
            encoded_with(
                3,
                &[
                    ("type", Value::from("separator")),
                    ("x-kde-title", Value::from(true)),
                    ("label", Value::from("Recent")),
                ],
                Vec::new(),
            ),
            encoded(4, "notes.txt", Vec::new()),
        ],
    };

    let items = items_from(&parent).expect("rows should decode");

    assert_eq!(
        items
            .iter()
            .map(|item| (item.label.as_str(), item.kind))
            .collect::<Vec<_>>(),
        [
            ("New", ItemKind::Standard),
            ("Recent", ItemKind::Group),
            ("notes.txt", ItemKind::Standard),
        ]
    );
}

#[test]
fn empty_dividers_are_not_kept() {
    let row = |label: &str| Item {
        label: label.to_owned(),
        enabled: true,
        kind: ItemKind::Standard,
        shortcut: None,
        activation: None,
        submenu: None,
    };
    let divider = Item {
        label: String::new(),
        enabled: false,
        kind: ItemKind::Separator,
        shortcut: None,
        activation: None,
        submenu: None,
    };

    let compacted = without_empty_dividers(vec![
        divider.clone(),
        row("Sidebar"),
        divider.clone(),
        divider.clone(),
        row("Zoom"),
        divider,
    ]);

    assert_eq!(compacted.len(), 3);
    assert_eq!(compacted[0].label, "Sidebar");
    assert_eq!(compacted[1].kind, ItemKind::Separator);
    assert_eq!(compacted[2].label, "Zoom");
}

#[test]
fn a_menu_of_only_dividers_is_empty() {
    let divider = Item {
        label: String::new(),
        enabled: false,
        kind: ItemKind::Separator,
        shortcut: None,
        activation: None,
        submenu: None,
    };

    assert!(without_empty_dividers(vec![divider.clone(), divider]).is_empty());
}

#[test]
fn a_companion_x11_record_is_not_a_menu() {
    let endpoint: Endpoint = serde_json::from_str(r#"{"kind":"x11","address":"0xabc","xid":4242}"#)
        .expect("an X11 association should decode");

    assert!(matches!(endpoint, Endpoint::X11 { .. }));
    assert_eq!(endpoint.address(), Some("0xabc"));
    assert_eq!(endpoint.xid(), Some(4242));
    assert!(!endpoint.exposes_menu());
}

#[test]
fn a_legacy_dbusmenu_record_still_exposes_a_menu() {
    let decoded = endpoint(r#"{"address":"0xabc","service":":1.9","path":"/MenuBar/1"}"#);

    assert!(matches!(decoded, Endpoint::DbusMenu { .. }));
    assert!(decoded.exposes_menu());
}

#[test]
fn a_gtk_record_keeps_a_separate_application_menu_path() {
    let decoded = endpoint(
        r#"{"kind":"gtk","service":":1.10","path":"/menus/menubar","app_menu_path":"/menus/appmenu"}"#,
    );

    assert_eq!(decoded.path(), "/menus/menubar");
    assert_eq!(decoded.app_menu_path(), Some("/menus/appmenu"));
}

#[test]
fn a_menu_is_chosen_by_the_focused_window_address() {
    let endpoints = vec![
        endpoint(r#"{"kind":"gtk","service":":1.10","path":"/menus/menubar"}"#),
        endpoint(r#"{"kind":"dbusmenu","address":"0xabc","service":":1.9","path":"/MenuBar/1"}"#),
    ];

    let found = menu_for_address(&endpoints, "0xabc").expect("addressed menu should match");
    assert_eq!(found.service(), ":1.9");
}

#[test]
fn a_parent_record_is_not_a_menu() {
    let endpoint: Endpoint =
        serde_json::from_str(r#"{"kind":"parent","address":"0xdialog","parent":"0xwriter"}"#)
            .expect("a parent link should decode");

    assert!(matches!(endpoint, Endpoint::Parent { .. }));
    assert_eq!(endpoint.address(), Some("0xdialog"));
    assert_eq!(endpoint.parent(), Some("0xwriter"));
    assert!(!endpoint.exposes_menu());
}

#[test]
fn a_dialog_uses_the_mapped_parent_menu() {
    let endpoints = vec![
        endpoint(r#"{"kind":"parent","address":"0xdialog","parent":"0xwriter"}"#),
        endpoint(
            r#"{"kind":"dbusmenu","address":"0xwriter","service":":1.9","path":"/MenuBar/1"}"#,
        ),
    ];

    assert!(menu_for_address(&endpoints, "0xdialog").is_none());
    assert_eq!(lineage("0xdialog", &endpoints), ["0xdialog", "0xwriter"]);
    let found = lineage("0xdialog", &endpoints)
        .into_iter()
        .find_map(|window| menu_for_address(&endpoints, window))
        .expect("the writer menu should match");
    assert_eq!(found.service(), ":1.9");
}

#[test]
fn a_parent_cycle_does_not_loop() {
    let endpoints = vec![
        endpoint(r#"{"kind":"parent","address":"0xa","parent":"0xb"}"#),
        endpoint(r#"{"kind":"parent","address":"0xb","parent":"0xa"}"#),
    ];

    assert_eq!(lineage("0xa", &endpoints), ["0xa", "0xb"]);
}

#[test]
fn a_window_without_a_parent_stays_itself() {
    let endpoints = vec![endpoint(
        r#"{"kind":"dbusmenu","address":"0xwriter","service":":1.9","path":"/MenuBar/1"}"#,
    )];

    assert_eq!(lineage("0xwriter", &endpoints), ["0xwriter"]);
}

#[test]
fn an_addressless_menu_matches_when_it_is_the_only_one_for_the_process() {
    let endpoints = vec![
        endpoint(r#"{"kind":"gtk","service":":1.10","path":"/menus/menubar"}"#),
        endpoint(r#"{"kind":"dbusmenu","address":"0xabc","service":":1.9","path":"/MenuBar/1"}"#),
    ];

    let found = unique_unaddressed(&endpoints, 4242, |service| {
        (service == ":1.10").then_some(4242)
    })
    .expect("the gtk export should match");
    assert_eq!(found.service(), ":1.10");
    assert_eq!(found.path(), "/menus/menubar");
}

#[test]
fn two_addressless_menus_for_the_same_process_are_not_guessed() {
    let endpoints = vec![
        endpoint(r#"{"kind":"gtk","service":":1.10","path":"/win1"}"#),
        endpoint(r#"{"kind":"gtk","service":":1.11","path":"/win2"}"#),
    ];

    assert!(unique_unaddressed(&endpoints, 4242, |_| Some(4242)).is_none());
}

#[test]
fn an_addressed_menu_is_not_used_as_a_process_fallback() {
    let endpoints = vec![endpoint(
        r#"{"kind":"gtk","address":"0xother","service":":1.10","path":"/menus/menubar"}"#,
    )];

    assert!(unique_unaddressed(&endpoints, 4242, |_| Some(4242)).is_none());
}

fn encoded(id: i32, label: &str, children: Vec<OwnedValue>) -> OwnedValue {
    let mut properties = HashMap::<String, Value<'_>>::new();
    properties.insert("label".to_owned(), Value::from(label.to_owned()));
    OwnedValue::try_from(Value::from((id, properties, children)))
        .expect("a D-BusMenu node should encode")
}

fn encoded_separator(id: i32) -> OwnedValue {
    encoded_with(id, &[("type", Value::from("separator"))], Vec::new())
}

fn encoded_submenu(id: i32, label: &str) -> OwnedValue {
    let mut properties = HashMap::<String, Value<'_>>::new();
    properties.insert("label".to_owned(), Value::from(label.to_owned()));
    properties.insert("children-display".to_owned(), Value::from("submenu"));
    OwnedValue::try_from(Value::from((id, properties, Vec::<OwnedValue>::new())))
        .expect("a D-BusMenu submenu should encode")
}

fn encoded_with(
    id: i32,
    properties: &[(&'static str, Value<'static>)],
    children: Vec<OwnedValue>,
) -> OwnedValue {
    let mut map = HashMap::<String, Value<'_>>::new();
    for (key, value) in properties {
        map.insert((*key).to_owned(), value.clone());
    }
    OwnedValue::try_from(Value::from((id, map, children))).expect("a D-BusMenu node should encode")
}

fn tree(id: i32, label: &str, children: Vec<OwnedValue>) -> Node {
    Node {
        id,
        properties: {
            let mut properties = HashMap::new();
            properties.insert(
                "label".to_owned(),
                OwnedValue::try_from(Value::from(label)).expect("label should encode"),
            );
            properties
        },
        children,
    }
}

#[test]
fn a_heading_is_found_by_label_after_its_identifier_changes() {
    let before = tree(
        0,
        "",
        vec![encoded(5, "Edit", vec![encoded(6, "Undo", Vec::new())])],
    );
    let after = tree(
        0,
        "",
        vec![encoded(50, "Edit", vec![encoded(60, "Undo", Vec::new())])],
    );

    let path = path_to(&before, 5)
        .expect("path should walk")
        .expect("id 5 exists");
    assert_eq!(path, vec!["Edit"]);

    let section = resolve_section(&after, 5, &path)
        .expect("resolve should walk")
        .expect("Edit still exists");
    assert_eq!(section.id, 50);

    let items = items_from(&section).expect("rows should decode");
    assert_eq!(items.len(), 1);
    assert_eq!(items[0].label, "Undo");
}

#[test]
fn a_stale_heading_announces_the_live_identifier() {
    let after = tree(
        0,
        "",
        vec![encoded(50, "Edit", vec![encoded(60, "Undo", Vec::new())])],
    );

    assert_eq!(
        destination(&after, 5, &["Edit".to_owned()]).expect("destination"),
        50
    );
    assert_eq!(
        destination(&after, 50, &["Edit".to_owned()]).expect("still live"),
        50
    );
}

#[test]
fn a_stale_row_activates_at_the_live_identifier() {
    let after = tree(
        0,
        "",
        vec![encoded(
            50,
            "View",
            vec![encoded(60, "Actual Size", Vec::new())],
        )],
    );

    assert_eq!(
        destination(&after, 6, &["View".to_owned(), "Actual Size".to_owned()])
            .expect("destination"),
        60
    );
}

#[test]
fn an_unlabeled_dbusmenu_placeholder_is_not_a_row() {
    let mut edit = node(5, &[("label", Value::from("Edit"))]);
    edit.children.push(
        OwnedValue::try_from(Value::from((
            7i32,
            HashMap::<String, Value<'_>>::new(),
            Vec::<OwnedValue>::new(),
        )))
        .expect("placeholder should encode"),
    );

    assert!(items_from(&edit).expect("rows should decode").is_empty());
}

#[test]
fn a_nested_path_walks_into_a_submenu() {
    let root = tree(
        0,
        "",
        vec![encoded(
            1,
            "File",
            vec![encoded(
                2,
                "Recent",
                vec![encoded(3, "notes.txt", Vec::new())],
            )],
        )],
    );

    let path = path_to(&root, 2)
        .expect("path should walk")
        .expect("Recent exists");
    assert_eq!(path, vec!["File", "Recent"]);
    let recent = at_path(&root, &path)
        .expect("walk should succeed")
        .expect("Recent exists");
    assert_eq!(recent.id, 2);
    assert_eq!(
        items_from(&recent).expect("rows should decode")[0].label,
        "notes.txt"
    );
}

#[test]
fn a_dbusmenu_tree_caches_every_heading_and_its_rows() {
    let root = tree(
        0,
        "",
        vec![
            encoded(1, "File", vec![encoded(2, "New", Vec::new())]),
            encoded(3, "Edit", vec![encoded(4, "Undo", Vec::new())]),
        ],
    );

    let (menu, sections) = dbusmenu_tree(&root).expect("tree should walk");

    assert_eq!(
        menu.sections
            .iter()
            .map(|section| section.label.as_str())
            .collect::<Vec<_>>(),
        ["File", "Edit"]
    );
    assert_eq!(sections[&SectionId::DbusMenu { id: 1 }][0].label, "New");
    assert_eq!(sections[&SectionId::DbusMenu { id: 3 }][0].label, "Undo");
}

#[test]
fn a_menubar_heading_is_a_labeled_submenu() {
    let root = tree(
        0,
        "",
        vec![
            encoded_submenu(1, "File"),
            encoded(2, "New Item", Vec::new()),
            encoded_separator(3),
            encoded_with(
                4,
                &[("children-display", Value::from("submenu"))],
                Vec::new(),
            ),
        ],
    );

    let (menu, _) = dbusmenu_tree(&root).expect("tree should walk");

    assert_eq!(
        menu.sections
            .iter()
            .map(|section| section.label.as_str())
            .collect::<Vec<_>>(),
        ["File"]
    );
}

#[test]
fn a_command_list_at_the_root_is_one_menu() {
    let root = tree(
        0,
        "",
        vec![
            encoded(1, "New Item", Vec::new()),
            encoded_separator(2),
            encoded(3, "Import…", Vec::new()),
            encoded_with(
                4,
                &[("children-display", Value::from("submenu"))],
                Vec::new(),
            ),
            encoded(5, "Zoom", Vec::new()),
        ],
    );

    let (menu, sections) = dbusmenu_tree(&root).expect("tree should walk");

    assert_eq!(menu.sections.len(), 1);
    assert_eq!(menu.sections[0].id, SectionId::DbusMenu { id: 0 });
    assert!(menu.sections[0].label.is_empty());
    assert_eq!(
        sections[&SectionId::DbusMenu { id: 0 }]
            .iter()
            .map(|item| (item.label.as_str(), item.kind))
            .collect::<Vec<_>>(),
        [
            ("New Item", ItemKind::Standard),
            ("", ItemKind::Separator),
            ("Import…", ItemKind::Standard),
            ("Zoom", ItemKind::Standard),
        ]
    );
}

#[test]
fn an_anonymous_list_takes_the_window_title() {
    let mut menu = Menu {
        sections: vec![super::Section {
            id: SectionId::DbusMenu { id: 0 },
            label: String::new(),
            enabled: true,
        }],
    };

    entitle_anonymous_list(&mut menu, "1Password".to_owned());

    assert_eq!(menu.sections[0].label, "1Password");
}

#[test]
fn a_gtk_command_list_at_the_root_is_one_menu() {
    let groups = vec![GtkGroup {
        group: 0,
        menu: 0,
        items: vec![
            gtk_entry(&[("label", Value::from("New Item"))], None),
            gtk_entry(&[], None),
            gtk_entry(&[("label", Value::from("Import…"))], None),
        ],
    }];

    let (menu, sections) = gtk_tree(&groups, &gtk::Actions::default()).expect("tree should walk");

    assert_eq!(menu.sections.len(), 1);
    assert_eq!(menu.sections[0].id, SectionId::Gtk { group: 0, menu: 0 });
    assert_eq!(
        sections[&SectionId::Gtk { group: 0, menu: 0 }]
            .iter()
            .map(|item| item.label.as_str())
            .collect::<Vec<_>>(),
        ["New Item", "Import…"]
    );
}

#[test]
fn a_gtk_menubar_still_uses_labeled_submenus() {
    let groups = vec![
        GtkGroup {
            group: 0,
            menu: 0,
            items: vec![
                gtk_submenu("File", 0, 1),
                gtk_entry(&[("label", Value::from("New Item"))], None),
            ],
        },
        GtkGroup {
            group: 0,
            menu: 1,
            items: vec![gtk_entry(&[("label", Value::from("New"))], None)],
        },
    ];

    let (menu, sections) = gtk_tree(&groups, &gtk::Actions::default()).expect("tree should walk");

    assert_eq!(
        menu.sections
            .iter()
            .map(|section| section.label.as_str())
            .collect::<Vec<_>>(),
        ["File"]
    );
    assert_eq!(
        sections[&SectionId::Gtk { group: 0, menu: 1 }][0].label,
        "New"
    );
}

#[test]
fn a_gtk_app_menu_is_a_leading_heading_beside_the_menubar() {
    let menubar = vec![
        GtkGroup {
            group: 0,
            menu: 0,
            items: vec![gtk_submenu("File", 0, 1), gtk_submenu("Edit", 0, 2)],
        },
        GtkGroup {
            group: 0,
            menu: 1,
            items: vec![gtk_entry(&[("label", Value::from("New"))], None)],
        },
        GtkGroup {
            group: 0,
            menu: 2,
            items: vec![gtk_entry(&[("label", Value::from("Copy"))], None)],
        },
    ];
    let app_menu = vec![GtkGroup {
        group: 0,
        menu: 0,
        items: vec![
            gtk_entry(&[("label", Value::from("About"))], None),
            gtk_entry(&[("label", Value::from("Quit"))], None),
        ],
    }];

    let (headings, sections) =
        gtk_tree(&menubar, &gtk::Actions::default()).expect("menubar should walk");
    let (menu, sections) = prepend_gtk_app_menu(
        headings,
        sections,
        &app_menu,
        &gtk::Actions::default(),
        "Writer".to_owned(),
    )
    .expect("app menu should prepend");

    assert_eq!(
        menu.sections
            .iter()
            .map(|section| section.label.as_str())
            .collect::<Vec<_>>(),
        ["Writer", "File", "Edit"]
    );
    assert_eq!(
        menu.sections[0].id,
        SectionId::GtkAppMenu { group: 0, menu: 0 }
    );
    assert_eq!(menu.sections[1].id, SectionId::Gtk { group: 0, menu: 1 });
    assert_eq!(
        sections[&SectionId::GtkAppMenu { group: 0, menu: 0 }]
            .iter()
            .map(|item| item.label.as_str())
            .collect::<Vec<_>>(),
        ["About", "Quit"]
    );
    assert_eq!(
        sections[&SectionId::Gtk { group: 0, menu: 1 }][0].label,
        "New"
    );
}

#[test]
fn an_app_menu_row_keeps_app_menu_section_ids() {
    let row = gtk::item(&gtk_submenu("About", 0, 1), &gtk::Actions::default(), true);

    assert_eq!(
        row.submenu,
        Some(SectionId::GtkAppMenu { group: 0, menu: 1 })
    );
}

#[test]
fn a_gtk_submenu_in_another_group_is_fetched_next() {
    let groups = vec![GtkGroup {
        group: 0,
        menu: 0,
        items: vec![gtk_submenu("File", 1, 0), gtk_submenu("Edit", 2, 0)],
    }];

    let extra = gtk_unfetched_groups(&groups, &HashSet::from([0]));
    let mut extra = extra;
    extra.sort_unstable();
    assert_eq!(extra, [1, 2]);
}

#[test]
fn a_gtk_menubar_in_another_group_still_names_file() {
    let groups = vec![
        GtkGroup {
            group: 0,
            menu: 0,
            items: vec![gtk_submenu("File", 1, 0), gtk_submenu("Edit", 2, 0)],
        },
        GtkGroup {
            group: 1,
            menu: 0,
            items: vec![gtk_entry(&[("label", Value::from("New"))], None)],
        },
        GtkGroup {
            group: 2,
            menu: 0,
            items: vec![gtk_entry(&[("label", Value::from("Undo"))], None)],
        },
    ];

    let (menu, _) = gtk_tree(&groups, &gtk::Actions::default()).expect("tree should walk");
    assert_eq!(
        menu.sections
            .iter()
            .map(|section| section.label.as_str())
            .collect::<Vec<_>>(),
        ["File", "Edit"]
    );
}

#[test]
fn a_gtk_sectioned_menubar_still_names_file() {
    let groups = vec![
        GtkGroup {
            group: 0,
            menu: 0,
            items: vec![gtk_entry(&[], Some((0, 1))), gtk_entry(&[], Some((0, 2)))],
        },
        GtkGroup {
            group: 0,
            menu: 2,
            items: vec![gtk_entry(&[], Some((0, 3)))],
        },
        GtkGroup {
            group: 0,
            menu: 3,
            items: vec![gtk_submenu("File", 0, 4), gtk_submenu("Edit", 0, 5)],
        },
        GtkGroup {
            group: 0,
            menu: 4,
            items: vec![gtk_entry(&[("label", Value::from("New"))], None)],
        },
        GtkGroup {
            group: 0,
            menu: 5,
            items: vec![gtk_entry(&[("label", Value::from("Undo"))], None)],
        },
    ];

    let (menu, _) = gtk_tree(&groups, &gtk::Actions::default()).expect("tree should walk");
    assert_eq!(
        menu.sections
            .iter()
            .map(|section| section.label.as_str())
            .collect::<Vec<_>>(),
        ["File", "Edit"]
    );
}
