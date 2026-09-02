import 'package:flutter/material.dart';

import '../bindings/bindings.dart';
import 'hypr_surface.dart';

abstract final class NotificationPalette {
  static const Color fg1 = Color(0xECCBD2DA);
  static const Color fg2 = Color(0xC0ADB6C0);
  static const Color fg3 = Color(0xA0929DA8);
  static const Color warmTime = Color(0xD9CBB29E);

  static const Color tile = Color(0xE60B0C0E);
  static const Color placeholderFill = Color(0x66000000);
  static const Color placeholderStroke = Color(0x8C000000);
  static const Color tileHovered = Color(0xEB121314);
}

enum NotificationTilePhase { idle, hovered }

@immutable
class NotificationTileStyle {
  const NotificationTileStyle({
    required this.base,
    required this.topLight,
    required this.border,
    required this.shadow,
  });

  final Color base;
  final Color topLight;
  final Color border;
  final Color shadow;

  factory NotificationTileStyle.forPhase(NotificationTilePhase phase) {
    return switch (phase) {
      NotificationTilePhase.idle => const NotificationTileStyle(
        base: NotificationPalette.tile,
        topLight: Color(0x0EFFFFFF),
        border: NotificationPalette.tileBorder,
        shadow: Color(0x52000000),
      ),
      NotificationTilePhase.hovered => const NotificationTileStyle(
        base: NotificationPalette.tileHovered,
        topLight: Color(0x13FFFFFF),
        border: NotificationPalette.tileBorder,
        shadow: Color(0x57000000),
      ),
    };
  }
}

Color notificationAccent(NotificationEntry entry) {
  return switch (entry.urgency) {
    NotificationUrgency.critical => HyprColors.danger,
    NotificationUrgency.low => _badgeColor(entry.app).withValues(alpha: 0.82),
    NotificationUrgency.normal => _badgeColor(entry.app),
  };
}

/// Widest span [DateTime.fromMillisecondsSinceEpoch] accepts.
const int _maxRepresentableMs = 8640000000000000;

String notificationAgeLabel(Uint64 createdAtMs, {DateTime? now}) {
  final DateTime observedAt = now ?? DateTime.now();
  // Uint64.toInt() clamps to the int64 bound rather than throwing, and that
  // clamped value is far outside the range DateTime accepts, so an absurd
  // created_at_ms would otherwise throw a RangeError out of the panel build.
  final int createdMs = createdAtMs.toInt();
  if (createdMs.abs() > _maxRepresentableMs) {
    return 'now';
  }
  final Duration age = observedAt.difference(
    DateTime.fromMillisecondsSinceEpoch(createdMs),
  );
  // Negative ages come from clock skew. Nothing is older than the present.
  if (age.inSeconds < 60) {
    return 'now';
  }
  if (age.inMinutes < 60) {
    return '${age.inMinutes}m ago';
  }
  if (age.inHours < 24) {
    return '${age.inHours}h ago';
  }
  return '${age.inDays}d ago';
}

Color _badgeColor(String name) {
  const List<Color> palette = <Color>[
    Color(0xFF9BA8B8),
    Color(0xFF8C83CA),
    Color(0xFFB486C5),
    Color(0xFFC8857C),
    Color(0xFFC5A879),
    Color(0xFF75AE91),
    Color(0xFF78A8B7),
  ];
  final int hash = name.codeUnits.fold<int>(
    0,
    (int value, int unit) => 0x1fffffff & (value * 31 + unit),
  );
  return palette[hash % palette.length];
}
