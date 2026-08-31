/// Production UI and typed fixtures exposed to Hyprbaric's isolated catalogs.
library;

export 'src/bindings/bindings.dart'
    show
        NotificationEntry,
        NotificationStatus,
        NotificationUrgency,
        PowerBatteryState,
        PowerCommandResult,
        PowerCommandResultFailed,
        PowerCommandSetProfile,
        PowerProfile,
        PowerStatus,
        Uint64;
export 'src/features/power/battery_chip.dart' show BatteryChip;
export 'src/features/power/power_panel.dart' show PowerPanel;
export 'src/features/power/power_profile_pad.dart' show PowerProfilePad;
export 'src/theme/hypr_palette.dart' show HyprPalette;
export 'src/widgets/hypr_surface.dart';
export 'src/widgets/notification_panel.dart' show NotificationPanel;
export 'src/widgets/notification_panel_parts.dart'
    show
        NotificationCountPill,
        NotificationEmptyState,
        NotificationHeader,
        NotificationList;
export 'src/widgets/notification_row.dart' show NotificationRow;
export 'src/widgets/primitives/hypr_action_row.dart' show HyprActionRow;
export 'src/widgets/primitives/hypr_badge.dart' show HyprBadge;
export 'src/widgets/primitives/hypr_toggle_switch.dart' show HyprToggleSwitch;
export 'src/widgets/right_cluster_buttons.dart' show NotificationButton;
