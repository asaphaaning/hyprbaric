#ifndef FLUTTER_WINDOW_BOOTSTRAP_H_
#define FLUTTER_WINDOW_BOOTSTRAP_H_

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>

GtkWindow *hyprbaric_create_window(GtkApplication *application,
                                   GdkMonitor *monitor,
                                   gboolean *layer_shell_available);

FlView *hyprbaric_create_view(GtkWindow *window, char **dart_entrypoint_args);

FlView *hyprbaric_create_view_for_engine(GtkWindow *window, FlEngine *engine);

#endif // FLUTTER_WINDOW_BOOTSTRAP_H_
