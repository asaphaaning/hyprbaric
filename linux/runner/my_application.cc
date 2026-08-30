#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include <algorithm>

#include "flutter/generated_plugin_registrant.h"
#include "hit_region.h"
#include "layer_shell_host.h"
#include "monitor.h"
#include "native_window_state.h"
#include "window_bootstrap.h"

namespace {
struct WindowRecord {
  GdkMonitor *monitor = nullptr;
  GtkWindow *window = nullptr;
  gchar *channel_suffix = nullptr;
};

void window_record_free(gpointer data) {
  auto *record = static_cast<WindowRecord *>(data);
  if (record->window != nullptr) {
    gtk_widget_destroy(GTK_WIDGET(record->window));
    g_object_unref(record->window);
  }
  g_clear_object(&record->monitor);
  g_clear_pointer(&record->channel_suffix, g_free);
  delete record;
}
} // namespace

struct _MyApplication {
  GtkApplication parent_instance;
  char **dart_entrypoint_arguments;
  GPtrArray *windows;
  FlEngine *engine;
  gulong monitor_added_handler;
  gulong monitor_removed_handler;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

namespace {
void first_frame_cb(FlView *view, gpointer user_data) {
  (void)view;
  native_window_state_first_frame(static_cast<NativeWindowState *>(user_data));
}

WindowRecord *find_window(MyApplication *self, GdkMonitor *monitor) {
  for (guint index = 0; index < self->windows->len; ++index) {
    auto *record =
        static_cast<WindowRecord *>(g_ptr_array_index(self->windows, index));
    if (record->monitor == monitor) {
      return record;
    }
  }
  return nullptr;
}

void clear_window_channel(MyApplication *self, WindowRecord *record) {
  if (self->engine == nullptr || record->channel_suffix == nullptr) {
    return;
  }
  FlBinaryMessenger *messenger = fl_engine_get_binary_messenger(self->engine);
  hyprbaric_native_layer_shell_host_api_clear_method_handlers(
      messenger, record->channel_suffix);
}

void refresh_monitor_descriptors(MyApplication *self) {
  for (const MonitorDescriptor &descriptor : hyprbaric_monitors()) {
    WindowRecord *record = find_window(self, descriptor.monitor);
    if (record == nullptr) {
      continue;
    }
    NativeWindowState *state = native_window_state_from_window(record->window);
    state->monitor_name = descriptor.name;
    native_window_state_set_primary(state, descriptor.is_primary);
  }
}

void create_window_for_monitor(MyApplication *self, GdkMonitor *monitor) {
  if (find_window(self, monitor) != nullptr) {
    return;
  }

  const MonitorDescriptor descriptor = hyprbaric_monitor_descriptor(monitor);
  gboolean layer_shell_available = FALSE;
  GtkWindow *window = hyprbaric_create_window(GTK_APPLICATION(self), monitor,
                                              &layer_shell_available);
  g_object_ref(window);

  const gboolean is_first_view = self->engine == nullptr;
  FlView *view =
      is_first_view
          ? hyprbaric_create_view(window, self->dart_entrypoint_arguments)
          : hyprbaric_create_view_for_engine(window, self->engine);
  if (is_first_view) {
    self->engine = FL_ENGINE(g_object_ref(fl_view_get_engine(view)));
    fl_register_plugins(FL_PLUGIN_REGISTRY(view));
  }

  NativeWindowState *state = native_window_state_attach(
      window, GTK_WIDGET(view), monitor, layer_shell_available,
      descriptor.name.c_str(), descriptor.is_primary);
  g_signal_connect(view, "first-frame", G_CALLBACK(first_frame_cb), state);

  gchar *suffix = g_strdup_printf("%" G_GINT64_FORMAT, fl_view_get_id(view));
  FlBinaryMessenger *messenger = fl_engine_get_binary_messenger(self->engine);
  hyprbaric_layer_shell_host_register(messenger, state, suffix);

  if (layer_shell_available) {
    g_signal_connect(window, "size-allocate",
                     G_CALLBACK(hyprbaric_hit_region_size_allocate), state);
  }

  auto *record = new WindowRecord{
      .monitor =
          monitor != nullptr ? GDK_MONITOR(g_object_ref(monitor)) : nullptr,
      .window = window,
      .channel_suffix = suffix,
  };
  g_ptr_array_add(self->windows, record);
}

void monitor_added_cb(GdkDisplay *display, GdkMonitor *monitor,
                      gpointer user_data) {
  (void)display;
  auto *self = MY_APPLICATION(user_data);
  create_window_for_monitor(self, monitor);
  refresh_monitor_descriptors(self);
}

void monitor_removed_cb(GdkDisplay *display, GdkMonitor *monitor,
                        gpointer user_data) {
  (void)display;
  auto *self = MY_APPLICATION(user_data);
  for (guint index = 0; index < self->windows->len; ++index) {
    auto *record =
        static_cast<WindowRecord *>(g_ptr_array_index(self->windows, index));
    if (record->monitor == monitor) {
      clear_window_channel(self, record);
      g_ptr_array_remove_index(self->windows, index);
      break;
    }
  }
  refresh_monitor_descriptors(self);
}
} // namespace

// Implements GApplication::activate.
static void my_application_activate(GApplication *application) {
  MyApplication *self = MY_APPLICATION(application);

  if (self->engine != nullptr) {
    return;
  }

  const std::vector<MonitorDescriptor> monitors = hyprbaric_monitors();
  auto primary =
      std::find_if(monitors.begin(), monitors.end(),
                   [](const auto &monitor) { return monitor.is_primary; });
  if (primary != monitors.end()) {
    create_window_for_monitor(self, primary->monitor);
  }
  for (const MonitorDescriptor &monitor : monitors) {
    create_window_for_monitor(self, monitor.monitor);
  }
  if (monitors.empty()) {
    create_window_for_monitor(self, nullptr);
  }

  GdkDisplay *display = gdk_display_get_default();
  if (display != nullptr) {
    self->monitor_added_handler = g_signal_connect(
        display, "monitor-added", G_CALLBACK(monitor_added_cb), self);
    self->monitor_removed_handler = g_signal_connect(
        display, "monitor-removed", G_CALLBACK(monitor_removed_cb), self);
  }
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication *application,
                                                  gchar ***arguments,
                                                  int *exit_status) {
  MyApplication *self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication *application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication *application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject *object) {
  MyApplication *self = MY_APPLICATION(object);
  GdkDisplay *display = gdk_display_get_default();
  if (display != nullptr && self->monitor_added_handler != 0) {
    g_signal_handler_disconnect(display, self->monitor_added_handler);
  }
  if (display != nullptr && self->monitor_removed_handler != 0) {
    g_signal_handler_disconnect(display, self->monitor_removed_handler);
  }
  if (self->windows != nullptr) {
    for (guint index = 0; index < self->windows->len; ++index) {
      clear_window_channel(self, static_cast<WindowRecord *>(
                                     g_ptr_array_index(self->windows, index)));
    }
  }
  g_clear_pointer(&self->windows, g_ptr_array_unref);
  g_clear_object(&self->engine);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass *klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication *self) {
  self->windows = g_ptr_array_new_with_free_func(window_record_free);
}

MyApplication *my_application_new() {
  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
