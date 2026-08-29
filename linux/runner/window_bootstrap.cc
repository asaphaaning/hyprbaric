#include "window_bootstrap.h"

#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif
#include <gtk-layer-shell/gtk-layer-shell.h>

namespace {
constexpr int kInitialBarHeight = 40;
constexpr int kInitialBarTopMargin = 3;
constexpr char kTitle[] = "Hyprbaric";

void configure_titlebar(GtkWindow *window) {
  gboolean use_header_bar = FALSE;
#ifdef GDK_WINDOWING_X11
  GdkScreen *x11_screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(x11_screen)) {
    const gchar *wm_name = gdk_x11_screen_get_window_manager_name(x11_screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar *header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, kTitle);
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, kTitle);
  }
}

void configure_transparency(GtkWidget *window_widget) {
#if GTK_CHECK_VERSION(3, 0, 0)
  GdkScreen *screen = gtk_widget_get_screen(window_widget);
  if (screen != nullptr) {
    GdkVisual *rgba_visual = gdk_screen_get_rgba_visual(screen);
    if (rgba_visual != nullptr) {
      gtk_widget_set_visual(window_widget, rgba_visual);
    }
  }
  gtk_widget_set_app_paintable(window_widget, TRUE);
#endif
}

void configure_initial_layer_shell(GtkWindow *window, GtkWidget *window_widget,
                                   GdkMonitor *monitor) {
  gtk_layer_init_for_window(window);
  gtk_layer_set_namespace(window, "hyprbaric");
  gtk_layer_set_layer(window, GTK_LAYER_SHELL_LAYER_TOP);
  gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_TOP, TRUE);
  gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_LEFT, TRUE);
  gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_RIGHT, TRUE);
  gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_BOTTOM, FALSE);
  gtk_layer_set_margin(window, GTK_LAYER_SHELL_EDGE_TOP, kInitialBarTopMargin);
  gtk_layer_set_margin(window, GTK_LAYER_SHELL_EDGE_LEFT, 0);
  gtk_layer_set_margin(window, GTK_LAYER_SHELL_EDGE_RIGHT, 0);
  gtk_layer_set_exclusive_zone(window,
                               kInitialBarHeight + kInitialBarTopMargin);
  gtk_layer_set_keyboard_mode(window, GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);

  if (monitor != nullptr) {
    gtk_layer_set_monitor(window, monitor);
  }

  if (monitor != nullptr) {
    GdkRectangle geometry;
    gdk_monitor_get_geometry(monitor, &geometry);
    gtk_widget_set_size_request(window_widget, -1, geometry.height);
  }
}
} // namespace

GtkWindow *hyprbaric_create_window(GtkApplication *application,
                                   GdkMonitor *monitor,
                                   gboolean *layer_shell_available) {
  GtkWindow *window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  GtkWidget *window_widget = GTK_WIDGET(window);

  configure_titlebar(window);
  gtk_window_set_default_size(window, 1280, 720);
  configure_transparency(window_widget);

  const gboolean supported = gtk_layer_is_supported();
  if (layer_shell_available != nullptr) {
    *layer_shell_available = supported;
  }
  if (supported) {
    configure_initial_layer_shell(window, window_widget, monitor);
  }

  gtk_widget_realize(GTK_WIDGET(window));
  return window;
}

FlView *hyprbaric_create_view(GtkWindow *window, char **dart_entrypoint_args) {
  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(project, dart_entrypoint_args);

  FlView *view = fl_view_new(project);
  GdkRGBA transparent = {0.0, 0.0, 0.0, 0.0};
  fl_view_set_background_color(view, &transparent);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
  gtk_widget_grab_focus(GTK_WIDGET(view));
  return view;
}

FlView *hyprbaric_create_view_for_engine(GtkWindow *window, FlEngine *engine) {
  FlView *view = fl_view_new_for_engine(engine);
  GdkRGBA transparent = {0.0, 0.0, 0.0, 0.0};
  fl_view_set_background_color(view, &transparent);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));
  return view;
}
