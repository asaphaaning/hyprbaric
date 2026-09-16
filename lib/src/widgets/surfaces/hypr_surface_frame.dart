/// Which chassis treatment a surface wears.
///
/// The frame selects the inset lighting in [HyprInsetBorder]: [panel] carries
/// the full top/bottom inset pair, [popover] holds its top sheen clear of the
/// corner arcs (the rings live on the chrome painter), and [card] is the
/// lightweight variant used by tiles nested inside a panel.
enum HyprSurfaceFrame {
  /// Full panel lighting with a feathered top and bottom inset.
  panel,

  /// Bar lighting with a uniform rounded inset outline, without fading.
  bar,

  /// Floating chrome with a corner-safe top sheen.
  popover,

  /// Lightweight lighting for a tile nested inside a panel.
  card,
}
