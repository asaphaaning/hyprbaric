import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bindings/bindings.dart';
import '../layer_shell_controller.dart';
import 'layer_shell.dart';
import 'monitor_workspace.dart';
import 'rust_signals.dart';
import 'workspaces.dart';

class FocusedWindowDisplay {
  const FocusedWindowDisplay({
    required this.title,
    this.appName,
    this.isFallback = false,
    this.isHidden = false,
  });

  const FocusedWindowDisplay.hidden()
    : appName = null,
      title = '',
      isFallback = true,
      isHidden = true;

  final String? appName;
  final String title;
  final bool isFallback;
  final bool isHidden;

  bool get hasAppTitleSplit {
    if (isHidden) {
      return false;
    }
    final String? app = appName;
    return app != null && app.toLowerCase() != title.toLowerCase();
  }

  String get tooltip {
    if (isHidden) {
      return '';
    }
    final String? app = appName;
    if (app == null || !hasAppTitleSplit) {
      return title;
    }
    return '$app - $title';
  }
}

String? _trimmed(String? value) {
  final String? trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _displayTitle(FocusedWindowStatus status) {
  return focusedWindowDisplay(status).title;
}

/// Resolves the focused-window label for one Hyprland output.
///
/// When [monitorName] cannot be resolved, compositor-wide focus is retained as
/// a conservative fallback. An explicitly empty per-monitor entry represents a
/// visible workspace with no focused client and therefore hides the label.
FocusedWindowDisplay focusedWindowDisplay(
  FocusedWindowStatus status, {
  String? monitorName,
}) {
  final MonitorFocusedWindowStatus? monitor = _monitorWindow(
    status.monitors,
    monitorName,
  );
  return _displayValues(
    appName: monitor == null ? status.appName : monitor.appName,
    title: monitor == null ? status.title : monitor.title,
    hostname: status.hostname,
    emptyDesktop:
        monitor != null &&
        _trimmed(monitor.appName) == null &&
        _trimmed(monitor.title) == null,
  );
}

FocusedWindowDisplay _displayValues({
  required String? appName,
  required String? title,
  required String hostname,
  required bool emptyDesktop,
}) {
  final String? displayAppName = _displayAppName(appName);
  final String? displayTitle = _trimmed(title);
  final String displayHostname = _trimmed(hostname) ?? 'Hyprbaric';
  if (emptyDesktop || _isEmptyDesktopStatus(appName, title, displayHostname)) {
    return const FocusedWindowDisplay.hidden();
  }
  if (displayTitle == null) {
    if (displayAppName != null) {
      return FocusedWindowDisplay(
        appName: displayAppName,
        title: displayAppName,
      );
    }
    return FocusedWindowDisplay(title: displayHostname, isFallback: true);
  }
  return FocusedWindowDisplay(appName: displayAppName, title: displayTitle);
}

MonitorFocusedWindowStatus? _monitorWindow(
  List<MonitorFocusedWindowStatus> monitors,
  String? monitorName,
) {
  if (monitorName == null) {
    return null;
  }

  for (final MonitorFocusedWindowStatus monitor in monitors) {
    if (monitor.monitorName == monitorName) {
      return monitor;
    }
  }

  return null;
}

bool _isEmptyDesktopStatus(
  String? appNameValue,
  String? titleValue,
  String hostname,
) {
  final String? title = _trimmed(titleValue);
  final String? appName = _trimmed(appNameValue);
  if (_isDesktopToken(title)) {
    return true;
  }
  if (title != null) {
    return false;
  }
  return _isDesktopToken(appName) ||
      (appName == null && _isDesktopToken(hostname));
}

bool _isDesktopToken(String? value) {
  final String? trimmed = _trimmed(value);
  if (trimmed == null) {
    return false;
  }
  final String normalized = trimmed
      .replaceFirst(RegExp(r'\.desktop$', caseSensitive: false), '')
      .toLowerCase();
  return normalized == 'desktop';
}

String? _displayAppName(String? value) {
  final String? trimmed = _trimmed(value);
  if (trimmed == null) {
    return null;
  }

  final String withoutDesktopSuffix = trimmed.replaceFirst(
    RegExp(r'\.desktop$', caseSensitive: false),
    '',
  );
  final String candidate = _reverseDnsTail(withoutDesktopSuffix);
  final List<String> words = candidate
      .split(RegExp(r'[\s._-]+'))
      .where((String word) => word.isNotEmpty)
      .map(_titleCaseWord)
      .toList(growable: false);
  if (words.isEmpty) {
    return null;
  }
  return words.join(' ');
}

String _reverseDnsTail(String value) {
  final List<String> parts = value
      .split('.')
      .where((String part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.length < 3) {
    return value;
  }
  final String prefix = parts.first.toLowerCase();
  if (prefix == 'app' ||
      prefix == 'com' ||
      prefix == 'dev' ||
      prefix == 'io' ||
      prefix == 'net' ||
      prefix == 'org') {
    return parts.last;
  }
  return value;
}

String _titleCaseWord(String word) {
  if (word.length <= 4 && word == word.toUpperCase()) {
    return word;
  }
  final String lower = word.toLowerCase();
  return lower[0].toUpperCase() + lower.substring(1);
}

/// Raw focused-window updates emitted from Rust via RINF.
final currentFocusedWindowStatusProvider = focusedWindowStatusProvider;

/// Human-friendly center label for the active window slot.
final currentWindowTitleProvider = Provider<String>((ref) {
  final AsyncValue<FocusedWindowStatus> status = ref.watch(
    currentFocusedWindowStatusProvider,
  );
  return status.maybeWhen(data: _displayTitle, orElse: () => 'Hyprbaric');
});

/// Structured center slot text for the app/title split treatment.
final currentWindowDisplayProvider = Provider<FocusedWindowDisplay>((ref) {
  final AsyncValue<FocusedWindowStatus> status = ref.watch(
    currentFocusedWindowStatusProvider,
  );
  final AsyncValue<WorkspaceStatus> workspace = ref.watch(
    currentWorkspaceStatusProvider,
  );
  final LayerShellMonitor? output = ref
      .watch(layerShellCurrentMonitorProvider)
      .asData
      ?.value;
  return status.maybeWhen(
    data: (FocusedWindowStatus value) {
      final String? monitorName = workspace.asData == null
          ? null
          : resolveMonitorWorkspace(
              workspace.asData!.value,
              output,
            ).monitorName;
      return focusedWindowDisplay(value, monitorName: monitorName);
    },
    orElse: () =>
        const FocusedWindowDisplay(title: 'Hyprbaric', isFallback: true),
  );
});
