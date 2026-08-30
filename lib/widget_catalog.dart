/// Production UI and typed fixtures exposed to Hyprbaric's isolated catalogs.
library;

export 'src/bindings/bindings.dart'
    show PowerBatteryState, PowerProfile, PowerStatus;
export 'src/features/power/battery_chip.dart' show BatteryChip;
export 'src/theme/hypr_palette.dart' show HyprPalette;
export 'src/widgets/hypr_surface.dart';
export 'src/widgets/primitives/hypr_action_row.dart' show HyprActionRow;
export 'src/widgets/primitives/hypr_badge.dart' show HyprBadge;
export 'src/widgets/primitives/hypr_toggle_switch.dart' show HyprToggleSwitch;
