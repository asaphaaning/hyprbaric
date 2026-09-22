#include "hit_region.h"

#include <algorithm>
#include <cstdint>

namespace {
// Empty overlays do not paint, regardless of their corner radii.
bool is_rectangular(const RoundedRegionRect &region) {
  return region.rect.width <= 0 || region.rect.height <= 0 ||
         (region.radius_top_left == 0 && region.radius_top_right == 0 &&
          region.radius_bottom_right == 0 && region.radius_bottom_left == 0);
}

void union_rectangle(cairo_region_t *region,
                     const cairo_rectangle_int_t &rectangle, int width,
                     int height) {
  if (rectangle.width <= 0 || rectangle.height <= 0) {
    return;
  }

  // Clip before union, using wider sums so offscreen extents cannot overflow.
  const int left = std::max(0, rectangle.x);
  const int top = std::max(0, rectangle.y);
  const int right = static_cast<int>(std::min<int64_t>(
      width, static_cast<int64_t>(rectangle.x) + rectangle.width));
  const int bottom = static_cast<int>(std::min<int64_t>(
      height, static_cast<int64_t>(rectangle.y) + rectangle.height));
  if (right <= left || bottom <= top) {
    return;
  }

  const cairo_rectangle_int_t clipped = {left, top, right - left, bottom - top};
  cairo_region_union_rectangle(region, &clipped);
}

void fill_rounded_region(cairo_t *cr, const RoundedRegionRect &region) {
  if (region.rect.width <= 0 || region.rect.height <= 0) {
    return;
  }

  const double x = static_cast<double>(region.rect.x);
  const double y = static_cast<double>(region.rect.y);
  const double region_width = static_cast<double>(region.rect.width);
  const double region_height = static_cast<double>(region.rect.height);
  const double tl = region.radius_top_left;
  const double tr = region.radius_top_right;
  const double br = region.radius_bottom_right;
  const double bl = region.radius_bottom_left;

  cairo_new_path(cr);
  cairo_move_to(cr, x + tl, y);
  cairo_line_to(cr, x + region_width - tr, y);
  if (tr > 0) {
    cairo_arc(cr, x + region_width - tr, y + tr, tr, -G_PI_2, 0.0);
  }
  cairo_line_to(cr, x + region_width, y + region_height - br);
  if (br > 0) {
    cairo_arc(cr, x + region_width - br, y + region_height - br, br, 0.0,
              G_PI_2);
  }
  cairo_line_to(cr, x + bl, y + region_height);
  if (bl > 0) {
    cairo_arc(cr, x + bl, y + region_height - bl, bl, G_PI_2, G_PI);
  }
  cairo_line_to(cr, x, y + tl);
  if (tl > 0) {
    cairo_arc(cr, x + tl, y + tl, tl, G_PI, 3.0 * G_PI_2);
  }
  cairo_close_path(cr);
  cairo_fill(cr);
}

cairo_region_t *rasterize(const HitRegionState &state, int width, int height,
                          const cairo_rectangle_int_t &bar) {
  cairo_surface_t *surface =
      cairo_image_surface_create(CAIRO_FORMAT_A8, width, height);
  cairo_t *context = cairo_create(surface);
  cairo_set_operator(context, CAIRO_OPERATOR_CLEAR);
  cairo_paint(context);
  cairo_set_operator(context, CAIRO_OPERATOR_SOURCE);
  cairo_set_antialias(context, CAIRO_ANTIALIAS_NONE);

  cairo_rectangle(context, bar.x, bar.y, bar.width, bar.height);
  cairo_fill(context);
  if (state.has_menu) {
    fill_rounded_region(context, state.menu);
  }
  for (const RoundedRegionRect &overlay : state.regions) {
    fill_rounded_region(context, overlay);
  }

  cairo_region_t *region = gdk_cairo_region_create_from_surface(surface);
  cairo_destroy(context);
  cairo_surface_destroy(surface);
  return region;
}
} // namespace

cairo_region_t *hyprbaric_hit_region_build(const HitRegionState &state,
                                           int width, int height) {
  const cairo_rectangle_int_t bounds = {0, 0, width, height};
  if (state.capture_all_clicks) {
    return cairo_region_create_rectangle(&bounds);
  }

  const int bar_height = std::max(0, std::min(state.bar_height, height));
  const int bar_y =
      state.bar_edge == HYPRBARIC_NATIVE_LAYER_SHELL_BAR_EDGE_BOTTOM
          ? height - bar_height
          : 0;
  const cairo_rectangle_int_t bar = {0, bar_y, width, bar_height};
  if ((state.has_menu && !is_rectangular(state.menu)) ||
      !std::all_of(state.regions.begin(), state.regions.end(),
                   is_rectangular)) {
    return rasterize(state, width, height, bar);
  }

  cairo_region_t *region = cairo_region_create_rectangle(&bar);
  if (state.has_menu) {
    union_rectangle(region, state.menu.rect, width, height);
  }
  for (const RoundedRegionRect &overlay : state.regions) {
    union_rectangle(region, overlay.rect, width, height);
  }
  return region;
}
