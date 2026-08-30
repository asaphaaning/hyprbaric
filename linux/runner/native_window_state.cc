#include "native_window_state.h"

#include "monitor.h"

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
  }
  return state->monitor_is_primary;
}

void apply_visibility(NativeWindowState *state) {
  if (state == nullptr || state->window == nullptr ||
      !state->first_frame_rendered) {
    return;
  }
  if (should_show(state)) {
    gtk_widget_show(GTK_WIDGET(state->window));
  } else {
    gtk_widget_hide(GTK_WIDGET(state->window));
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
  state->monitor = monitor != nullptr
                       ? GDK_MONITOR(g_object_ref(monitor))
                       : nullptr;
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
