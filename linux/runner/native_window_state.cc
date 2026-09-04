#include "native_window_state.h"

#include "monitor.h"
#include "native_window_visibility.h"

namespace {
constexpr char kNativeWindowStateKey[] = "hyprbaric-native-window-state";

void native_window_state_free(gpointer data) {
  auto *state = static_cast<NativeWindowState *>(data);
  g_clear_object(&state->monitor);
  delete state;
}

gboolean should_show(const NativeWindowState *state) {
  switch (state->monitor_target) {
  case HYPRBARIC_NATIVE_LAYER_SHELL_MONITOR_TARGET_KIND_PRIMARY:
    return state->monitor_is_primary;
  case HYPRBARIC_NATIVE_LAYER_SHELL_MONITOR_TARGET_KIND_ALL:
    return TRUE;
  case HYPRBARIC_NATIVE_LAYER_SHELL_MONITOR_TARGET_KIND_NAMED:
    return state->monitor_name == state->named_monitor_target ||
           (state->monitor_is_primary &&
            !hyprbaric_has_monitor(state->named_monitor_target));
  case HYPRBARIC_NATIVE_LAYER_SHELL_MONITOR_TARGET_KIND_HIDDEN:
    return FALSE;
  }
  return state->monitor_is_primary;
}

void apply_visibility(NativeWindowState *state) {
  if (state == nullptr || state->window == nullptr) {
    return;
  }

  GtkWidget *window = GTK_WIDGET(state->window);
  switch (native_window_visibility(should_show(state),
                                   state->first_frame_rendered)) {
  case NativeWindowVisibility::kHidden:
    g_debug("Hiding Hyprbaric window on monitor '%s'",
            state->monitor_name.c_str());
    gtk_widget_hide(window);
    return;
  case NativeWindowVisibility::kPriming:
    g_debug("Priming Hyprbaric window on monitor '%s' for its first frame",
            state->monitor_name.c_str());
    gtk_widget_set_opacity(window, 0.0);
    gtk_widget_show(window);
    return;
  case NativeWindowVisibility::kVisible:
    g_debug("Showing Hyprbaric window on monitor '%s'",
            state->monitor_name.c_str());
    gtk_widget_set_opacity(window, 1.0);
    gtk_widget_show(window);
    return;
  }
}
} // namespace

NativeWindowState *native_window_state_attach(GtkWindow *window,
                                              GtkWidget *view,
                                              GdkMonitor *monitor,
                                              gboolean layer_shell_available,
                                              const char *monitor_name,
                                              gboolean monitor_is_primary) {
  auto *state = new NativeWindowState();
  state->window = window;
  state->view = view;
  state->monitor =
      monitor != nullptr ? GDK_MONITOR(g_object_ref(monitor)) : nullptr;
  state->layer_shell_available = layer_shell_available;
  state->monitor_name = monitor_name != nullptr ? monitor_name : "Primary";
  state->monitor_is_primary = monitor_is_primary;

  g_object_set_data_full(G_OBJECT(window), kNativeWindowStateKey, state,
                         native_window_state_free);
  return state;
}

void native_window_state_first_frame(NativeWindowState *state) {
  if (state == nullptr) {
    return;
  }
  state->first_frame_rendered = TRUE;
  apply_visibility(state);
}

void native_window_state_set_monitor_target(
    NativeWindowState *state, HyprbaricNativeLayerShellMonitorTargetKind target,
    const char *monitor_name) {
  if (state == nullptr) {
    return;
  }
  state->monitor_target = target;
  state->named_monitor_target = monitor_name != nullptr ? monitor_name : "";
  apply_visibility(state);
}

void native_window_state_set_primary(NativeWindowState *state,
                                     gboolean is_primary) {
  if (state == nullptr) {
    return;
  }
  state->monitor_is_primary = is_primary;
  apply_visibility(state);
}

NativeWindowState *native_window_state_from_window(GtkWindow *window) {
  if (window == nullptr) {
    return nullptr;
  }
  return static_cast<NativeWindowState *>(
      g_object_get_data(G_OBJECT(window), kNativeWindowStateKey));
}
