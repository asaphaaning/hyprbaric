/// Shared duration vocabulary for Hyprbaric UI and transient feedback.
///
/// `HyprMotion` owns the curve vocabulary. This type names the timing values so
/// non-animated state, timers, and widgets can share the same closed scale.
abstract final class HyprDurations {
  static const Duration queryDebounce = Duration(milliseconds: 35);
  static const Duration pressed = Duration(milliseconds: 60);

  /// Rate limit for pushing a dragged value at its backend.
  static const Duration commit = Duration(milliseconds: 75);

  /// Tracks a value the pointer is actively dragging.
  static const Duration scrub = Duration(milliseconds: 80);
  static const Duration hover = Duration(milliseconds: 120);
  static const Duration selection = Duration(milliseconds: 130);
  static const Duration switcher = Duration(milliseconds: 180);
  static const Duration popup = Duration(milliseconds: 220);
  static const Duration workspace = Duration(milliseconds: 260);
  static const Duration toast = Duration(milliseconds: 280);
  static const Duration growPopup = Duration(milliseconds: 360);

  /// A selection plate gliding between neighbouring controls.
  static const Duration plate = Duration(milliseconds: 520);

  /// The quieter plate trailing the pointer between controls.
  static const Duration plateHover = Duration(milliseconds: 300);

  /// Content turning over in place, such as the window title.
  static const Duration flip = Duration(milliseconds: 240);

  /// A digit rolling over to its next value.
  static const Duration roll = Duration(milliseconds: 620);

  /// The bar easing into place when it first appears.
  static const Duration entrance = Duration(milliseconds: 900);

  /// One popover handing its shell to the next, e.g. mixer to power.
  static const Duration handoff = Duration(milliseconds: 500);
  static const Duration osdPeakTick = Duration(milliseconds: 60);
  static const Duration osdLifetime = Duration(milliseconds: 1500);

  /// How long a control shows its own value before deferring to a backend.
  static const Duration previewHold = Duration(milliseconds: 2000);
  static const Duration toastLifetime = Duration(milliseconds: 3800);
}
