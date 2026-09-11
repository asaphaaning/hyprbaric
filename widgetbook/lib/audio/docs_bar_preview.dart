import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:riverpod/misc.dart' show Override;

import '../embed/embed_theme.dart';
import '../use_cases/settings/settings_fixtures.dart';
import 'docs_search.dart';
import 'docs_search_fetcher.dart';

/// Where one docs-bar navigation leads: a menu row, the title, or search.
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
  ),
  search(itemId: 114, label: 'Search', target: '/search');

  const DocsDestination({
    required this.itemId,
    required this.label,
    required this.target,
  });

  /// The stable native row id the fixture assigns this destination.
  ///
  /// Button-only destinations such as [search] still carry one so every site
  /// route shares the same vocabulary.
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
    id: 2,
    name: '2',
    isSpecial: false,
    occupiedWorkspaceIds: <int>[1, 2, 4],
    monitors: <MonitorWorkspaceStatus>[],
  );

  /// The strip shows [visibleCount] indicators, so the site bar stays compact
  /// next to the docs menu. The count follows the range preset it belongs
  /// to, the way the settings panel pairs them.
  static const WorkspaceSettingsStatus siteWorkspaces = WorkspaceSettingsStatus(
    indicatorStyle: WorkspaceIndicatorStyle.roman,
    clickable: true,
    visibleRange: WorkspaceVisibleRange.small,
    visibleCount: 5,
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

/// The site bar: workspaces, docs menu, title, and search.
///
/// A minimal production-cluster composition for the landing-page embed. The
/// workspace strip keeps a few indicators, the global menu carries
/// documentation navigation, the centered title goes home, and the search
/// button routes to the search page; no control widgets come along.
/// [onNavigate] receives absolute URLs, while null keeps every navigation
/// inert (tests) exactly as on the desktop. [onMenuRect] reports the open
/// menu region for the host's frost island, or null when none is open.
class DocsBarPreview extends StatelessWidget {
  const DocsBarPreview({
    super.key,
    this.baseUrl = '/',
    this.onNavigate,
    this.onMenuRect,
  });

  /// The site root the host page reports, ending with a `/`.
  final String baseUrl;

  /// Receives absolute navigation URLs, or null to leave the bar inert.
  final ValueChanged<String>? onNavigate;

  /// Receives the open menu region, or null to leave frost reporting off.
  final ValueChanged<LayerShellMenuRegion?>? onMenuRect;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<String>? onNavigate = this.onNavigate;
    final ValueChanged<LayerShellMenuRegion?>? onMenuRect = this.onMenuRect;
    final String home = DocsDestination.home.resolve(baseUrl);

    return ProviderScope(
      overrides: docsBarOverrides(
        baseUrl: baseUrl,
        onNavigate: onNavigate ?? (_) {},
      ),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: embedTheme,
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: <Widget>[
              _DocsSiteBar(
                baseUrl: baseUrl,
                onTitleTap: onNavigate == null
                    ? null
                    : () => onNavigate(home),
                onNavigate: onNavigate,
              ),
              if (onMenuRect != null)
                _MenuFrostReporter(onMenuRect: onMenuRect),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every provider the docs bar pins, for the preview and its tests.
///
/// Only what the site composition reads: menu and title fixtures plus the
/// appearance behind the bar chrome. The workspace strip and the search
/// button take explicit props instead. Tests may pass their own [dispatcher]
/// to observe the intents the bar emits; the preview routes menu activations
/// to [onNavigate] by default.
List<Override> docsBarOverrides({
  required String baseUrl,
  required ValueChanged<String> onNavigate,
  RustCommandDispatcher? dispatcher,
}) {
  return <Override>[
    rustCommandDispatcherProvider.overrideWithValue(
      dispatcher ??
          DocsBarDispatcher(baseUrl: baseUrl, onNavigate: onNavigate),
    ),
    _stream(focusedWindowStatusProvider, DocsBarFixtures.focusedWindow),
    _stream(workspaceStatusProvider, DocsBarFixtures.workspace),
    _stream(appearanceStatusProvider, SettingsFixtures.appearanceDefault),
    ...DocsMenuFixtures.providers(),
  ];
}

/// Pins one stream provider to a single deterministic snapshot.
Override _stream<T>(StreamProvider<T> provider, T value) {
  return provider.overrideWith((Ref ref) => Stream<T>.value(value));
}

/// The site bar chrome around the workspace strip, the docs menu, the
/// centered title, and the search entry.
///
/// Mirrors the production bar's surface and three-cluster row, minus the
/// launcher and every control widget. The strip owns its workspace state
/// locally so clicks stay live without a compositor behind them.
class _DocsSiteBar extends ConsumerStatefulWidget {
  const _DocsSiteBar({
    required this.baseUrl,
    this.onTitleTap,
    this.onNavigate,
  });

  final String baseUrl;
  final VoidCallback? onTitleTap;
  final ValueChanged<String>? onNavigate;

  @override
  ConsumerState<_DocsSiteBar> createState() => _DocsSiteBarState();
}

class _DocsSiteBarState extends ConsumerState<_DocsSiteBar> {
  static const double _centerClusterMaxWidth = 680;
  static const List<int> _occupiedWorkspaces = <int>[1, 4];

  final LayerShellDropdownController _searchController =
      LayerShellDropdownController();
  final LayerShellDropdownController _clockController =
      LayerShellDropdownController();

  int _activeWorkspace = 2;
  DateTime _now = DateTime.now();
  late final ValueNotifier<DateTime> _month;
  Timer? _minuteTicker;

  @override
  void initState() {
    super.initState();
    final DateTime now = _now;
    _month = ValueNotifier<DateTime>(DateTime(now.year, now.month));
    _minuteTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _minuteTicker?.cancel();
    _month.dispose();
    super.dispose();
  }

  List<int> get _occupiedWorkspaceIds =>
      <int>{..._occupiedWorkspaces, _activeWorkspace}.toList(growable: false)
        ..sort();

  void _setActiveWorkspace(int workspace) {
    setState(() => _activeWorkspace = workspace < 1 ? 1 : workspace);
  }

  void _toggleSearch() {
    if (_searchController.isOpen) {
      _searchController.close();
      return;
    }
    _clockController.close();
    _searchController.open();
  }

  void _toggleClock() {
    if (_clockController.isOpen) {
      _clockController.close();
      return;
    }
    _searchController.close();
    _clockController.open();
  }

  void _onClockCommand(CalendarCommand command) {
    final DateTime now = DateTime.now();
    final DateTime month = _month.value;
    setState(() => _now = now);
    _month.value = switch (command) {
      CalendarCommand.previousMonth =>
        DateTime(month.year, month.month - 1),
      CalendarCommand.nextMonth => DateTime(month.year, month.month + 1),
      CalendarCommand.today => DateTime(now.year, now.month),
    };
  }

  ClockViewState _clockViewFor(DateTime month) =>
      ClockViewState.fromStatus(_buildClockStatus(month));

  ClockStatus _buildClockStatus(DateTime month) {
    final DateTime now = _now;
    return ClockStatus(
      timeLabel: '${_two(now.hour)}:${_two(now.minute)}',
      dateLabel: '${_weekday3(now.weekday)}, ${_month3(now.month)} ${now.day}',
      monthLabel: '${_monthName(month.month)} ${month.year}',
      weekNumber: _isoWeekNumber(now),
      utcOffset: _formatOffset(now.timeZoneOffset),
      days: _monthGrid(month, now),
    );
  }

  @override
  Widget build(BuildContext context) {
    final BarConfig bar = ref.watch(barConfigProvider);
    final HyprPalette palette = context.hyprPalette;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: HyprSurface(
        borderRadius: BorderRadius.circular(bar.cornerRadius.toDouble()),
        color: palette.surfaceStrong,
        borderColor: HyprColors.borderOuter,
        shadow: false,
        blur: 16,
        child: SizedBox(
          height: bar.height,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                // A row hands its non-flexible children
                                // unbounded width, which would stop the box
                                // below ever scaling down and overflow the bar
                                // instead. The cap is what it would have had
                                // on its own.
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: constraints.maxWidth,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: WorkspaceStrip(
                                      status: WorkspaceStatus(
                                        id: _activeWorkspace,
                                        name: '$_activeWorkspace',
                                        isSpecial: false,
                                        occupiedWorkspaceIds:
                                            _occupiedWorkspaceIds,
                                        monitors:
                                            const <MonitorWorkspaceStatus>[],
                                      ),
                                      settings:
                                          DocsBarFixtures.siteWorkspaces,
                                      resolution: MonitorWorkspaceResolution(
                                        activeWorkspaceId: _activeWorkspace,
                                        activeWorkspaceName:
                                            '$_activeWorkspace',
                                        isSpecial: false,
                                        monitorName: 'DP-1',
                                      ),
                                      onPrevious: () => _setActiveWorkspace(
                                        _activeWorkspace - 1,
                                      ),
                                      onNext: () => _setActiveWorkspace(
                                        _activeWorkspace + 1,
                                      ),
                                      onSelect: _setActiveWorkspace,
                                    ),
                                  ),
                                ),
                                const Flexible(child: GlobalMenuBar()),
                              ],
                            );
                          },
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CenterCluster(
                      maxWidth: _centerClusterMaxWidth,
                      onTap: widget.onTitleTap,
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          LayerShellDropdown(
                            controller: _searchController,
                            menuRadius: HyprRadii.popoverRadius,
                            menuWidth: 380,
                            horizontalAnchor:
                                LayerShellDropdownAnchor.right,
                            buttonBuilder:
                                (
                                  BuildContext context,
                                  LayerShellDropdownController controller, {
                                  required bool isOpen,
                                }) {
                                  return _SiteSearchButton(
                                    isOpen: isOpen,
                                    onPressed: _toggleSearch,
                                  );
                                },
                            menuBuilder:
                                (
                                  BuildContext context,
                                  LayerShellDropdownController controller,
                                ) {
                                  return _SiteSearchPanel(
                                    baseUrl: widget.baseUrl,
                                    onNavigate: (String url) {
                                      controller.close();
                                      widget.onNavigate?.call(url);
                                    },
                                    onClose: controller.close,
                                  );
                                },
                          ),
                          const SizedBox(width: 4),
                          LayerShellDropdown(
                            controller: _clockController,
                            menuRadius: BorderRadius.zero,
                            buttonBuilder:
                                (
                                  BuildContext context,
                                  LayerShellDropdownController controller, {
                                  required bool isOpen,
                                }) {
                                  return ClockButton(
                                    status: _clockViewFor(
                                      _month.value,
                                    ),
                                    isOpen: isOpen,
                                    onPressed: _toggleClock,
                                  );
                                },
                            menuBuilder:
                                (
                                  BuildContext context,
                                  LayerShellDropdownController controller,
                                ) {
                                  // The overlay entry builds
                                  // once, so the panel follows the
                                  // month through a listenable the way
                                  // production panels follow providers.
                                  return ValueListenableBuilder<DateTime>(
                                    valueListenable: _month,
                                    builder:
                                        (
                                          BuildContext context,
                                          DateTime month,
                                          Widget? child,
                                        ) {
                                          return ClockPanel(
                                            status: _clockViewFor(
                                              month,
                                            ),
                                            onCommand: _onClockCommand,
                                            borderRadius:
                                                HyprRadii.clockCardRadius,
                                          );
                                        },
                                  );
                                },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The documentation search entry, dressed like the navbar's own field.
///
/// A button rather than a field: activating it routes to the search page,
/// where the plugin's real input lives. Kept quiet like the bar's other
/// affordances, with a shortcut pill mirroring the navbar's hint.
class _SiteSearchButton extends StatelessWidget {
  const _SiteSearchButton({required this.isOpen, required this.onPressed});

  final bool isOpen;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      semanticLabel: 'Search the docs',
      onPressed: onPressed,
      builder: (BuildContext context, HyprInteractionState state) {
        final bool lit = isOpen || state.active;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          height: 34,
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: HyprColors.well,
            border: Border.all(
              color: lit ? HyprColors.borderSoft : HyprColors.wellBorder,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '/',
                style: HyprTypography.globalMenuKey.copyWith(
                  color: HyprColors.textFaint,
                ),
              ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  'Search the docs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HyprTypography.barMono.copyWith(
                    color: HyprColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: HyprColors.wellBorder),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'Ctrl K',
                  style: HyprTypography.globalMenuKey.copyWith(
                    color: HyprColors.textFaint,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Forwards the open menu region to whoever reports frost for the host page.
///
/// The dropdowns already measure this rect for the native input region; the
/// site embed reuses the same geometry so the page can blur exactly the
/// popup area. Reports null when no menu is open so the island hides.
class _MenuFrostReporter extends ConsumerStatefulWidget {
  const _MenuFrostReporter({required this.onMenuRect});

  final ValueChanged<LayerShellMenuRegion?> onMenuRect;

  @override
  ConsumerState<_MenuFrostReporter> createState() =>
      _MenuFrostReporterState();
}

class _MenuFrostReporterState extends ConsumerState<_MenuFrostReporter> {
  VoidCallback? _detach;

  @override
  void initState() {
    super.initState();
    final LayerShellRegionManager manager = ref.read(
      layerShellRegionManagerProvider,
    );

    void report() => widget.onMenuRect(manager.menuRegion.value);

    manager.menuRegion.addListener(report);
    _detach = () => manager.menuRegion.removeListener(report);
    report();
  }

  @override
  void dispose() {
    _detach?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Documentation search: a field over locally ranked results.
///
/// The index is built from the docs at site build time and fetched next to
/// the embed, so queries never leave the bar and need no page-JS bridge.
/// An empty query shows curated entry points; Enter opens the first hit, or
/// the full search page when there is none.
class _SiteSearchPanel extends StatefulWidget {
  const _SiteSearchPanel({
    required this.baseUrl,
    required this.onNavigate,
    required this.onClose,
  });

  final String baseUrl;
  final ValueChanged<String> onNavigate;
  final VoidCallback onClose;

  @override
  State<_SiteSearchPanel> createState() => _SiteSearchPanelState();
}

class _SiteSearchPanelState extends State<_SiteSearchPanel> {
  static const List<DocsDestination> _popular = <DocsDestination>[
    DocsDestination.getStarted,
    DocsDestination.installation,
    DocsDestination.configuration,
    DocsDestination.shortcuts,
  ];

  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;
  List<DocsSearchEntry>? _index;
  List<DocsSearchEntry> _results = const <DocsSearchEntry>[];
  String _query = '';

  @override
  void initState() {
    super.initState();
    // The follower renders its first frame offstage while unlinked, which
    // swallows autofocus; requesting focus after layout lands it reliably.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
      }
    });
    fetchDocsSearchIndex().then((List<DocsSearchEntry>? index) {
      if (!mounted) {
        return;
      }
      setState(() {
        _index = index ?? const <DocsSearchEntry>[];
        _runQuery();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _query = value.trim();
        _runQuery();
      });
    });
  }

  void _runQuery() {
    final List<DocsSearchEntry>? index = _index;
    _results = _query.isEmpty || index == null
        ? const <DocsSearchEntry>[]
        : rankDocsResults(_query, index);
  }

  String _siteUrl(String target) {
    final String baseUrl = widget.baseUrl;
    final String root = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return '$root$target';
  }

  void _open(String target) {
    widget.onClose();
    widget.onNavigate(_siteUrl(target));
  }

  void _openFirstOrSearch() {
    final List<DocsSearchEntry> results = _results;
    _open(results.isEmpty ? '/search' : results.first.url);
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _query = '';
      _results = const <DocsSearchEntry>[];
    });
  }

  @override
  Widget build(BuildContext context) {
    final String query = _query;
    final bool searching = query.isNotEmpty;

    return HyprPopoverPanel(
      borderRadius: HyprRadii.popoverRadius,
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 380),
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            HyprTextFieldChrome(
              focusNode: _focus,
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.search_rounded,
                    size: 15,
                    color: HyprColors.textFaint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focus,
                      autofocus: true,
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) => _openFirstOrSearch(),
                      style: HyprTypography.barMono.copyWith(
                        color: HyprColors.text,
                      ),
                      cursorColor: HyprColors.accent,
                      decoration: InputDecoration.collapsed(
                        hintText: 'Search the docs…',
                        hintStyle: HyprTypography.barMono.copyWith(
                          color: HyprColors.textFaint,
                        ),
                      ),
                    ),
                  ),
                  if (searching)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _clear,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          'Esc',
                          style: HyprTypography.globalMenuKey.copyWith(
                            color: HyprColors.textFaint,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (!searching) ...<Widget>[
              const _SearchCaption(label: 'Popular'),
              for (final DocsDestination destination in _popular)
                _SearchResultRow(
                  title: destination.label,
                  crumb: destination.target,
                  onTap: () => _open(destination.target),
                ),
            ] else if (_index == null) ...<Widget>[
              const _SearchNotice(label: 'Loading the index…'),
            ] else if (_results.isEmpty) ...<Widget>[
              _SearchNotice(label: 'No results for "$query"'),
            ] else ...<Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    for (final DocsSearchEntry hit in _results)
                      _SearchResultRow(
                        title: hit.title,
                        crumb: hit.section,
                        onTap: () => _open(hit.url),
                      ),
                  ],
                ),
              ),
            ],
            _SearchFooter(onOpenSearch: () => _open('/search')),
          ],
        ),
      ),
    );
  }
}

/// One search row: title over a muted crumb, lit on hover like menu rows.
class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.title,
    required this.crumb,
    required this.onTap,
  });

  final String title;
  final String crumb;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      semanticLabel: title,
      onPressed: onTap,
      builder: (BuildContext context, HyprInteractionState state) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: state.active ? HyprColors.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HyprTypography.barStrong.copyWith(
                  color: HyprColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                crumb,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: HyprTypography.compactMono.copyWith(
                  color: HyprColors.textMuted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A caption naming the rows beneath it, mirroring the menu groups.
class _SearchCaption extends StatelessWidget {
  const _SearchCaption({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        style: HyprTypography.globalMenuGroup.copyWith(
          color: HyprColors.textFaint,
        ),
      ),
    );
  }
}

/// A quiet line where rows would be: loading and empty states.
class _SearchNotice extends StatelessWidget {
  const _SearchNotice({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Text(
        label,
        style: HyprTypography.globalMenuItem.copyWith(
          color: HyprColors.textFaint,
        ),
      ),
    );
  }
}

/// The footer row leading to the full search page.
class _SearchFooter extends StatelessWidget {
  const _SearchFooter({required this.onOpenSearch});

  final VoidCallback onOpenSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 10),
          child: ColoredBox(
            color: HyprColors.popupStroke,
            child: SizedBox(height: 1, width: double.infinity),
          ),
        ),
        _SearchResultRow(
          title: 'Open full search',
          crumb: 'Every page, one list',
          onTap: onOpenSearch,
        ),
      ],
    );
  }
}

const List<String> _weekdays3 = <String>[
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

const List<String> _months3 = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const List<String> _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _two(int value) => value.toString().padLeft(2, '0');

String _weekday3(int weekday) => _weekdays3[(weekday - 1).clamp(0, 6)];

String _month3(int month) => _months3[(month - 1).clamp(0, 11)];

String _monthName(int month) => _monthNames[(month - 1).clamp(0, 11)];

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The ISO week number of [date]: the week holding its Thursday.
int _isoWeekNumber(DateTime date) {
  final DateTime thursday = date.add(Duration(days: 4 - date.weekday));
  final DateTime yearStart = DateTime(thursday.year, 1, 1);
  return (thursday.difference(yearStart).inDays ~/ 7) + 1;
}

String _formatOffset(Duration offset) {
  final int minutes = offset.inMinutes;
  final String sign = minutes < 0 ? '-' : '+';
  final int absolute = minutes.abs();
  return 'UTC$sign${_two(absolute ~/ 60)}:${_two(absolute % 60)}';
}

/// The Monday-first month grid the calendar panel renders, padded with the
/// neighbouring months' edge days the way wall calendars do.
List<CalendarDay> _monthGrid(DateTime month, DateTime now) {
  final DateTime first = DateTime(month.year, month.month, 1);
  final int leading = first.weekday - 1;
  final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
  final List<CalendarDay> days = <CalendarDay>[];

  for (int back = leading; back > 0; back--) {
    final DateTime day = first.subtract(Duration(days: back));
    days.add(
      CalendarDay(
        year: day.year,
        month: day.month,
        day: day.day,
        currentMonth: false,
        today: _isSameDay(day, now),
      ),
    );
  }
  for (int day = 1; day <= daysInMonth; day++) {
    final DateTime current = DateTime(month.year, month.month, day);
    days.add(
      CalendarDay(
        year: current.year,
        month: current.month,
        day: day,
        currentMonth: true,
        today: _isSameDay(current, now),
      ),
    );
  }
  DateTime next = DateTime(month.year, month.month + 1, 1);
  while (days.length % 7 != 0) {
    days.add(
      CalendarDay(
        year: next.year,
        month: next.month,
        day: next.day,
        currentMonth: false,
        today: _isSameDay(next, now),
      ),
    );
    next = next.add(const Duration(days: 1));
  }
  return days;
}
