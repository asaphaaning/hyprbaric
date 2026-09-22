#include "hit_region.h"

#ifdef GDK_WINDOWING_WAYLAND
#include <gdk/gdkwayland.h>
#endif

namespace {
gboolean hit_region_rect_equals(const cairo_rectangle_int_t &lhs,
                                const cairo_rectangle_int_t &rhs) {
  return lhs.x == rhs.x && lhs.y == rhs.y && lhs.width == rhs.width &&
         lhs.height == rhs.height;
}

gboolean rounded_region_rect_equals(const RoundedRegionRect &lhs,
                                    const RoundedRegionRect &rhs) {
  return hit_region_rect_equals(lhs.rect, rhs.rect) &&
         lhs.radius_top_left == rhs.radius_top_left &&
         lhs.radius_top_right == rhs.radius_top_right &&
         lhs.radius_bottom_right == rhs.radius_bottom_right &&
         lhs.radius_bottom_left == rhs.radius_bottom_left;
}

gboolean hit_region_state_equals(const HitRegionState &lhs,
                                 const HitRegionState &rhs) {
  if (lhs.regions.size() != rhs.regions.size()) {
    return FALSE;
  }
  for (size_t i = 0; i < lhs.regions.size(); ++i) {
    if (!rounded_region_rect_equals(lhs.regions[i], rhs.regions[i])) {
      return FALSE;
    }
  }
  return lhs.bar_height == rhs.bar_height && lhs.has_menu == rhs.has_menu &&
         lhs.bar_edge == rhs.bar_edge &&
         lhs.capture_all_clicks == rhs.capture_all_clicks &&
         rounded_region_rect_equals(lhs.menu, rhs.menu);
}

void apply_regions(NativeWindowState *state, cairo_region_t *input_region) {
  GtkWidget *window_widget = GTK_WIDGET(state->window);
  GtkWidget *view_widget = state->view != nullptr ? state->view : window_widget;
  if (!gtk_widget_get_realized(view_widget)) {
    return;
  }

#if GTK_CHECK_VERSION(4, 0, 0)
  GdkSurface *view_surface = gtk_native_get_surface(GTK_NATIVE(view_widget));
  if (view_surface != nullptr) {
    gdk_surface_set_input_region(view_surface, input_region);
    gdk_surface_set_opaque_region(view_surface, nullptr);
    gdk_surface_queue_render(view_surface);
  }

  GdkSurface *window_surface =
      gtk_native_get_surface(GTK_NATIVE(window_widget));
  if (window_surface != nullptr) {
    gdk_surface_set_input_region(window_surface, input_region);
    gdk_surface_set_opaque_region(window_surface, nullptr);
    gdk_surface_queue_render(window_surface);
  }
#else
  GdkWindow *view_gdk_window = gtk_widget_get_window(view_widget);
  if (view_gdk_window == nullptr) {
    return;
  }

  GdkDisplay *display = gdk_window_get_display(view_gdk_window);

#ifdef GDK_WINDOWING_WAYLAND
  if (GDK_IS_WAYLAND_DISPLAY(display)) {
    struct wl_surface *surface =
        gdk_wayland_window_get_wl_surface(view_gdk_window);
    if (surface != nullptr) {
      struct wl_region *region = nullptr;
      struct wl_compositor *compositor =
          gdk_wayland_display_get_wl_compositor(display);
      if (input_region != nullptr && compositor != nullptr) {
        region = wl_compositor_create_region(compositor);
        if (region != nullptr) {
          const int rect_count = cairo_region_num_rectangles(input_region);
          for (int i = 0; i < rect_count; ++i) {
            cairo_rectangle_int_t rect = {0, 0, 0, 0};
            cairo_region_get_rectangle(input_region, i, &rect);
            wl_region_add(region, rect.x, rect.y, rect.width, rect.height);
          }
        }
      }
      wl_surface_set_input_region(surface, region);
      wl_surface_set_opaque_region(surface, nullptr);
      wl_surface_commit(surface);
      if (region != nullptr) {
        wl_region_destroy(region);
      }
    }
  } else
#endif
  {
    gdk_window_input_shape_combine_region(view_gdk_window, input_region, 0, 0);
    gdk_window_set_opaque_region(view_gdk_window, nullptr);
  }

  GdkWindow *window_gdk_window = gtk_widget_get_window(window_widget);
  if (window_gdk_window != nullptr) {
    gdk_window_input_shape_combine_region(window_gdk_window, input_region, 0,
                                          0);
    gdk_window_set_opaque_region(window_gdk_window, nullptr);
  }
#endif
}

RoundedRegionRect rounded_region_from_native(
    HyprbaricNativeLayerShellRegion *region) {
  return {
      .rect =
          {
              .x = static_cast<int>(
                  hyprbaric_native_layer_shell_region_get_x(region)),
              .y = static_cast<int>(
                  hyprbaric_native_layer_shell_region_get_y(region)),
              .width = static_cast<int>(
                  hyprbaric_native_layer_shell_region_get_width(region)),
              .height = static_cast<int>(
                  hyprbaric_native_layer_shell_region_get_height(region)),
          },
      .radius_top_left = static_cast<int>(
          hyprbaric_native_layer_shell_region_get_radius_top_left(region)),
      .radius_top_right = static_cast<int>(
          hyprbaric_native_layer_shell_region_get_radius_top_right(region)),
      .radius_bottom_right = static_cast<int>(
          hyprbaric_native_layer_shell_region_get_radius_bottom_right(region)),
      .radius_bottom_left = static_cast<int>(
          hyprbaric_native_layer_shell_region_get_radius_bottom_left(region)),
  };
}

gboolean flush_hit_region_idle(gpointer user_data) {
  GtkWindow *window = GTK_WINDOW(user_data);
  NativeWindowState *state = native_window_state_from_window(window);
  if (state != nullptr) {
    state->hit_region_apply_scheduled = FALSE;
    hyprbaric_hit_region_apply(state);
  }
  return G_SOURCE_REMOVE;
}
} // namespace

gboolean hyprbaric_hit_region_apply(NativeWindowState *state) {
  if (state == nullptr || state->window == nullptr) {
    return FALSE;
  }

  GtkWidget *window_widget = GTK_WIDGET(state->window);
  GtkWidget *view_widget = state->view != nullptr ? state->view : window_widget;
  if (!gtk_widget_get_realized(view_widget)) {
    return FALSE;
  }

  GdkWindow *view_gdk_window = gtk_widget_get_window(view_widget);
  if (view_gdk_window == nullptr) {
    return FALSE;
  }

  const int width = gtk_widget_get_allocated_width(view_widget);
  const int height = gtk_widget_get_allocated_height(view_widget);
  const HitRegionState &region_state = state->hit_region_state;

  if (width <= 1 || height <= 1 || region_state.bar_height <= 0) {
    return FALSE;
  }

  if (state->last_applied_region_width == width &&
      state->last_applied_region_height == height &&
      hit_region_state_equals(region_state,
                              state->last_applied_hit_region_state)) {
    return TRUE;
  }

  cairo_region_t *region = hyprbaric_hit_region_build(region_state, width, height);
  g_debug("hyprbaric::hit_region: applying %d rectangles to %dx%d logical window",
          cairo_region_num_rectangles(region), width, height);
  apply_regions(state, region);
  cairo_region_destroy(region);

  state->last_applied_hit_region_state = region_state;
  state->last_applied_region_width = width;
  state->last_applied_region_height = height;

  return TRUE;
}

void hyprbaric_hit_region_schedule_apply(NativeWindowState *state) {
  if (state == nullptr || state->window == nullptr ||
      state->hit_region_apply_scheduled) {
    return;
  }

  state->hit_region_apply_scheduled = TRUE;
  g_idle_add_full(G_PRIORITY_HIGH_IDLE, flush_hit_region_idle,
                  g_object_ref(state->window), g_object_unref);
}

gboolean hyprbaric_hit_region_update(
    NativeWindowState *state, HyprbaricNativeLayerShellRegionRequest *request) {
  if (state == nullptr || request == nullptr) {
    return FALSE;
  }

  HitRegionState next_state;
  next_state.bar_height = static_cast<int>(
      hyprbaric_native_layer_shell_region_request_get_bar_height(request));
  next_state.bar_edge =
      hyprbaric_native_layer_shell_region_request_get_bar_edge(request);
  next_state.capture_all_clicks =
      hyprbaric_native_layer_shell_region_request_get_capture_all_clicks(
          request);

  HyprbaricNativeLayerShellRegion *menu =
      hyprbaric_native_layer_shell_region_request_get_menu(request);
  if (menu != nullptr) {
    next_state.menu = rounded_region_from_native(menu);
    next_state.has_menu = TRUE;
  }

  FlValue *regions_list =
      hyprbaric_native_layer_shell_region_request_get_passive_regions(request);
  if (regions_list != nullptr &&
      fl_value_get_type(regions_list) == FL_VALUE_TYPE_LIST) {
    const size_t region_count = fl_value_get_length(regions_list);
    next_state.regions.reserve(region_count);
    for (size_t index = 0; index < region_count; ++index) {
      FlValue *region_value = fl_value_get_list_value(regions_list, index);
      if (region_value == nullptr ||
          fl_value_get_type(region_value) != FL_VALUE_TYPE_CUSTOM) {
        continue;
      }
      next_state.regions.push_back(
          rounded_region_from_native(HYPRBARIC_NATIVE_LAYER_SHELL_REGION(
              fl_value_get_custom_value_object(region_value))));
    }
  }

  if (hit_region_state_equals(state->hit_region_state, next_state)) {
    return FALSE;
  }

  state->hit_region_state = next_state;
  hyprbaric_hit_region_schedule_apply(state);
  return TRUE;
}

void hyprbaric_hit_region_size_allocate(GtkWidget *widget,
                                        GdkRectangle *allocation,
                                        gpointer user_data) {
  (void)widget;
  (void)allocation;
  NativeWindowState *state = static_cast<NativeWindowState *>(user_data);
  hyprbaric_hit_region_apply(state);
}
