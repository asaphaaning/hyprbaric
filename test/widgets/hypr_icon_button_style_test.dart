import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/widgets/hypr_surface.dart';
import 'package:hyprbaric/src/widgets/primitives/primitives.dart';

void main() {
  test(
    'hyprCompactIconButtonStyle resolves idle, hover, and active colors',
    () {
      final ButtonStyle idle = hyprCompactIconButtonStyle(
        foregroundColor: HyprColors.textFaint,
        hoverForegroundColor: HyprColors.text,
        hoverBackgroundColor: HyprColors.hover,
      );

      expect(_foreground(idle, <WidgetState>{}), HyprColors.textFaint);
      expect(
        _foreground(idle, <WidgetState>{WidgetState.hovered}),
        HyprColors.text,
      );
      expect(_background(idle, <WidgetState>{}), Colors.transparent);
      expect(
        _background(idle, <WidgetState>{WidgetState.hovered}),
        HyprColors.hover,
      );

      final ButtonStyle active = hyprCompactIconButtonStyle(active: true);
      expect(_foreground(active, <WidgetState>{}), HyprColors.text);
      expect(_background(active, <WidgetState>{}), HyprColors.hoverStrong);
      expect(_side(active).color, HyprColors.border);
      expect(_side(active).width, 1.2);
    },
  );

  test('hyprCompactIconButtonStyle resolves danger palette', () {
    final ButtonStyle danger = hyprCompactIconButtonStyle(danger: true);

    expect(_foreground(danger, <WidgetState>{}), const Color(0xFFFF7B70));
    expect(
      _foreground(danger, <WidgetState>{WidgetState.hovered}),
      const Color(0xFFFF8D82),
    );
    expect(_background(danger, <WidgetState>{}), const Color(0x1EE16658));
    expect(
      _background(danger, <WidgetState>{WidgetState.hovered}),
      const Color(0x33E16658),
    );

    final ButtonStyle activeDanger = hyprCompactIconButtonStyle(
      active: true,
      danger: true,
    );
    expect(_background(activeDanger, <WidgetState>{}), const Color(0x29E16658));
    expect(_side(activeDanger).color, const Color(0x99E16658));
  });

  test('hyprCompactIconButtonStyle applies compact dimensions', () {
    final ButtonStyle style = hyprCompactIconButtonStyle(
      size: const Size(28, 26),
      radius: 7,
    );

    expect(style.minimumSize?.resolve(<WidgetState>{}), const Size(28, 26));
    expect(style.fixedSize?.resolve(<WidgetState>{}), const Size(28, 26));
    expect(
      style.overlayColor?.resolve(<WidgetState>{WidgetState.pressed}),
      Colors.transparent,
    );
    expect(style.splashFactory, NoSplash.splashFactory);
    final RoundedSuperellipseBorder shape =
        style.shape!.resolve(<WidgetState>{})! as RoundedSuperellipseBorder;
    expect(shape.borderRadius, BorderRadius.circular(7));
  });
}

Color _foreground(ButtonStyle style, Set<WidgetState> states) {
  return style.foregroundColor!.resolve(states)!;
}

Color? _background(ButtonStyle style, Set<WidgetState> states) {
  return style.backgroundColor!.resolve(states);
}

BorderSide _side(ButtonStyle style) {
  return style.side!.resolve(<WidgetState>{})!;
}
