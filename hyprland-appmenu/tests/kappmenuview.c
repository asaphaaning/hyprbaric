#include <gio/gio.h>

/// Holds the KDE and Qt AppMenu registration names for an integration test.
///
/// KDE and Qt applications detect one of these names during startup, then
/// begin exporting their real menu bars via the Wayland AppMenu protocol.
int main(void) {
  GMainLoop *loop = g_main_loop_new(NULL, FALSE);
  const guint registrar =
      g_bus_own_name(G_BUS_TYPE_SESSION, "com.canonical.AppMenu.Registrar",
                     G_BUS_NAME_OWNER_FLAGS_NONE, NULL, NULL, NULL, NULL, NULL);
  const guint provider =
      g_bus_own_name(G_BUS_TYPE_SESSION, "org.kde.kappmenu",
                     G_BUS_NAME_OWNER_FLAGS_NONE, NULL, NULL, NULL, NULL, NULL);
  const guint consumer =
      g_bus_own_name(G_BUS_TYPE_SESSION, "org.kde.kappmenuview",
                     G_BUS_NAME_OWNER_FLAGS_NONE, NULL, NULL, NULL, NULL, NULL);

  g_main_loop_run(loop);

  g_bus_unown_name(consumer);
  g_bus_unown_name(provider);
  g_bus_unown_name(registrar);
  g_main_loop_unref(loop);
  return 0;
}
