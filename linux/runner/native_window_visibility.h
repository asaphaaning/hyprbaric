#ifndef FLUTTER_NATIVE_WINDOW_VISIBILITY_H_
#define FLUTTER_NATIVE_WINDOW_VISIBILITY_H_

/// The presentation phase of one monitor-bound native window.
enum class NativeWindowVisibility {
  /// The monitor target excludes the window, so it must remain unmapped.
  kHidden,
  /// The target includes the window, but Flutter still needs to render a frame.
  kPriming,
  /// Flutter has rendered and the selected window can be presented normally.
  kVisible,
};

/// Resolves the native presentation phase from target selection and rendering.
constexpr NativeWindowVisibility
native_window_visibility(bool selected, bool first_frame_rendered) {
  if (!selected) {
    return NativeWindowVisibility::kHidden;
  }

  return first_frame_rendered ? NativeWindowVisibility::kVisible
                              : NativeWindowVisibility::kPriming;
}

#endif // FLUTTER_NATIVE_WINDOW_VISIBILITY_H_
