import 'package:flutter/material.dart';

/// Whether a formatted label pops character by character or as one unit.
enum HyprPopUnit {
  /// Preserve unchanged characters in decimal readouts.
  character,

  /// Replace a whole label, including Roman numerals and workspace names.
  label,
}

/// Animates only changed characters in a formatted number, aligned from right.
/// Outgoing characters are excluded from accessibility and pointer handling.
class HyprDigitPop extends StatelessWidget {
  const HyprDigitPop({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 220),
    this.unit = HyprPopUnit.character,
  });

  /// A number already formatted by its domain, including sign and decimal point.
  final String value;

  /// Typography shared with the surrounding instrument.
  final TextStyle style;

  /// Time for the last changed character to settle.
  final Duration duration;

  /// The unit of content that changes together.
  final HyprPopUnit unit;

  @override
  Widget build(BuildContext context) {
    final parts = switch (unit) {
      HyprPopUnit.character => value.characters.toList(),
      HyprPopUnit.label => [value],
    };
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(
        value,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.clip,
      );
    }
    final labels = <Widget>[
      for (var index = 0; index < parts.length; index++)
        AnimatedSwitcher(
          key: ValueKey(parts.length - index),
          duration: duration,
          switchInCurve: Interval(
            (index * .045).clamp(0, .3),
            1,
            curve: Curves.easeOutCubic,
          ),
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.center,
            children: [if (previous.isNotEmpty) previous.last, ?current],
          ),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, .32),
                end: Offset.zero,
              ).animate(animation),
              child: ScaleTransition(
                scale: Tween(begin: .82, end: 1.0).animate(animation),
                child: child,
              ),
            ),
          ),
          child: Text(
            parts[index],
            key: ValueKey(parts[index]),
            style: style,
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),
    ];
    return Semantics(
      label: value,
      child: ExcludeSemantics(
        child: unit == HyprPopUnit.label
            ? labels.single
            : Row(mainAxisSize: MainAxisSize.min, children: labels),
      ),
    );
  }
}
