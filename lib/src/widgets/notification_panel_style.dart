import 'package:flutter/material.dart';

import '../bindings/bindings.dart';
import 'hypr_surface.dart';

abstract final class NotificationPalette {
  static const Color fg1 = HyprInstrumentColors.text;
  static const Color fg2 = HyprInstrumentColors.secondary;
  static const Color fg3 = HyprInstrumentColors.secondary;

  static const Color tile = Color(0x40151C2A);
  static const Color tileHovered = Color(0x60414A62);
  static const Color tileBorder = Color(0x6051607D);
}

/// Presentation identity parsed once at the external application-name boundary.
enum NotificationSource {
  github,
  discord,
  system,
  other;

  static NotificationSource fromName(String name) =>
      switch (name.toLowerCase()) {
        'github' => github,
        'discord' => discord,
        'system' => system,
        _ => other,
      };

  IconData get icon => switch (this) {
    github => Icons.code_rounded,
    discord => Icons.forum_rounded,
    system => Icons.settings_rounded,
    other => Icons.apps_rounded,
  };

  Color? get accent => switch (this) {
    github => const Color(0xFFBA97FF),
    discord => const Color(0xFF32DFDE),
    system => const Color(0xFFFF7D86),
    other => null,
  };
}

Color notificationAccent(NotificationEntry entry) {
  final source = NotificationSource.fromName(entry.app);
  return switch (entry.urgency) {
    NotificationUrgency.critical => const Color(0xFFFF7D86),
    NotificationUrgency.low => source.accent ?? _badgeColor(entry.app),
    NotificationUrgency.normal => source.accent ?? _badgeColor(entry.app),
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
