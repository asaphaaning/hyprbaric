import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// The module shortcuts shown in the website bar.
///
/// Glyphs are the Iconsax outline set from the bar: link, sun, flash,
/// setting-5, and bell, stroked through [BarGlyphIcon].
enum SiteModule {
  /// Connection details and live traffic.
  network(
    'Network',
    'Throughput and ping, Wi-Fi networks in range, and interface addresses.',
    Iconsax.link_copy,
  ),

  /// Audio levels and screen brightness.
  mixer(
    'Volume & brightness',
    'Output and input levels with live meters, and screen brightness.',
    Iconsax.sun_1_copy,
  ),

  /// Battery charge and power profiles.
  power(
    'Battery & power profiles',
    'Charge level, time remaining, and the active power profile.',
    Iconsax.flash_circle_copy,
  ),

  /// Desktop capture and quick toggles.
  controls(
    'Controls & toggles',
    'Colour picking, do not disturb, night light, caffeine, capture, and recording.',
    Iconsax.setting_5_copy,
  ),

  /// The current notification inbox.
  notifications(
    'Notification centre',
    'A compact current-session inbox with per-item dismissal and a clear-all action.',
    Iconsax.notification_copy,
  );

  const SiteModule(this.title, this.description, this.icon);

  /// The human-readable module name.
  final String title;

  /// The short introduction displayed on hover or focus.
  final String description;

  /// The bar glyph identifying this module.
  final IconData icon;
}

/// A module introduction anchored in the iframe's logical coordinates.
class ModuleHint {
  const ModuleHint(this.module, this.rect);

  /// The module being introduced.
  final SiteModule module;

  /// Bounds of its bar button, used by the host to place the tooltip.
  final Rect rect;
}

/// A ripple-free module shortcut; its tooltip is painted by the page host.
class SiteModuleButton extends StatelessWidget {
  const SiteModuleButton({
    super.key,
    required this.module,
    required this.onPressed,
    this.onHint,
  });

  final SiteModule module;
  final VoidCallback onPressed;
  final ValueChanged<ModuleHint?>? onHint;

  @override
  Widget build(BuildContext context) {
    void show() {
      final RenderObject? object = context.findRenderObject();
      if (object is RenderBox && object.hasSize) {
        onHint?.call(
          ModuleHint(module, object.localToGlobal(Offset.zero) & object.size),
        );
      }
    }

    return Focus(
      onFocusChange: (focused) => focused ? show() : onHint?.call(null),
      child: MouseRegion(
        onEnter: (_) => show(),
        onExit: (_) => onHint?.call(null),
        child: IconButton(
          onPressed: () {
            onHint?.call(null);
            onPressed();
          },
          style: hyprCompactIconButtonStyle(
            size: HyprIconSizes.barButton,
            radius: HyprRadii.panel,
          ),
          icon: Semantics(
            label: '${module.title}. ${module.description}. Explore modules.',
            child: BarGlyphIcon(icon: module.icon, size: HyprIconSizes.bar),
          ),
        ),
      ),
    );
  }
}
