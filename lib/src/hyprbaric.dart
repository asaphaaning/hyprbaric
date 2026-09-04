import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bindings/bindings.dart';
import 'features/launcher/app_launcher.dart';
import 'features/rust_commands.dart';
import 'features/session/session_launcher.dart';
import 'features/settings/settings_overlay.dart';
import 'features/setup/setup_guide_host.dart';
import 'layer_shell_controller.dart';
import 'layer_shell_hit_region.dart';
import 'state/providers.dart';
import 'widgets/center_cluster.dart';
import 'widgets/hypr_surface.dart';
import 'widgets/layer_shell_dropdown.dart';
import 'widgets/left_cluster.dart';
import 'widgets/right_cluster.dart';
import 'widgets/transient_overlays.dart';

class Hyprbaric extends ConsumerWidget {
  const Hyprbaric({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final HyprPalette palette = HyprPalette.fromAppearance(
      ref.watch(currentAppearanceProvider),
    );
    final ThemeData baseTheme = ThemeData(useMaterial3: true);
    final ThemeData transparentTheme = baseTheme.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: HyprTypography.textTheme(baseTheme.textTheme),
      primaryTextTheme: HyprTypography.textTheme(baseTheme.primaryTextTheme),
      extensions: <ThemeExtension<dynamic>>[palette],
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: transparentTheme,
      darkTheme: transparentTheme,
      home: const Scaffold(
        backgroundColor: Colors.transparent,
        body: _BarView(),
      ),
    );
  }
}

class _BarView extends ConsumerStatefulWidget {
  const _BarView();

  @override
  ConsumerState<_BarView> createState() => _BarViewState();
}

class _BarViewState extends ConsumerState<_BarView> {
  static const int _barTopMargin = 3;
  static const int _brightnessShortcutStep = 5;
  static const double _centerClusterMaxWidth = 680;
  static const BorderRadius _clockCardRadius = HyprRadii.clockCardRadius;
  static const BorderRadius _networkRadius = HyprRadii.popoverRadius;
  static const BorderRadius _audioRadius = HyprRadii.popoverRadius;
  final LayerShellDropdownController _clockController =
      LayerShellDropdownController();
  final LayerShellDropdownController _networkController =
      LayerShellDropdownController();
  final LayerShellDropdownController _notificationController =
      LayerShellDropdownController();
  final LayerShellDropdownController _audioController =
      LayerShellDropdownController();
  final LayerShellDropdownController _powerController =
      LayerShellDropdownController();
  final LayerShellDropdownController _controlsController =
      LayerShellDropdownController();
  final LayerShellDropdownController _trayMenuController =
      LayerShellDropdownController();
  final AppLauncherController _appLauncherController = AppLauncherController();
  final SessionLauncherController _sessionLauncherController =
      SessionLauncherController();
  final GlobalKey _appLauncherAnchorKey = GlobalKey();
  final GlobalKey _powerButtonAnchorKey = GlobalKey();
  bool _settingsOpen = false;
  bool _layerShellConfigurationInProgress = false;
  ({BarConfig bar, LayerShellMonitorTarget monitor})?
  _pendingLayerShellConfiguration;
  late final ProviderSubscription<BarConfig> _barConfigSubscription;
  late final ProviderSubscription<LayerShellMonitorTarget>
  _viewMonitorTargetSubscription;
  late final ProviderSubscription<AsyncValue<ShortcutEvent>>
  _hotkeySubscription;
  late final ProviderSubscription<AsyncValue<AudioStatus>>
  _audioStatusSubscription;
  late final ProviderSubscription<AsyncValue<BrightnessStatus>>
  _brightnessStatusSubscription;
  late final ProviderSubscription<AsyncValue<CaffeineStatus>>
  _caffeineStatusSubscription;
  late final ProviderSubscription<AsyncValue<NightLightStatus>>
  _nightLightStatusSubscription;
  late final ProviderSubscription<AsyncValue<ScheduleStatus>>
  _scheduleStatusSubscription;
  late final ProviderSubscription<ModulesStatus> _modulesSubscription;
  late final ProviderSubscription<AsyncValue<TrayMenuStatus>>
  _trayMenuSubscription;

  @override
  void initState() {
    super.initState();
    ref.read(notificationControllerProvider);
    ref.read(controlsControllerProvider);
    _appLauncherController.addListener(_handleLauncherChromeChanged);
    _sessionLauncherController.addListener(_handleSessionLauncherChanged);
    _barConfigSubscription = ref.listenManual<BarConfig>(barConfigProvider, (
      BarConfig? previous,
      BarConfig next,
    ) {
      if (!mounted) {
        return;
      }
      _scheduleLayerShellConfiguration();
    });
    _viewMonitorTargetSubscription = ref.listenManual<LayerShellMonitorTarget>(
      layerShellViewMonitorTargetProvider,
      (_, _) => _scheduleLayerShellConfiguration(),
    );
    _hotkeySubscription = ref.listenManual<AsyncValue<ShortcutEvent>>(
      shortcutEventProvider,
      (AsyncValue<ShortcutEvent>? _, AsyncValue<ShortcutEvent> next) {
        next.whenData((ShortcutEvent event) {
          if (ref.read(layerShellViewRoleProvider).handlesGlobalActions) {
            _handleHotkeyEvent(event.event);
          }
        });
      },
    );
    _audioStatusSubscription = ref.listenManual<AsyncValue<AudioStatus>>(
      audioStatusProvider,
      (_, _) {},
    );
    _brightnessStatusSubscription = ref
        .listenManual<AsyncValue<BrightnessStatus>>(
          brightnessStatusProvider,
          (_, _) {},
        );
    _caffeineStatusSubscription = ref.listenManual<AsyncValue<CaffeineStatus>>(
      caffeineStatusProvider,
      (_, _) {},
    );
    _nightLightStatusSubscription = ref
        .listenManual<AsyncValue<NightLightStatus>>(
          nightLightStatusProvider,
          (_, _) {},
        );
    _scheduleStatusSubscription = ref.listenManual<AsyncValue<ScheduleStatus>>(
      scheduleStatusProvider,
      (_, _) {},
    );
    _modulesSubscription = ref.listenManual<ModulesStatus>(
      currentModulesProvider,
      (ModulesStatus? previous, ModulesStatus next) {
        _handleModulesChanged(next);
      },
    );
    _trayMenuSubscription = ref.listenManual<AsyncValue<TrayMenuStatus>>(
      trayMenuStatusProvider,
      (AsyncValue<TrayMenuStatus>? _, AsyncValue<TrayMenuStatus> next) {
        next.whenData(_openTrayMenu);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleLayerShellConfiguration();
    });
  }

  @override
  void dispose() {
    _appLauncherController.removeListener(_handleLauncherChromeChanged);
    _sessionLauncherController.removeListener(_handleSessionLauncherChanged);
    _barConfigSubscription.close();
    _viewMonitorTargetSubscription.close();
    _hotkeySubscription.close();
    _audioStatusSubscription.close();
    _brightnessStatusSubscription.close();
    _caffeineStatusSubscription.close();
    _nightLightStatusSubscription.close();
    _scheduleStatusSubscription.close();
    _modulesSubscription.close();
    _trayMenuSubscription.close();
    _appLauncherController.dispose();
    _sessionLauncherController.dispose();
    super.dispose();
  }

  void _handleSessionLauncherChanged() {
    _handleLauncherChromeChanged();
  }

  void _handleLauncherChromeChanged() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  void _handleModulesChanged(ModulesStatus status) {
    if (!status.isEnabled(ModuleId.systemTray)) {
      _trayMenuController.dismiss();
    }
    if (!status.isEnabled(ModuleId.notifications)) {
      _notificationController.dismiss();
    }
    if (!status.isEnabled(ModuleId.audioDisplay)) {
      _audioController.dismiss();
    }
  }

  void _scheduleLayerShellConfiguration() {
    if (!mounted) {
      return;
    }

    _pendingLayerShellConfiguration = (
      bar: ref.read(barConfigProvider),
      monitor: ref.read(layerShellViewMonitorTargetProvider),
    );
    if (!_layerShellConfigurationInProgress) {
      unawaited(_flushLayerShellConfiguration());
    }
  }

  Future<void> _flushLayerShellConfiguration() async {
    _layerShellConfigurationInProgress = true;
    try {
      while (true) {
        final configuration = _pendingLayerShellConfiguration;
        if (configuration == null) {
          break;
        }
        _pendingLayerShellConfiguration = null;
        await _configureLayerShell(configuration.bar, configuration.monitor);
      }
    } finally {
      _layerShellConfigurationInProgress = false;
    }
  }

  Future<void> _configureLayerShell(
    BarConfig barConfig,
    LayerShellMonitorTarget monitor,
  ) async {
    try {
      await ref
          .read(layerShellControllerProvider)
          .configurePanelDefaults(
            exclusiveZone: barConfig.height.round() + _barTopMargin,
            autoExclusiveZone: false,
            anchorTop: !barConfig.isBottom,
            anchorBottom: barConfig.isBottom,
            marginTop: barConfig.isBottom ? 0 : _barTopMargin,
            marginBottom: barConfig.isBottom ? _barTopMargin : 0,
            marginLeft: 0,
            marginRight: 0,
            monitor: monitor,
          );
      if (!mounted) {
        return;
      }
      final LayerShellRegionManager regionManager = ref.read(
        layerShellRegionManagerProvider,
      );
      regionManager
        ..setBarHeight(barConfig.height)
        ..setBarEdge(
          barConfig.isBottom ? LayerShellBarEdge.bottom : LayerShellBarEdge.top,
        );
      await regionManager.updateRegion(
        menuRect: null,
        debugLabel: 'bar-initial',
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to configure layer shell: $error');
      debugPrint('$stackTrace');
    }
  }

  void _handleHotkeyEvent(HotkeyEvent event) {
    switch (event) {
      case HotkeyEventToggleAppLauncher():
        _toggleAppLauncher();
      case HotkeyEventToggleControls():
        _toggleControls();
      case HotkeyEventOpenBarSettings():
        _openSettingsModal();
      case HotkeyEventToggleSessionLauncher():
        _toggleSessionLauncher();
      case HotkeyEventVolumeUp(:final step):
        _changeOutputVolume(step);
      case HotkeyEventVolumeDown(:final step):
        _changeOutputVolume(-step);
      case HotkeyEventToggleMute():
        _toggleOutputMute();
      case HotkeyEventBrightnessUp():
        _changeBrightness(_brightnessShortcutStep);
      case HotkeyEventBrightnessDown():
        _changeBrightness(-_brightnessShortcutStep);
      case HotkeyEventColorPick():
        _pickColor();
      case HotkeyEventToggleRecording():
        _toggleRecording();
      case HotkeyEventToggleDoNotDisturb():
        _toggleDoNotDisturb();
      case HotkeyEventToggleNightLight():
        _toggleNightLight();
      case HotkeyEventToggleCaffeine():
        _toggleCaffeine();
      case _:
        return;
    }
  }

  void _changeOutputVolume(int delta) {
    final AudioEndpoint? output = ref.read(currentAudioStatusProvider)?.output;
    if (output == null) {
      return;
    }
    _setAudioVolume(AudioEndpointKind.output, output.volume + delta);
  }

  void _toggleOutputMute() {
    final AudioEndpoint? output = ref.read(currentAudioStatusProvider)?.output;
    if (output == null) {
      return;
    }
    _setAudioMuted(AudioEndpointKind.output, muted: !output.muted);
  }

  void _changeBrightness(int delta) {
    final BrightnessStatus? status = ref
        .read(brightnessStatusProvider)
        .asData
        ?.value;
    switch (status) {
      case BrightnessStatusAvailable(:final value):
        _setBrightness(value + delta, feedback: BrightnessFeedback.osd);
      case _:
        return;
    }
  }

  void _toggleDoNotDisturb() {
    final bool enabled =
        ref.read(currentNotificationStatusProvider)?.dndEnabled ?? false;
    _setDoNotDisturb(!enabled);
  }

  void _toggleNightLight() {
    final NightLightStatus? status = ref
        .read(nightLightStatusProvider)
        .asData
        ?.value;
    switch (status) {
      case NightLightStatusAvailable(:final enabled):
        _setNightLight(!enabled);
      case _:
        return;
    }
  }

  void _toggleCaffeine() {
    final CaffeineStatus? status = ref
        .read(caffeineStatusProvider)
        .asData
        ?.value;
    switch (status) {
      case CaffeineStatusAvailable(:final enabled):
        _setCaffeine(!enabled);
      case _:
        return;
    }
  }

  void _toggleClock() {
    if (_clockController.isOpen) {
      _clockController.close();
      return;
    }
    _dismissAppLauncher();
    _dismissSessionLauncher();
    _dismissBarPopups();
    _clockController.open();
  }

  void _toggleNetwork() {
    if (_networkController.isOpen) {
      _networkController.close();
      return;
    }
    _dismissAppLauncher();
    _dismissSessionLauncher();
    _dismissBarPopups();
    _requestNetworkScan();
    _networkController.open();
  }

  void _toggleNotifications() {
    if (_notificationController.isOpen) {
      _notificationController.close();
      return;
    }
    _dismissAppLauncher();
    _dismissSessionLauncher();
    _dismissBarPopups();
    _notificationController.open();
  }

  void _toggleAudio() {
    if (_audioController.isOpen) {
      _audioController.close();
      return;
    }
    _dismissAppLauncher();
    _dismissSessionLauncher();
    _dismissBarPopups();
    _audioController.open();
  }

  void _togglePower() {
    if (_powerController.isOpen) {
      _powerController.close();
      return;
    }
    _dismissAppLauncher();
    _dismissSessionLauncher();
    _dismissBarPopups();
    _powerController.open();
  }

  void _toggleControls() {
    if (_controlsController.isOpen) {
      _controlsController.close();
      return;
    }
    _dismissAppLauncher();
    _dismissSessionLauncher();
    _dismissBarPopups();
    _controlsController.open();
  }

  void _toggleAppLauncher() {
    if (_appLauncherController.isOpen) {
      _appLauncherController.close();
      return;
    }
    _dismissBarPopups();
    _dismissSessionLauncher();
    _appLauncherController.open();
  }

  void _toggleSessionLauncher() {
    if (_sessionLauncherController.isOpen) {
      _sessionLauncherController.close();
      return;
    }
    _dismissAppLauncher();
    _dismissBarPopups();
    _sessionLauncherController.open();
  }

  void _dismissBarPopups() {
    _clockController.dismiss();
    _networkController.dismiss();
    _notificationController.dismiss();
    _audioController.dismiss();
    _powerController.dismiss();
    _controlsController.dismiss();
    _trayMenuController.dismiss();
  }

  void _dismissBarPopupsExceptTrayMenu() {
    _clockController.dismiss();
    _networkController.dismiss();
    _notificationController.dismiss();
    _audioController.dismiss();
    _powerController.dismiss();
    _controlsController.dismiss();
  }

  void _dismissSessionLauncher() {
    _sessionLauncherController.dismiss();
  }

  void _dismissAppLauncher() {
    _appLauncherController.dismiss();
  }

  void _requestNetworkScan() {
    ref.read(networkControllerProvider.notifier).scan();
  }

  void _setNetworkWifiEnabled(bool enabled) {
    ref
        .read(networkControllerProvider.notifier)
        .setWifiEnabled(enabled: enabled);
  }

  void _connectNetwork(NetworkEntry entry, String? password) {
    ref.read(networkControllerProvider.notifier).connect(entry, password);
  }

  void _openNetworkSettings() {
    ref.read(networkControllerProvider.notifier).openSettings();
  }

  void _openSettingsModal() {
    _controlsController.dismiss();
    _dismissAppLauncher();
    _dismissSessionLauncher();
    if (mounted) {
      setState(() => _settingsOpen = true);
    }
  }

  void _closeSettingsModal() {
    if (mounted) {
      setState(() => _settingsOpen = false);
    }
  }

  void _setAudioVolume(AudioEndpointKind kind, int volume) {
    ref.read(audioControllerProvider.notifier).setVolume(kind, volume);
  }

  void _setAudioMuted(AudioEndpointKind kind, {required bool muted}) {
    ref.read(audioControllerProvider.notifier).setMuted(kind, muted: muted);
  }

  void _setBrightness(int value, {required BrightnessFeedback feedback}) {
    ref
        .read(audioControllerProvider.notifier)
        .setBrightness(value, feedback: feedback);
  }

  /// The mixer knob already shows the value it is setting.
  void _setBrightnessFromPanel(int value) =>
      _setBrightness(value, feedback: BrightnessFeedback.none);

  void _openAudioMixer() {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(const LauncherIntent.launch('pavucontrol.desktop'));
  }

  void _setPowerProfile(PowerProfile profile) {
    ref.read(powerControllerProvider.notifier).setProfile(profile);
  }

  void _showControlToast(String message) {
    ref.read(controlsControllerProvider.notifier).showToast(message);
  }

  void _captureScreenshot(ScreenshotMode mode) {
    _dismissAppLauncher();
    _dismissSessionLauncher();
    _dismissBarPopups();
    ref.read(controlsControllerProvider.notifier).captureScreenshot(mode);
  }

  void _pickColor() {
    _dismissAppLauncher();
    _dismissSessionLauncher();
    _dismissBarPopups();
    ref.read(controlsControllerProvider.notifier).pickColor();
  }

  void _toggleRecording() {
    _dismissAppLauncher();
    _dismissSessionLauncher();
    _dismissBarPopups();
    ref.read(controlsControllerProvider.notifier).toggleRecording();
  }

  void _activateTrayItem(String id, Offset position) {
    ref.read(trayControllerProvider.notifier).activate(id, position);
  }

  void _openTrayContextMenu(String id, Offset position) {
    ref.read(trayControllerProvider.notifier).openContextMenu(id, position);
  }

  void _activateTrayMenuItem(String itemId, int menuItemId) {
    ref
        .read(trayControllerProvider.notifier)
        .activateMenuItem(itemId, menuItemId);
  }

  void _openTrayMenu(TrayMenuStatus menu) {
    if (!mounted || menu.items.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _dismissAppLauncher();
      _dismissSessionLauncher();
      _dismissBarPopupsExceptTrayMenu();
      _trayMenuController.open();
    });
  }

  void _dismissNotification(int id) {
    ref.read(notificationControllerProvider.notifier).dismiss(id);
  }

  void _clearNotifications() {
    ref.read(notificationControllerProvider.notifier).clearAll();
  }

  void _setDoNotDisturb(bool enabled) {
    ref
        .read(notificationControllerProvider.notifier)
        .setDoNotDisturb(enabled: enabled);
  }

  void _setNightLight(bool enabled) {
    ref
        .read(nightLightControllerProvider.notifier)
        .setEnabled(enabled: enabled);
  }

  void _setCaffeine(bool enabled) {
    ref.read(caffeineControllerProvider.notifier).setEnabled(enabled: enabled);
  }

  void _sendClockCalendarCommand(CalendarCommand command) {
    ref.read(clockControllerProvider.notifier).calendar(command);
  }

  void _openNotificationToast(ToastEntry entry) {
    ref.read(notificationControllerProvider.notifier).dismissToast(entry.id);
    if (_notificationController.isOpen) {
      return;
    }
    _dismissAppLauncher();
    _dismissSessionLauncher();
    _dismissBarPopups();
    _notificationController.open();
  }

  @override
  Widget build(BuildContext context) {
    final BarConfig barConfig = ref.watch(barConfigProvider);
    final ModulesStatus modules = ref.watch(currentModulesProvider);
    final double barHeight = barConfig.height;
    final HyprPalette palette = context.hyprPalette;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: Colors.transparent),
        Align(
          alignment: barConfig.isBottom
              ? Alignment.bottomCenter
              : Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Material(
              color: Colors.transparent,
              elevation: 0,
              child: HyprSurface(
                borderRadius: BorderRadius.circular(
                  barConfig.cornerRadius.toDouble(),
                ),
                color: palette.surfaceStrong,
                borderColor: HyprColors.borderOuter,
                shadow: false,
                blur: 16,
                child: SizedBox(
                  height: barHeight,
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: LeftCluster(
                            logoKey: _appLauncherAnchorKey,
                            appLauncherOpen: _appLauncherController.isOpen,
                            onToggleAppLauncher: _toggleAppLauncher,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: modules.isEnabled(ModuleId.activeWindowTitle)
                                ? const CenterCluster(
                                    maxWidth: _centerClusterMaxWidth,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                        Expanded(
                          child: RightCluster(
                            showSystemTray: modules.isEnabled(
                              ModuleId.systemTray,
                            ),
                            showNotifications: modules.isEnabled(
                              ModuleId.notifications,
                            ),
                            showAudioDisplay: modules.isEnabled(
                              ModuleId.audioDisplay,
                            ),
                            networkController: _networkController,
                            audioController: _audioController,
                            powerController: _powerController,
                            controlsController: _controlsController,
                            trayMenuController: _trayMenuController,
                            notificationController: _notificationController,
                            clockController: _clockController,
                            powerButtonAnchorKey: _powerButtonAnchorKey,
                            networkRadius: _networkRadius,
                            audioRadius: _audioRadius,
                            clockCardRadius: _clockCardRadius,
                            sessionLauncherOpen:
                                _sessionLauncherController.isOpen,
                            onToggleNetwork: _toggleNetwork,
                            onToggleAudio: _toggleAudio,
                            onTogglePower: _togglePower,
                            onToggleControls: _toggleControls,
                            onToggleNotifications: _toggleNotifications,
                            onToggleClock: _toggleClock,
                            onToggleSessionLauncher: _toggleSessionLauncher,
                            onSetNetworkWifiEnabled: _setNetworkWifiEnabled,
                            onConnectNetwork: _connectNetwork,
                            onOpenNetworkSettings: _openNetworkSettings,
                            onSetAudioVolume: _setAudioVolume,
                            onSetAudioMuted: _setAudioMuted,
                            onSetBrightness: _setBrightnessFromPanel,
                            onOpenAudioMixer: _openAudioMixer,
                            onSetPowerProfile: _setPowerProfile,
                            onCaptureScreenshot: _captureScreenshot,
                            onPickColor: _pickColor,
                            onToggleRecording: _toggleRecording,
                            onOpenSettings: _openSettingsModal,
                            onControlToast: _showControlToast,
                            onActivateTrayItem: _activateTrayItem,
                            onOpenTrayContextMenu: _openTrayContextMenu,
                            onActivateTrayMenuItem: _activateTrayMenuItem,
                            onDismissNotification: _dismissNotification,
                            onClearNotifications: _clearNotifications,
                            onSetDoNotDisturb: _setDoNotDisturb,
                            onSetNightLight: _setNightLight,
                            onSetCaffeine: _setCaffeine,
                            onClockCommand: _sendClockCalendarCommand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SessionLauncher(
          controller: _sessionLauncherController,
          barHeight: barHeight,
          anchorKey: _powerButtonAnchorKey,
        ),
        AppLauncher(
          controller: _appLauncherController,
          barHeight: barHeight,
          anchorKey: _appLauncherAnchorKey,
        ),
        ToastHost(barHeight: barHeight, onToastPressed: _openNotificationToast),
        const OsdHost(),
        if (_settingsOpen) SettingsModalOverlay(onClose: _closeSettingsModal),
        SetupGuideHost(
          key: const ValueKey<String>('setup-guide-host'),
          onReady: _closeSettingsModal,
        ),
      ],
    );
  }
}
