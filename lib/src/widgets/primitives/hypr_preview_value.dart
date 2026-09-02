import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../theme/hypr_tokens.dart';

/// A locally previewed value that defers to its backend on a bounded window.
///
/// Backends rarely echo the exact value that was sent: PipeWire rounds
/// percentages, and a failed brightness write resyncs to whatever the hardware
/// actually holds. Clearing a preview only on an exact match therefore strands
/// it forever, leaving a readout showing a value nothing ever took. Holding it
/// for a window instead keeps the control responsive while guaranteeing the
/// backend wins in the end.
///
/// [scope] identifies what the preview belongs to, such as an endpoint id. A
/// preview is dropped as soon as its scope changes.
class HyprPreviewValue extends ChangeNotifier {
  HyprPreviewValue({this.hold = HyprDurations.previewHold});

  /// How long a preview survives without the backend confirming it.
  final Duration hold;

  Timer? _expiry;
  Object? _scope;
  int? _value;

  /// The previewed value, or null when the backend is authoritative.
  int? get value => _value;

  bool get isActive => _value != null;

  /// Records a locally chosen value and restarts the hold window.
  void show(int value, {Object? scope}) {
    _scope = scope;
    if (_value != value) {
      _value = value;
      notifyListeners();
    }
    _expiry?.cancel();
    _expiry = Timer(hold, _expire);
  }

  /// Reconciles against what the backend now reports.
  ///
  /// Returns the value that should be displayed.
  int? settle(int? backendValue, {Object? scope}) {
    if (_value == null) {
      return backendValue;
    }
    if (scope != _scope || backendValue == _value) {
      clear();
      return backendValue;
    }
    return _value;
  }

  void clear() {
    _expiry?.cancel();
    _expiry = null;
    _scope = null;
    if (_value != null) {
      _value = null;
      notifyListeners();
    }
  }

  void _expire() {
    _expiry = null;
    if (_value != null) {
      _value = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }
}
