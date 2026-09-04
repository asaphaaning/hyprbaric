/// Which chassis treatment a surface wears.
///
/// The frame selects the inset lighting in [HyprInsetBorder]: [panel] carries
/// the full top/bottom inset pair, [popover] adds the inner ring and holds its
/// single line clear of the corner arcs, and [card] is the lightweight variant
/// used by tiles nested inside a panel.
enum HyprSurfaceFrame { panel, popover, card }
