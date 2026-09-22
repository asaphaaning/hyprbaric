#ifndef FLUTTER_HIT_REGION_H_
#define FLUTTER_HIT_REGION_H_

#include <gtk/gtk.h>

#include "layer_shell_api.g.h"
#include "native_window_state.h"

// Builds an input region in window-local logical coordinates. The caller owns
// the returned region. Rectangular geometry needs no image surface; rounded
// geometry retains the raster mask. Width and height must be positive.
cairo_region_t *hyprbaric_hit_region_build(const HitRegionState &state,
                                           int width, int height);

gboolean hyprbaric_hit_region_apply(NativeWindowState *state);

void hyprbaric_hit_region_schedule_apply(NativeWindowState *state);

gboolean hyprbaric_hit_region_update(
    NativeWindowState *state, HyprbaricNativeLayerShellRegionRequest *request);

void hyprbaric_hit_region_size_allocate(GtkWidget *widget,
                                        GdkRectangle *allocation,
                                        gpointer user_data);

#endif // FLUTTER_HIT_REGION_H_
