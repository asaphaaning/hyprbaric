#include <gtk/gtk.h>

static void activate_action(GSimpleAction *action, GVariant *parameter,
                            gpointer user_data) {
  const char *name = g_action_get_name(G_ACTION(action));
  gchar *printed = parameter ? g_variant_print(parameter, TRUE) : g_strdup("-");
  g_print("activate %s %s\n", name, printed);
  g_free(printed);
  (void)user_data;
}

static void toggle_action(GSimpleAction *action, GVariant *parameter,
                          gpointer user_data) {
  GVariant *state = g_action_get_state(G_ACTION(action));
  gboolean next = !g_variant_get_boolean(state);
  g_simple_action_set_state(action, g_variant_new_boolean(next));
  g_variant_unref(state);
  (void)parameter;
  (void)user_data;
}

static void radio_action(GSimpleAction *action, GVariant *parameter,
                         gpointer user_data) {
  if (parameter != NULL) {
    g_simple_action_set_state(action, g_variant_ref(parameter));
  }
  (void)user_data;
}

static void quit_action(GSimpleAction *action, GVariant *parameter,
                        gpointer user_data) {
  (void)action;
  (void)parameter;
  g_application_quit(G_APPLICATION(user_data));
}

static void add_action(GtkApplication *application, const char *name,
                       GCallback callback) {
  GSimpleAction *action = g_simple_action_new(name, NULL);
  g_signal_connect(action, "activate", callback, application);
  g_action_map_add_action(G_ACTION_MAP(application), G_ACTION(action));
  g_object_unref(action);
}

static void add_disabled(GtkApplication *application, const char *name) {
  GSimpleAction *action = g_simple_action_new(name, NULL);
  g_simple_action_set_enabled(action, FALSE);
  g_action_map_add_action(G_ACTION_MAP(application), G_ACTION(action));
  g_object_unref(action);
}

static void add_toggle(GtkApplication *application, const char *name,
                       gboolean initial) {
  GSimpleAction *action =
      g_simple_action_new_stateful(name, NULL, g_variant_new_boolean(initial));
  g_signal_connect(action, "activate", G_CALLBACK(toggle_action), application);
  g_action_map_add_action(G_ACTION_MAP(application), G_ACTION(action));
  g_object_unref(action);
}

static void add_radio(GtkApplication *application, const char *name,
                      const char *initial) {
  GSimpleAction *action = g_simple_action_new_stateful(
      name, G_VARIANT_TYPE_STRING, g_variant_new_string(initial));
  g_signal_connect(action, "activate", G_CALLBACK(radio_action), application);
  g_action_map_add_action(G_ACTION_MAP(application), G_ACTION(action));
  g_object_unref(action);
}

static void add_parameterized(GtkApplication *application, const char *name) {
  GSimpleAction *action = g_simple_action_new(name, G_VARIANT_TYPE_STRING);
  g_signal_connect(action, "activate", G_CALLBACK(activate_action), application);
  g_action_map_add_action(G_ACTION_MAP(application), G_ACTION(action));
  g_object_unref(action);
}

static GMenuModel *menu(void) {
  GMenu *menubar = g_menu_new();
  GMenu *file = g_menu_new();
  GMenu *edit = g_menu_new();
  GMenu *view = g_menu_new();
  GMenuItem *quit = g_menu_item_new("_Quit", "app.quit");

  g_menu_append(file, "_New", "app.new");
  g_menu_item_set_attribute(quit, "accel", "s", "<Primary>q");
  g_menu_append_item(file, quit);
  g_object_unref(quit);
  g_menu_append(file, "notes.txt", "app.open-file::notes.txt");

  g_menu_append(edit, "_Copy", "app.copy");
  g_menu_append(edit, "_Paste", "app.paste");
  g_menu_append(edit, "_Undo", "app.undo");

  g_menu_append(view, "_Refresh", "app.refresh");
  g_menu_append(view, "_Fullscreen", "app.fullscreen");
  g_menu_append(view, "_Left", "app.justify::left");
  g_menu_append(view, "_Center", "app.justify::center");
  g_menu_append(view, "_Right", "app.justify::right");

  g_menu_append_submenu(menubar, "_File", G_MENU_MODEL(file));
  g_menu_append_submenu(menubar, "_Edit", G_MENU_MODEL(edit));
  g_menu_append_submenu(menubar, "_View", G_MENU_MODEL(view));

  g_object_unref(file);
  g_object_unref(edit);
  g_object_unref(view);

  return G_MENU_MODEL(menubar);
}

static void startup(GtkApplication *application, gpointer user_data) {
  (void)user_data;

  GMenuModel *menubar = menu();
  add_action(application, "new", G_CALLBACK(activate_action));
  add_action(application, "copy", G_CALLBACK(activate_action));
  add_action(application, "paste", G_CALLBACK(activate_action));
  add_action(application, "refresh", G_CALLBACK(activate_action));
  add_disabled(application, "undo");
  add_toggle(application, "fullscreen", TRUE);
  add_radio(application, "justify", "left");
  add_parameterized(application, "open-file");
  add_action(application, "quit", G_CALLBACK(quit_action));
  gtk_application_set_accels_for_action(application, "app.new",
                                        (const char *[]){"<Primary>n", NULL});
  gtk_application_set_menubar(application, menubar);
  g_object_unref(menubar);
}

static void activate(GtkApplication *application, gpointer user_data) {
  (void)user_data;

  GtkWidget *window = gtk_application_window_new(application);
  gtk_window_set_default_size(GTK_WINDOW(window), 420, 180);
  gtk_window_set_title(GTK_WINDOW(window), "Hyprbaric GTK Menu Probe");
  gtk_window_set_child(GTK_WINDOW(window),
                       gtk_label_new("GTK4 GMenuModel exporter"));
  gtk_window_present(GTK_WINDOW(window));
}

int main(int argc, char **argv) {
  GtkApplication *application = gtk_application_new(
      "org.hyprbaric.GtkMenuProbe", G_APPLICATION_DEFAULT_FLAGS);

  g_signal_connect(application, "startup", G_CALLBACK(startup), NULL);
  g_signal_connect(application, "activate", G_CALLBACK(activate), NULL);
  int status = g_application_run(G_APPLICATION(application), argc, argv);
  g_object_unref(application);

  return status;
}
