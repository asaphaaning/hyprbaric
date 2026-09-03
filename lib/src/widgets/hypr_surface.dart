import 'surfaces/hypr_colors.dart';
import 'surfaces/hypr_glass_surface.dart';
import 'surfaces/hypr_surface_frame.dart';

export '../theme/hypr_tokens.dart';
export 'surfaces/hypr_colors.dart';
export 'surfaces/hypr_console.dart';
export 'surfaces/hypr_console_colors.dart';
export 'surfaces/hypr_divider.dart';
export 'surfaces/hypr_glass_frame.dart';
export 'surfaces/hypr_glass_surface.dart';
export 'surfaces/hypr_inset_border.dart';
export 'surfaces/hypr_popover_surface.dart';
export 'surfaces/hypr_surface_frame.dart';
export 'surfaces/hypr_typography.dart';

class HyprSurface extends HyprGlassSurface {
  const HyprSurface({
    super.key,
    required super.child,
    required super.borderRadius,
    super.color = HyprColors.surface,
    super.borderColor = HyprColors.border,
    super.blur = 18,
    super.shadow = false,
    super.inset = true,
    super.frame = HyprSurfaceFrame.panel,
  });
}
