import 'package:flutter/widgets.dart';

import '../../theme/hypr_motion.dart';
import 'hypr_flip.dart';

/// Text whose digits roll over individually when they change, like an
/// odometer; other characters stay put.
///
/// Each position keeps its own roll, so a minute ticking over only moves the
/// digits that changed. Use a tabular style so positions keep their width.
class HyprRollingText extends StatelessWidget {
  const HyprRollingText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  static bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

  @override
  Widget build(BuildContext context) {
    final double travel = (style.fontSize ?? 14) * 1.1;
    final List<int> units = text.codeUnits;
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int index = 0; index < units.length; index++)
            if (_isDigit(units[index]))
              KeyedSubtree(
                key: ValueKey<int>(index),
                child: ClipRect(
                  child: HyprFlip(
                    flipKey: units[index],
                    distance: travel,
                    duration: HyprMotion.roll,
                    child: Text(
                      String.fromCharCode(units[index]),
                      style: style,
                    ),
                  ),
                ),
              )
            else
              Text(
                String.fromCharCode(units[index]),
                key: ValueKey<int>(index),
                style: style,
              ),
        ],
      ),
    );
  }
}
