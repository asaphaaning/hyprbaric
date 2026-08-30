import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../bindings/bindings.dart';
import 'hypr_surface.dart';

abstract final class NotificationPalette {
  static const Color fg1 = Color(0xECCBD2DA);
  static const Color fg2 = Color(0xC0ADB6C0);
  static const Color fg3 = Color(0xA0929DA8);
  static const Color warmTime = Color(0xD9CBB29E);

  static const Color chassisTop = Color(0x800E1015);
  static const Color chassisBottom = Color(0x8F090C10);
  static const Color tile = Color(0xE60B0C0E);
  static const Color tileHovered = Color(0xEB121314);
  static const Color tilePressed = Color(0xF007080A);
}

enum NotificationTilePhase { idle, hovered, pressed }

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
        topLight: Color(0x09FFFFFF),
        border: Color(0x8C000000),
        shadow: Color(0x66000000),
      ),
      NotificationTilePhase.hovered => const NotificationTileStyle(
        base: NotificationPalette.tileHovered,
        topLight: Color(0x0EFFFFFF),
        border: Color(0x99000000),
        shadow: Color(0x66000000),
      ),
      NotificationTilePhase.pressed => const NotificationTileStyle(
        base: NotificationPalette.tilePressed,
        topLight: Color(0x05FFFFFF),
        border: Color(0x99000000),
        shadow: Color(0x73000000),
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

String notificationAgeLabel(Uint64 createdAtMs, {DateTime? now}) {
  final DateTime observedAt = now ?? DateTime.now();
  final Duration age = observedAt.difference(
    DateTime.fromMillisecondsSinceEpoch(createdAtMs.toInt()),
  );
  if (age.inSeconds < 60) {
    return 'now';
  }
  if (age.inMinutes < 60) {
    return '${math.max(1, age.inMinutes)}m ago';
  }
  if (age.inHours < 24) {
    return '${age.inHours}h ago';
  }
  return '${age.inDays}d ago';
}

Color _badgeColor(String name) {
  final Color? referenceColor = switch (name.toLowerCase()) {
    'github' => const Color(0xFF8190A8),
    'discord' => const Color(0xFF6684FB),
    'system' => const Color(0xFF5480C7),
    _ => null,
  };
  if (referenceColor != null) {
    return referenceColor;
  }

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
