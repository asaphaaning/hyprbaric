#include "layer_shell_host.h"

#include <gtk-layer-shell/gtk-layer-shell.h>

#include "hit_region.h"
#include "layer_shell_api.g.h"
#include "monitor.h"

namespace {
GtkLayerShellLayer native_layer_to_gtk(HyprbaricNativeLayerShellLayer layer) {
  switch (layer) {
  case HYPRBARIC_NATIVE_LAYER_SHELL_LAYER_BACKGROUND:
    return GTK_LAYER_SHELL_LAYER_BACKGROUND;
  case HYPRBARIC_NATIVE_LAYER_SHELL_LAYER_BOTTOM:
    return GTK_LAYER_SHELL_LAYER_BOTTOM;
  case HYPRBARIC_NATIVE_LAYER_SHELL_LAYER_TOP:
    return GTK_LAYER_SHELL_LAYER_TOP;
  case HYPRBARIC_NATIVE_LAYER_SHELL_LAYER_OVERLAY:
    return GTK_LAYER_SHELL_LAYER_OVERLAY;
  }
  return GTK_LAYER_SHELL_LAYER_TOP;
}

GtkLayerShellKeyboardMode
native_keyboard_mode_to_gtk(HyprbaricNativeLayerShellKeyboardMode mode) {
  switch (mode) {
  case HYPRBARIC_NATIVE_LAYER_SHELL_KEYBOARD_MODE_NONE:
    return GTK_LAYER_SHELL_KEYBOARD_MODE_NONE;
  case HYPRBARIC_NATIVE_LAYER_SHELL_KEYBOARD_MODE_EXCLUSIVE:
    return GTK_LAYER_SHELL_KEYBOARD_MODE_EXCLUSIVE;
  case HYPRBARIC_NATIVE_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND:
    return GTK_LAYER_SHELL_KEYBOARD_MODE_ON_DEMAND;
  }
  return GTK_LAYER_SHELL_KEYBOARD_MODE_NONE;
}

gboolean layer_shell_ready(NativeWindowState *state) {
  return state != nullptr && state->layer_shell_available &&
         state->window != nullptr;
}

void maybe_set_anchor(GtkWindow *window, GtkLayerShellEdge edge,
                      gboolean *value) {
  if (value != nullptr) {
    gtk_layer_set_anchor(window, edge, *value);
  }
}

void maybe_set_margin(GtkWindow *window, GtkLayerShellEdge edge,
                      int64_t *value) {
  if (value != nullptr) {
    gtk_layer_set_margin(window, edge, static_cast<int>(*value));
  }
}

void apply_anchors(GtkWindow *window,
                   HyprbaricNativeLayerShellAnchors *anchors) {
  if (anchors == nullptr) {
    return;
  }
  maybe_set_anchor(window, GTK_LAYER_SHELL_EDGE_TOP,
                   hyprbaric_native_layer_shell_anchors_get_top(anchors));
  maybe_set_anchor(window, GTK_LAYER_SHELL_EDGE_BOTTOM,
                   hyprbaric_native_layer_shell_anchors_get_bottom(anchors));
  maybe_set_anchor(window, GTK_LAYER_SHELL_EDGE_LEFT,
                   hyprbaric_native_layer_shell_anchors_get_left(anchors));
  maybe_set_anchor(window, GTK_LAYER_SHELL_EDGE_RIGHT,
                   hyprbaric_native_layer_shell_anchors_get_right(anchors));
}

void apply_margins(GtkWindow *window,
                   HyprbaricNativeLayerShellMargins *margins) {
  if (margins == nullptr) {
    return;
  }
  maybe_set_margin(window, GTK_LAYER_SHELL_EDGE_TOP,
                   hyprbaric_native_layer_shell_margins_get_top(margins));
  maybe_set_margin(window, GTK_LAYER_SHELL_EDGE_BOTTOM,
                   hyprbaric_native_layer_shell_margins_get_bottom(margins));
  maybe_set_margin(window, GTK_LAYER_SHELL_EDGE_LEFT,
                   hyprbaric_native_layer_shell_margins_get_left(margins));
  maybe_set_margin(window, GTK_LAYER_SHELL_EDGE_RIGHT,
                   hyprbaric_native_layer_shell_margins_get_right(margins));
}

void apply_size(GtkWindow *window, HyprbaricNativeLayerShellSize *size) {
  if (size == nullptr) {
    return;
  }
  int64_t *width_value = hyprbaric_native_layer_shell_size_get_width(size);
  int64_t *height_value = hyprbaric_native_layer_shell_size_get_height(size);
  if (width_value == nullptr && height_value == nullptr) {
    return;
  }
  const int width =
      width_value != nullptr ? static_cast<int>(*width_value) : -1;
  const int height =
      height_value != nullptr ? static_cast<int>(*height_value) : -1;
  gtk_widget_set_size_request(GTK_WIDGET(window), width, height);
}

void apply_keyboard_mode(NativeWindowState *state,
                         HyprbaricNativeLayerShellKeyboardMode mode) {
  GtkLayerShellKeyboardMode keyboard_mode = native_keyboard_mode_to_gtk(mode);
  gtk_layer_set_keyboard_mode(state->window, keyboard_mode);
  if (keyboard_mode != GTK_LAYER_SHELL_KEYBOARD_MODE_NONE &&
      state->view != nullptr) {
    gtk_widget_grab_focus(state->view);
    gtk_window_present(state->window);
  }
}

void apply_auto_exclusive_zone(GtkWindow *window, gboolean enabled) {
  if (enabled) {
    gtk_layer_auto_exclusive_zone_enable(window);
  } else {
    gtk_layer_set_exclusive_zone(window, gtk_layer_get_exclusive_zone(window));
  }
}

NativeWindowState *state_from_user_data(gpointer user_data) {
  return static_cast<NativeWindowState *>(user_data);
}

void release_borrowed_state(gpointer user_data) { (void)user_data; }

#define LAYER_SHELL_UNAVAILABLE_RESPONSE(method)                               \
  hyprbaric_native_layer_shell_host_api_##method##_response_new_error(         \
      "layer-shell-unavailable",                                               \
      "Wayland layer shell is not available on this system.", nullptr)

static HyprbaricNativeLayerShellHostApiListMonitorsResponse *
native_list_monitors(gpointer user_data) {
  (void)user_data;
  g_autoptr(FlValue) values = fl_value_new_list();
  for (const MonitorDescriptor &monitor : hyprbaric_monitors()) {
    HyprbaricNativeLayerShellMonitor *value =
        hyprbaric_native_layer_shell_monitor_new(
            monitor.name.c_str(), monitor.label.c_str(), monitor.is_primary);
    fl_value_append_take(
        values,
        fl_value_new_custom(hyprbaric_native_layer_shell_monitor_type_id, value,
                            g_object_unref));
  }
  return hyprbaric_native_layer_shell_host_api_list_monitors_response_new(
      values);
}

static HyprbaricNativeLayerShellHostApiConfigurePanelResponse *
native_configure_panel(HyprbaricNativeLayerShellPanelConfig *config,
                       gpointer user_data) {
  NativeWindowState *state = state_from_user_data(user_data);
  if (!layer_shell_ready(state)) {
    return LAYER_SHELL_UNAVAILABLE_RESPONSE(configure_panel);
  }

  gtk_layer_set_namespace(
      state->window,
      hyprbaric_native_layer_shell_panel_config_get_app_namespace(config));
  gtk_layer_set_layer(
      state->window,
      native_layer_to_gtk(
          hyprbaric_native_layer_shell_panel_config_get_layer(config)));
  apply_anchors(state->window,
                hyprbaric_native_layer_shell_panel_config_get_anchors(config));
  apply_keyboard_mode(
      state,
      hyprbaric_native_layer_shell_panel_config_get_keyboard_mode(config));
  apply_margins(state->window,
                hyprbaric_native_layer_shell_panel_config_get_margins(config));
  apply_size(state->window,
             hyprbaric_native_layer_shell_panel_config_get_size(config));
  gtk_layer_set_exclusive_zone(
      state->window,
      static_cast<int>(
          hyprbaric_native_layer_shell_panel_config_get_exclusive_zone(
              config)));
  apply_auto_exclusive_zone(
      state->window,
      hyprbaric_native_layer_shell_panel_config_get_auto_exclusive_zone(
          config));
  HyprbaricNativeLayerShellMonitorTarget *monitor =
      hyprbaric_native_layer_shell_panel_config_get_monitor(config);
  native_window_state_set_monitor_target(
      state, hyprbaric_native_layer_shell_monitor_target_get_kind(monitor),
      hyprbaric_native_layer_shell_monitor_target_get_name(monitor));

  return hyprbaric_native_layer_shell_host_api_configure_panel_response_new();
}

static HyprbaricNativeLayerShellHostApiSetLayerResponse *
native_set_layer(HyprbaricNativeLayerShellLayer layer, gpointer user_data) {
  NativeWindowState *state = state_from_user_data(user_data);
  if (!layer_shell_ready(state)) {
    return LAYER_SHELL_UNAVAILABLE_RESPONSE(set_layer);
  }
  gtk_layer_set_layer(state->window, native_layer_to_gtk(layer));
  return hyprbaric_native_layer_shell_host_api_set_layer_response_new();
}

static HyprbaricNativeLayerShellHostApiSetNamespaceResponse *
native_set_namespace(const gchar *namespace_name, gpointer user_data) {
  NativeWindowState *state = state_from_user_data(user_data);
  if (!layer_shell_ready(state)) {
    return LAYER_SHELL_UNAVAILABLE_RESPONSE(set_namespace);
  }
  gtk_layer_set_namespace(state->window, namespace_name);
  return hyprbaric_native_layer_shell_host_api_set_namespace_response_new();
}

static HyprbaricNativeLayerShellHostApiSetAnchorsResponse *
native_set_anchors(HyprbaricNativeLayerShellAnchors *anchors,
                   gpointer user_data) {
  NativeWindowState *state = state_from_user_data(user_data);
  if (!layer_shell_ready(state)) {
    return LAYER_SHELL_UNAVAILABLE_RESPONSE(set_anchors);
  }
  apply_anchors(state->window, anchors);
  return hyprbaric_native_layer_shell_host_api_set_anchors_response_new();
}

static HyprbaricNativeLayerShellHostApiSetMarginsResponse *
native_set_margins(HyprbaricNativeLayerShellMargins *margins,
                   gpointer user_data) {
  NativeWindowState *state = state_from_user_data(user_data);
  if (!layer_shell_ready(state)) {
    return LAYER_SHELL_UNAVAILABLE_RESPONSE(set_margins);
  }
  apply_margins(state->window, margins);
  return hyprbaric_native_layer_shell_host_api_set_margins_response_new();
}

static HyprbaricNativeLayerShellHostApiSetExclusiveZoneResponse *
native_set_exclusive_zone(int64_t zone, gpointer user_data) {
  NativeWindowState *state = state_from_user_data(user_data);
  if (!layer_shell_ready(state)) {
    return LAYER_SHELL_UNAVAILABLE_RESPONSE(set_exclusive_zone);
  }
  gtk_layer_set_exclusive_zone(state->window, static_cast<int>(zone));
  return hyprbaric_native_layer_shell_host_api_set_exclusive_zone_response_new();
}

static HyprbaricNativeLayerShellHostApiSetAutoExclusiveZoneResponse *
native_set_auto_exclusive_zone(gboolean enabled, gpointer user_data) {
  NativeWindowState *state = state_from_user_data(user_data);
  if (!layer_shell_ready(state)) {
    return LAYER_SHELL_UNAVAILABLE_RESPONSE(set_auto_exclusive_zone);
  }
  apply_auto_exclusive_zone(state->window, enabled);
  return hyprbaric_native_layer_shell_host_api_set_auto_exclusive_zone_response_new();
}

static HyprbaricNativeLayerShellHostApiSetKeyboardModeResponse *
native_set_keyboard_mode(HyprbaricNativeLayerShellKeyboardMode mode,
                         gpointer user_data) {
  NativeWindowState *state = state_from_user_data(user_data);
  if (!layer_shell_ready(state)) {
    return LAYER_SHELL_UNAVAILABLE_RESPONSE(set_keyboard_mode);
  }
  apply_keyboard_mode(state, mode);
  return hyprbaric_native_layer_shell_host_api_set_keyboard_mode_response_new();
}

static HyprbaricNativeLayerShellHostApiSetSizeResponse *
native_set_size(HyprbaricNativeLayerShellSize *size, gpointer user_data) {
  NativeWindowState *state = state_from_user_data(user_data);
  if (!layer_shell_ready(state)) {
    return LAYER_SHELL_UNAVAILABLE_RESPONSE(set_size);
  }
  apply_size(state->window, size);
  return hyprbaric_native_layer_shell_host_api_set_size_response_new();
}

static HyprbaricNativeLayerShellHostApiSetRegionResponse *
native_set_region(HyprbaricNativeLayerShellRegionRequest *request,
                  gpointer user_data) {
  NativeWindowState *state = state_from_user_data(user_data);
  if (!layer_shell_ready(state)) {
    return LAYER_SHELL_UNAVAILABLE_RESPONSE(set_region);
  }
  hyprbaric_hit_region_update(state, request);
  return hyprbaric_native_layer_shell_host_api_set_region_response_new();
}

static const HyprbaricNativeLayerShellHostApiVTable kLayerShellVTable = {
    .list_monitors = native_list_monitors,
    .configure_panel = native_configure_panel,
    .set_layer = native_set_layer,
    .set_namespace = native_set_namespace,
    .set_anchors = native_set_anchors,
    .set_margins = native_set_margins,
    .set_exclusive_zone = native_set_exclusive_zone,
    .set_auto_exclusive_zone = native_set_auto_exclusive_zone,
    .set_keyboard_mode = native_set_keyboard_mode,
    .set_size = native_set_size,
    .set_region = native_set_region,
};
} // namespace

void hyprbaric_layer_shell_host_register(FlBinaryMessenger *messenger,
                                         NativeWindowState *state,
                                         const char *suffix) {
  hyprbaric_native_layer_shell_host_api_set_method_handlers(
      messenger, suffix, &kLayerShellVTable, state, release_borrowed_state);
}
