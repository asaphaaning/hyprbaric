import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../bindings/bindings.dart';
import '../features/audio/audio_panel.dart';
import '../features/clock/clock_panel.dart';
import '../features/controls/controls_panel.dart';
import '../features/network/network_panel.dart';
import '../features/power/battery_chip.dart';
import '../features/power/power_panel.dart';
import '../features/tray/tray_menu_panel.dart';
import '../features/tray/tray_strip.dart';
import '../state/providers.dart';
import 'hypr_surface.dart';
import 'layer_shell_dropdown.dart';
import 'notification_panel.dart';
import 'right_cluster_buttons.dart';

class RightCluster extends ConsumerWidget {
  const RightCluster({
    super.key,
    required this.showSystemTray,
    required this.showNotifications,
    required this.showAudioDisplay,
    required this.networkController,
    required this.audioController,
    required this.powerController,
    required this.controlsController,
    required this.trayMenuController,
    required this.notificationController,
    required this.clockController,
    required this.powerButtonAnchorKey,
    required this.networkRadius,
    required this.audioRadius,
    required this.clockCardRadius,
    required this.sessionLauncherOpen,
    required this.onToggleNetwork,
    required this.onToggleAudio,
    required this.onTogglePower,
    required this.onToggleControls,
    required this.onToggleNotifications,
    required this.onToggleClock,
    required this.onToggleSessionLauncher,
    required this.onSetNetworkWifiEnabled,
    required this.onConnectNetwork,
    required this.onOpenNetworkSettings,
    required this.onSetAudioVolume,
    required this.onSetAudioMuted,
    required this.onSetBrightness,
    required this.onOpenAudioMixer,
    required this.onSetPowerProfile,
    required this.onCaptureScreenshot,
    required this.onPickColor,
    required this.onToggleRecording,
    required this.onOpenSettings,
    required this.onControlToast,
    required this.onActivateTrayItem,
    required this.onOpenTrayContextMenu,
    required this.onActivateTrayMenuItem,
    required this.onDismissNotification,
    required this.onClearNotifications,
    required this.onSetDoNotDisturb,
    required this.onSetNightLight,
    required this.onSetCaffeine,
    required this.onClockCommand,
  });

  final bool showSystemTray;
  final bool showNotifications;
  final bool showAudioDisplay;
  final LayerShellDropdownController networkController;
  final LayerShellDropdownController audioController;
  final LayerShellDropdownController powerController;
  final LayerShellDropdownController controlsController;
  final LayerShellDropdownController trayMenuController;
  final LayerShellDropdownController notificationController;
  final LayerShellDropdownController clockController;
  final GlobalKey powerButtonAnchorKey;
  final BorderRadius networkRadius;
  final BorderRadius audioRadius;
  final BorderRadius clockCardRadius;
  final bool sessionLauncherOpen;
  final VoidCallback onToggleNetwork;
  final VoidCallback onToggleAudio;
  final VoidCallback onTogglePower;
  final VoidCallback onToggleControls;
  final VoidCallback onToggleNotifications;
  final VoidCallback onToggleClock;
  final VoidCallback onToggleSessionLauncher;
  final ValueChanged<bool> onSetNetworkWifiEnabled;
  final void Function(NetworkEntry entry, String? password) onConnectNetwork;
  final VoidCallback onOpenNetworkSettings;
  final void Function(AudioEndpointKind kind, int volume) onSetAudioVolume;
  final void Function(AudioEndpointKind kind, {required bool muted})
  onSetAudioMuted;
  final ValueChanged<int> onSetBrightness;
  final VoidCallback onOpenAudioMixer;
  final ValueChanged<PowerProfile> onSetPowerProfile;
  final ValueChanged<ScreenshotMode> onCaptureScreenshot;
  final VoidCallback onPickColor;
  final VoidCallback onToggleRecording;
  final VoidCallback onOpenSettings;
  final ValueChanged<String> onControlToast;
  final void Function(String id, Offset position) onActivateTrayItem;
  final void Function(String id, Offset position) onOpenTrayContextMenu;
  final void Function(String itemId, int menuItemId) onActivateTrayMenuItem;
  final ValueChanged<int> onDismissNotification;
  final VoidCallback onClearNotifications;
  final ValueChanged<bool> onSetDoNotDisturb;
  final ValueChanged<bool> onSetNightLight;
  final ValueChanged<bool> onSetCaffeine;
  final ValueChanged<CalendarCommand> onClockCommand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NotificationStatus? notificationStatus = ref.watch(
      currentNotificationStatusProvider,
    );
    final TrayStatus? trayStatus = ref.watch(currentTrayStatusProvider);
    final TrayMenuStatus? trayMenuStatus = ref.watch(
      currentTrayMenuStatusProvider,
    );
    final ClockViewState clockView = ref.watch(clockViewProvider);
    final AsyncValue<PowerStatus> powerStatus = ref.watch(powerStatusProvider);

    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const HyprDivider(),
            if (showSystemTray)
              if (trayStatus case final TrayStatus status
                  when status.items.isNotEmpty) ...<Widget>[
                LayerShellDropdown(
                  controller: trayMenuController,
                  menuRadius: audioRadius,
                  menuWidth: 300,
                  horizontalAnchor: LayerShellDropdownAnchor.right,
                  transition: LayerShellDropdownTransition.grow,
                  buttonBuilder:
                      (
                        BuildContext context,
                        LayerShellDropdownController controller, {
                        required bool isOpen,
                      }) {
                        return TrayStrip(
                          status: status,
                          onActivate: onActivateTrayItem,
                          onContextMenu: onOpenTrayContextMenu,
                        );
                      },
                  menuBuilder:
                      (
                        BuildContext context,
                        LayerShellDropdownController controller,
                      ) {
                        return TrayMenuPanel(
                          menu: trayMenuStatus,
                          borderRadius: audioRadius,
                          onActivateItem: (String itemId, int menuItemId) {
                            onActivateTrayMenuItem(itemId, menuItemId);
                            controller.close();
                          },
                        );
                      },
                ),
                const HyprDivider(),
              ],
            LayerShellDropdown(
              controller: networkController,
              menuRadius: networkRadius,
              buttonBuilder:
                  (
                    BuildContext context,
                    LayerShellDropdownController controller, {
                    required bool isOpen,
                  }) {
                    return BarIconActionButton(
                      label: 'Network',
                      icon: Iconsax.link_copy,
                      isOpen: isOpen,
                      onPressed: onToggleNetwork,
                    );
                  },
              menuBuilder:
                  (
                    BuildContext context,
                    LayerShellDropdownController controller,
                  ) {
                    return Consumer(
                      builder:
                          (BuildContext context, WidgetRef ref, Widget? child) {
                            return NetworkPanel(
                              borderRadius: networkRadius,
                              status: ref.watch(networkStatusProvider),
                              latestResult: ref
                                  .watch(networkCommandResultProvider)
                                  .asData
                                  ?.value,
                              onSetWifiEnabled: onSetNetworkWifiEnabled,
                              onConnect: onConnectNetwork,
                              onOpenSettings: onOpenNetworkSettings,
                            );
                          },
                    );
                  },
            ),
            if (showAudioDisplay) ...<Widget>[
              const SizedBox(width: 4),
              LayerShellDropdown(
                controller: audioController,
                menuRadius: audioRadius,
                buttonBuilder:
                    (
                      BuildContext context,
                      LayerShellDropdownController controller, {
                      required bool isOpen,
                    }) {
                      return AudioDisplayButton(
                        isOpen: isOpen,
                        onPressed: onToggleAudio,
                      );
                    },
                menuBuilder:
                    (
                      BuildContext context,
                      LayerShellDropdownController controller,
                    ) {
                      return Consumer(
                        builder:
                            (
                              BuildContext context,
                              WidgetRef ref,
                              Widget? child,
                            ) {
                              return AudioPanel(
                                borderRadius: audioRadius,
                                status: ref.watch(audioStatusProvider),
                                brightnessStatus: ref.watch(
                                  brightnessStatusProvider,
                                ),
                                onSetVolume: onSetAudioVolume,
                                onSetMuted: onSetAudioMuted,
                                onSetBrightness: onSetBrightness,
                                onOpenMixer: () {
                                  onOpenAudioMixer();
                                  controller.dismiss();
                                },
                              );
                            },
                      );
                    },
              ),
            ],
            const SizedBox(width: 4),
            LayerShellDropdown(
              controller: powerController,
              menuRadius: audioRadius,
              menuWidth: 320,
              buttonBuilder:
                  (
                    BuildContext context,
                    LayerShellDropdownController controller, {
                    required bool isOpen,
                  }) {
                    return BatteryChip(
                      status: powerStatus.asData?.value,
                      isOpen: isOpen,
                      onPressed: onTogglePower,
                    );
                  },
              menuBuilder:
                  (
                    BuildContext context,
                    LayerShellDropdownController controller,
                  ) {
                    return Consumer(
                      builder:
                          (BuildContext context, WidgetRef ref, Widget? child) {
                            return PowerPanel(
                              borderRadius: audioRadius,
                              status: ref.watch(powerStatusProvider),
                              latestResult: ref
                                  .watch(powerCommandResultProvider)
                                  .asData
                                  ?.value,
                              onSetProfile: onSetPowerProfile,
                            );
                          },
                    );
                  },
            ),
            LayerShellDropdown(
              controller: controlsController,
              menuRadius: audioRadius,
              menuWidth: 432,
              buttonBuilder:
                  (
                    BuildContext context,
                    LayerShellDropdownController controller, {
                    required bool isOpen,
                  }) {
                    return BarIconActionButton(
                      label: 'Controls',
                      icon: Iconsax.setting_5_copy,
                      isOpen: isOpen,
                      onPressed: onToggleControls,
                    );
                  },
              menuBuilder:
                  (
                    BuildContext context,
                    LayerShellDropdownController controller,
                  ) {
                    return Consumer(
                      builder:
                          (BuildContext context, WidgetRef ref, Widget? child) {
                            final NotificationStatus? liveNotificationStatus =
                                ref.watch(currentNotificationStatusProvider);
                            final NightLightStatus? nightLightStatus = ref
                                .watch(nightLightStatusProvider)
                                .asData
                                ?.value;
                            final CaffeineStatus? caffeineStatus = ref
                                .watch(caffeineStatusProvider)
                                .asData
                                ?.value;
                            final RecordingStatus? recordingStatus = ref
                                .watch(recordingStatusProvider)
                                .asData
                                ?.value;
                            return ControlsPanel(
                              borderRadius: audioRadius,
                              onCaptureScreenshot: onCaptureScreenshot,
                              onPickColor: onPickColor,
                              onToggleRecording: onToggleRecording,
                              onOpenSettings: onOpenSettings,
                              onToast: onControlToast,
                              dndEnabled:
                                  liveNotificationStatus?.dndEnabled ?? false,
                              onSetDoNotDisturb: onSetDoNotDisturb,
                              nightLightStatus: nightLightStatus,
                              onSetNightLight: onSetNightLight,
                              caffeineStatus: caffeineStatus,
                              onSetCaffeine: onSetCaffeine,
                              recordingStatus: recordingStatus,
                              shortcutLabels: ref.watch(shortcutLabelsProvider),
                            );
                          },
                    );
                  },
            ),
            if (showNotifications) ...<Widget>[
              const SizedBox(width: 4),
              LayerShellDropdown(
                controller: notificationController,
                menuRadius: audioRadius,
                menuWidth: kNotificationPanelWidth,
                horizontalAnchor: LayerShellDropdownAnchor.right,
                buttonBuilder:
                    (
                      BuildContext context,
                      LayerShellDropdownController controller, {
                      required bool isOpen,
                    }) {
                      return NotificationButton(
                        unreadCount: notificationStatus?.unreadCount ?? 0,
                        isOpen: isOpen,
                        onPressed: onToggleNotifications,
                      );
                    },
                menuBuilder:
                    (
                      BuildContext context,
                      LayerShellDropdownController controller,
                    ) {
                      return Consumer(
                        builder:
                            (
                              BuildContext context,
                              WidgetRef ref,
                              Widget? child,
                            ) {
                              return NotificationPanel(
                                borderRadius: audioRadius,
                                status: ref.watch(
                                  currentNotificationStatusProvider,
                                ),
                                onDismiss: onDismissNotification,
                                onClearAll: onClearNotifications,
                              );
                            },
                      );
                    },
              ),
            ],
            const HyprDivider(height: 18),
            LayerShellDropdown(
              controller: clockController,
              menuRadius: BorderRadius.zero,
              buttonBuilder:
                  (
                    BuildContext context,
                    LayerShellDropdownController controller, {
                    required bool isOpen,
                  }) {
                    return ClockButton(
                      status: clockView,
                      isOpen: isOpen,
                      onPressed: onToggleClock,
                    );
                  },
              menuBuilder:
                  (
                    BuildContext context,
                    LayerShellDropdownController controller,
                  ) {
                    return Consumer(
                      builder:
                          (BuildContext context, WidgetRef ref, Widget? child) {
                            return ClockPanel(
                              status: ref.watch(clockViewProvider),
                              onCommand: onClockCommand,
                              borderRadius: clockCardRadius,
                            );
                          },
                    );
                  },
            ),
            const HyprDivider(),
            KeyedSubtree(
              key: powerButtonAnchorKey,
              child: PowerButton(
                isOpen: sessionLauncherOpen,
                onPressed: onToggleSessionLauncher,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
