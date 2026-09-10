import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:riverpod/misc.dart' show Override;

import '../use_cases/notifications/notification_fixtures.dart';
import '../use_cases/power/power_fixtures.dart';
import '../use_cases/settings/settings_fixtures.dart';
import '../use_cases/tray/tray_fixtures.dart';
import 'audio_fixtures.dart';

/// Where one docs-bar menu row leads.
///
/// [target] is site-relative: `http` targets leave the site, `#` targets are
/// in-page anchors, and everything else is a docs route. [resolve] joins the
/// target onto the site base URL the host page reports.
enum DocsDestination {
  home(itemId: 101, label: 'hyprbaric home', target: '/'),
  getStarted(itemId: 102, label: 'Get started', target: '/docs/intro'),
  installation(
    itemId: 103,
    label: 'Installation',
    target: '/docs/installation',
  ),
  configuration(
    itemId: 104,
    label: 'Configuration',
    target: '/docs/configuration',
  ),
  shortcuts(itemId: 105, label: 'Shortcuts', target: '/docs/shortcuts'),
  globalMenu(itemId: 106, label: 'Global menu', target: '/docs/global-menu'),
  troubleshooting(
    itemId: 107,
    label: 'Troubleshooting',
    target: '/docs/troubleshooting',
  ),
  modules(itemId: 108, label: 'Modules', target: '/#modules'),
  configurator(itemId: 109, label: 'Configuration', target: '/#config'),
  browseDocs(itemId: 110, label: 'Browse all docs', target: '/docs/intro'),
  github(
    itemId: 111,
    label: 'GitHub',
    target: 'https://github.com/asaphaaning/hyprbaric',
  ),
  releases(
    itemId: 112,
    label: 'Releases',
    target: 'https://github.com/asaphaaning/hyprbaric/releases/latest',
  ),
  issues(
    itemId: 113,
    label: 'Issues',
    target: 'https://github.com/asaphaaning/hyprbaric/issues',
  );

  const DocsDestination({
    required this.itemId,
    required this.label,
    required this.target,
  });

  /// The stable native row id the fixture assigns this destination.
  final int itemId;

  /// The row text in the open menu.
  final String label;

  /// The site-relative navigation target.
  final String target;

  /// The destination activated as [id], or null for foreign rows.
  static DocsDestination? byItemId(GlobalMenuItemId id) {
    if (id is! GlobalMenuItemIdDbusMenu) {
      return null;
    }
    for (final DocsDestination destination in values) {
      if (destination.itemId == id.id) {
        return destination;
      }
    }
    return null;
  }

  /// Joins [target] onto [baseUrl], which ends with a `/`.
  ///
  /// ```dart
  /// expect(
  ///   DocsDestination.getStarted.resolve('/hyprbaric/'),
  ///   '/hyprbaric/docs/intro',
  /// );
  /// ```
  String resolve(String baseUrl) {
    if (target.startsWith('http')) {
      return target;
    }
    final String root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$root$target';
  }
}

/// The focused window the docs bar pretends is focused.
///
/// A single `hyprbaric` identity keeps the center cluster compact: the app
/// name doubles as the title, so the bar shows one centered wordmark that the
/// preview wires home.
abstract final class DocsBarFixtures {
  static const FocusedWindowStatus focusedWindow = FocusedWindowStatus(
    appName: 'hyprbaric',
    title: 'hyprbaric',
    hostname: 'hyprbaric',
    monitors: <MonitorFocusedWindowStatus>[],
  );

  static const WorkspaceStatus workspace = WorkspaceStatus(
    id: 1,
    name: '1',
    isSpecial: false,
    occupiedWorkspaceIds: <int>[1, 2],
    monitors: <MonitorWorkspaceStatus>[],
  );

  static const ClockStatus clock = ClockStatus(
    timeLabel: '08:18',
    dateLabel: 'Sun, Aug 30',
    monthLabel: 'August 2026',
    weekNumber: 35,
    utcOffset: 'UTC+02:00',
    days: <CalendarDay>[],
  );

  static const CaffeineStatus caffeine = CaffeineStatusAvailable(
    enabled: false,
  );

  static const RecordingStatus recording = RecordingStatusIdle();

  static const SetupStatus setup = SetupStatus(state: SetupState.complete);

  static const PortalStatus portal = PortalStatus(
    colorScheme: PortalColorScheme.preferDark,
  );
}

/// Documentation navigation dressed as an application menu.
///
/// Headings mirror the docs sidebar categories; rows carry the stable
/// [DocsDestination.itemId] the preview dispatcher routes on.
abstract final class DocsMenuFixtures {
  static const GlobalMenuSectionId docs = GlobalMenuSectionIdDbusMenu(id: 11);
  static const GlobalMenuSectionId site = GlobalMenuSectionIdDbusMenu(id: 12);
  static const GlobalMenuSectionId project = GlobalMenuSectionIdDbusMenu(
    id: 13,
  );

  static final GlobalMenuSession session = GlobalMenuSession(
    generation: Uint64(BigInt.one),
    window: 'docs',
  );

  static GlobalMenuAddress address(GlobalMenuSectionId id) =>
      GlobalMenuAddress(session: session, section: id);

  static final GlobalMenuStatus headings = GlobalMenuStatus(
    session: session,
    sections: <GlobalMenuSection>[
      const GlobalMenuSection(id: docs, label: 'Docs', enabled: true),
      const GlobalMenuSection(id: site, label: 'Site', enabled: true),
      const GlobalMenuSection(id: project, label: 'Project', enabled: true),
    ],
    message: null,
  );

  static const GlobalMenuItem separator = GlobalMenuItem(
    label: '',
    enabled: false,
    kind: GlobalMenuItemKindSeparator(),
    shortcut: null,
    activation: null,
    submenu: null,
  );

  static GlobalMenuItem group(String label) {
    return GlobalMenuItem(
      label: label,
      enabled: false,
      kind: const GlobalMenuItemKindGroup(),
      shortcut: null,
      activation: null,
      submenu: null,
    );
  }

  static GlobalMenuItem link(DocsDestination destination) {
    return GlobalMenuItem(
      label: destination.label,
      enabled: true,
      kind: const GlobalMenuItemKindStandard(),
      shortcut: null,
      activation: GlobalMenuItemIdDbusMenu(id: destination.itemId),
      submenu: null,
    );
  }

  static final List<GlobalMenuItem> docsItems = <GlobalMenuItem>[
    group('Get started'),
    link(DocsDestination.getStarted),
    link(DocsDestination.installation),
    group('Configuration'),
    link(DocsDestination.configuration),
    link(DocsDestination.shortcuts),
    link(DocsDestination.globalMenu),
    group('Reference'),
    link(DocsDestination.troubleshooting),
  ];

  static final List<GlobalMenuItem> siteItems = <GlobalMenuItem>[
    link(DocsDestination.modules),
    link(DocsDestination.configurator),
    separator,
    link(DocsDestination.browseDocs),
  ];

  static final List<GlobalMenuItem> projectItems = <GlobalMenuItem>[
    link(DocsDestination.github),
    link(DocsDestination.releases),
    link(DocsDestination.issues),
  ];

  static GlobalMenuSectionStatus section(
    GlobalMenuSectionId id,
    List<GlobalMenuItem> items,
  ) {
    return GlobalMenuSectionStatus(
      session: session,
      section: id,
      items: items,
      message: null,
    );
  }

  /// Pins docs headings and the panels the preview can hang.
  static List<Override> providers() {
    return <Override>[
      globalMenuStatusProvider.overrideWith(
        (Ref ref) => Stream<GlobalMenuStatus>.value(headings),
      ),
      globalMenuSectionProvider(address(docs)).overrideWith(
        (Ref ref) =>
            Stream<GlobalMenuSectionStatus>.value(section(docs, docsItems)),
      ),
      globalMenuSectionProvider(address(site)).overrideWith(
        (Ref ref) =>
            Stream<GlobalMenuSectionStatus>.value(section(site, siteItems)),
      ),
      globalMenuSectionProvider(address(project)).overrideWith(
        (Ref ref) => Stream<GlobalMenuSectionStatus>.value(
          section(project, projectItems),
        ),
      ),
    ];
  }
}

/// Routes docs-bar menu activations to the site instead of the compositor.
///
/// Anything that is not a docs destination (including reads, opens, and
/// dismissals) falls through to the default dispatcher, which safely skips
/// delivery while RINF is uninitialised.
class DocsBarDispatcher extends RustCommandDispatcher {
  DocsBarDispatcher({required this.baseUrl, required this.onNavigate});

  final String baseUrl;
  final ValueChanged<String> onNavigate;

  @override
  void dispatch(RustIntent intent) {
    if (intent is GlobalMenuIntent) {
      final GlobalMenuItemId? item = intent.activatedItem;
      final DocsDestination? destination = item == null
          ? null
          : DocsDestination.byItemId(item);
      if (destination != null) {
        onNavigate(destination.resolve(baseUrl));
        return;
      }
    }
    super.dispatch(intent);
  }
}

/// The production bar with docs fixtures, for the landing-page embed.
///
/// The global menu carries documentation navigation, the centered title
/// navigates [homeUrl], and every other cluster keeps its catalog behaviour.
/// [onNavigate] receives absolute URLs; null keeps the bar inert (tests, the
/// Widgetbook catalog) exactly as on the desktop.
class DocsBarPreview extends StatelessWidget {
  const DocsBarPreview({super.key, this.baseUrl = '/', this.onNavigate});

  /// The site root the host page reports, ending with a `/`.
  final String baseUrl;

  /// Receives absolute navigation URLs, or null to leave the bar inert.
  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<String>? onNavigate = this.onNavigate;
    final String home = DocsDestination.home.resolve(baseUrl);

    return ProviderScope(
      overrides: docsBarOverrides(
        baseUrl: baseUrl,
        onNavigate: onNavigate ?? (_) {},
      ),
      child: Hyprbaric(
        onTitleTap: onNavigate == null ? null : () => onNavigate(home),
      ),
    );
  }
}

/// Every provider the docs bar pins, for the preview and its tests.
///
/// Tests may pass their own [dispatcher] to observe the intents the bar
/// emits; the preview routes menu activations to [onNavigate] by default.
List<Override> docsBarOverrides({
  required String baseUrl,
  required ValueChanged<String> onNavigate,
  RustCommandDispatcher? dispatcher,
}) {
  return <Override>[
    setupGuideAutomaticHostProvider.overrideWithValue(false),
    rustCommandDispatcherProvider.overrideWithValue(
      dispatcher ?? DocsBarDispatcher(baseUrl: baseUrl, onNavigate: onNavigate),
    ),
    _stream(workspaceStatusProvider, DocsBarFixtures.workspace),
    _stream(workspaceSettingsStatusProvider, SettingsFixtures.workspacesRoman),
    _stream(focusedWindowStatusProvider, DocsBarFixtures.focusedWindow),
    _stream(networkStatusProvider, _DocsNetwork.status),
    _stream(audioStatusProvider, AudioFixtures.ready),
    _stream(brightnessStatusProvider, AudioFixtures.brightness),
    _stream(notificationStatusProvider, NotificationFixtures.populated()),
    _stream(powerStatusProvider, PowerFixtures.desktop),
    _stream(clockStatusProvider, DocsBarFixtures.clock),
    _stream(appearanceStatusProvider, SettingsFixtures.appearanceDefault),
    _stream(modulesStatusProvider, SettingsFixtures.modulesAll),
    _stream(capabilityStatusProvider, SettingsFixtures.capabilities),
    _stream(scheduleStatusProvider, SettingsFixtures.scheduleEnabled),
    _stream(nightLightStatusProvider, SettingsFixtures.nightLightOn),
    _stream(appStatusProvider, SettingsFixtures.app),
    _stream(trayStatusProvider, TrayFixtures.populated),
    ...DocsMenuFixtures.providers(),
    _stream(caffeineStatusProvider, DocsBarFixtures.caffeine),
    _stream(recordingStatusProvider, DocsBarFixtures.recording),
    _stream(setupStatusProvider, DocsBarFixtures.setup),
    _stream(portalStatusProvider, DocsBarFixtures.portal),
  ];
}

/// Pins one stream provider to a single deterministic snapshot.
Override _stream<T>(StreamProvider<T> provider, T value) {
  return provider.overrideWith((Ref ref) => Stream<T>.value(value));
}

/// A quiet network world behind the docs bar.
abstract final class _DocsNetwork {
  static final NetworkStatus status = NetworkStatus(
    wifiEnabled: true,
    devicePresent: true,
    scanning: false,
    activeSsid: 'Hyprnet_5G',
    traffic: NetworkTraffic(
      upload: NetworkTransfer(
        bytesPerSecond: Uint64.fromBigInt(BigInt.from(184320)),
        totalBytes: Uint64.fromBigInt(BigInt.from(482049188)),
      ),
      download: NetworkTransfer(
        bytesPerSecond: Uint64.fromBigInt(BigInt.from(2104492)),
        totalBytes: Uint64.fromBigInt(BigInt.from(4820491880)),
      ),
      pingMs: 12,
    ),
    networks: <NetworkEntry>[
      NetworkEntry(
        ssid: 'Hyprnet_5G',
        strength: 88,
        secure: true,
        state: NetworkEntryState.active,
      ),
    ],
    interfaces: <NetworkInterface>[
      NetworkInterface(name: 'wlo1', address: '192.168.1.42', active: true),
    ],
  );
}
