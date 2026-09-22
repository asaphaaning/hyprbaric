#include "hit_region.h"

#include <algorithm>
#include <array>
#include <cstdlib>
#include <iostream>
#include <limits>
#include <random>

namespace {
// Frozen pre-optimization rasterizer: an independent reference for input
// pixels.
void paint_reference_overlay(cairo_t *cr, const RoundedRegionRect &region) {
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

cairo_region_t *reference_region(const HitRegionState &state, int width,
                                 int height) {
  cairo_surface_t *surface =
      cairo_image_surface_create(CAIRO_FORMAT_A8, width, height);
  cairo_t *context = cairo_create(surface);
  cairo_set_operator(context, CAIRO_OPERATOR_CLEAR);
  cairo_paint(context);
  cairo_set_operator(context, CAIRO_OPERATOR_SOURCE);
  cairo_set_antialias(context, CAIRO_ANTIALIAS_NONE);

  const int bar_height = std::max(0, std::min(state.bar_height, height));
  const int painted_height = state.capture_all_clicks ? height : bar_height;
  const int origin =
      state.bar_edge == HYPRBARIC_NATIVE_LAYER_SHELL_BAR_EDGE_BOTTOM
          ? height - painted_height
          : 0;
  cairo_rectangle(context, 0, origin, width, painted_height);
  cairo_fill(context);
  if (state.has_menu) {
    paint_reference_overlay(context, state.menu);
  }
  for (const RoundedRegionRect &overlay : state.regions) {
    paint_reference_overlay(context, overlay);
  }

  cairo_region_t *region = gdk_cairo_region_create_from_surface(surface);
  cairo_destroy(context);
  cairo_surface_destroy(surface);
  return region;
}

RoundedRegionRect overlay(int left, int top, int width, int height,
                          std::array<int, 4> radii = {}) {
  RoundedRegionRect region;
  region.rect = {left, top, width, height};
  region.radius_top_left = radii[0];
  region.radius_top_right = radii[1];
  region.radius_bottom_right = radii[2];
  region.radius_bottom_left = radii[3];
  return region;
}

void check(const char *name, const HitRegionState &state, int width = 256,
           int height = 180) {
  cairo_region_t *expected = reference_region(state, width, height);
  cairo_region_t *actual = hyprbaric_hit_region_build(state, width, height);
  if (cairo_region_status(expected) != CAIRO_STATUS_SUCCESS ||
      cairo_region_status(actual) != CAIRO_STATUS_SUCCESS ||
      !cairo_region_equal(expected, actual)) {
    std::cerr << "Region mismatch: " << name << " (" << width << 'x' << height
              << ")\n";
    std::exit(EXIT_FAILURE);
  }
  cairo_region_destroy(expected);
  cairo_region_destroy(actual);
}

void check_rectangles() {
  HitRegionState state;
  state.bar_height = 40;
  for (const auto edge : {HYPRBARIC_NATIVE_LAYER_SHELL_BAR_EDGE_TOP,
                          HYPRBARIC_NATIVE_LAYER_SHELL_BAR_EDGE_BOTTOM}) {
    state.bar_edge = edge;
    check("Bar only", state, 3200, 1800);
    check("Bar clamped to window height", state, 256, 20);
    check("Single pixel window", state, 1, 1);
    state.capture_all_clicks = TRUE;
    check("Full capture", state);
    state.capture_all_clicks = FALSE;
  }

  state.has_menu = TRUE;
  state.menu = overlay(-20, 24, 120, 90);
  state.regions = {overlay(60, 60, 140, 70),    overlay(60, 60, 140, 70),
                   overlay(230, 160, 100, 100), overlay(30, -15, 30, 60),
                   overlay(-150, 90, 100, 20),  overlay(30, 250, 100, 20)};
  check("Clipped and overlapping menu/passive rectangles", state);

  state.regions.push_back(overlay(0, 0, 256, 180));
  check("Settings covers the window without capture flag", state);
  state.regions.clear();
  state.menu = overlay(15, 60, -30, 20, {8, 8, 8, 8});
  state.regions = {overlay(15, 60, 30, 0, {8, 8, 8, 8})};
  check("Empty overlays with nonzero radii paint nothing", state);

  state.has_menu = FALSE;
  state.menu = overlay(20, 60, 100, 80, {12, 12, 12, 12});
  state.regions.clear();
  check("Inactive menu geometry is ignored", state);
  state.bar_height = 0;
  check("Empty bar", state);
}

void check_rounded_fallback() {
  HitRegionState state;
  state.bar_height = 40;
  state.has_menu = TRUE;
  state.menu = overlay(20, 55, 100, 80, {12, 8, 4, 0});
  state.regions = {overlay(-12, 110, 90, 90, {16, 16, 16, 16}),
                   overlay(110, 90, 100, 40)};
  check("Mixed rounded and rectangular overlays", state);
  state.has_menu = FALSE;
  check("Rounded passive overlay without menu", state);
  state.has_menu = TRUE;
  state.menu = overlay(20, 50, 35, 20, {40, -8, 70, 4});
  check("Unnormalized radii retain raster behavior", state);

  state.capture_all_clicks = TRUE;
  check("Capture includes rounded and unnormalized overlays", state);
  state.regions.clear();
  state.menu = overlay(0, 0, 256, 180, {18, 18, 18, 18});
  check("Capture fills rounded corner cutouts", state);
}

void check_large_rectangles() {
  HitRegionState state;
  state.bar_height = 40;
  state.regions = {overlay(std::numeric_limits<int>::max() - 8, 50, 20, 20),
                   overlay(50, std::numeric_limits<int>::max() - 8, 20, 20)};
  cairo_region_t *actual = hyprbaric_hit_region_build(state, 256, 180);
  const cairo_rectangle_int_t bar = {0, 0, 256, 40};
  cairo_region_t *expected = cairo_region_create_rectangle(&bar);
  if (cairo_region_status(actual) != CAIRO_STATUS_SUCCESS ||
      !cairo_region_equal(expected, actual)) {
    std::cerr << "Offscreen rectangle extents must not overflow\n";
    std::exit(EXIT_FAILURE);
  }
  cairo_region_destroy(expected);
  cairo_region_destroy(actual);
}

void check_generated_geometry() {
  std::mt19937 random(20260922);
  for (int iteration = 0; iteration < 1000; ++iteration) {
    HitRegionState state;
    state.bar_height = static_cast<int>(random() % 220);
    state.bar_edge = iteration % 2 == 0
                         ? HYPRBARIC_NATIVE_LAYER_SHELL_BAR_EDGE_TOP
                         : HYPRBARIC_NATIVE_LAYER_SHELL_BAR_EDGE_BOTTOM;
    state.capture_all_clicks = iteration % 5 == 0;
    state.has_menu = iteration % 3 != 0;
    for (int index = 0; index < 1 + iteration % 7; ++index) {
      const int width = static_cast<int>(random() % 200) - 5;
      const int height = static_cast<int>(random() % 150) - 5;
      std::array<int, 4> radii = {};
      if (iteration % 4 == 0) {
        for (int &radius : radii) {
          radius = static_cast<int>(random() % 40) - 5;
        }
      }
      const auto region =
          overlay(static_cast<int>(random() % 400) - 100,
                  static_cast<int>(random() % 300) - 100, width, height, radii);
      if (index == 0) {
        state.menu = region;
      } else {
        state.regions.push_back(region);
      }
    }
    check("Generated geometry", state);
  }
}
} // namespace

int main() {
  check_rectangles();
  check_rounded_fallback();
  check_large_rectangles();
  check_generated_geometry();
  std::cout << "Hit region geometry comparisons passed\n";
  return EXIT_SUCCESS;
}
