#include <gtk/gtk.h>

static void activate_action(GSimpleAction *action, GVariant *parameter,
                            gpointer user_data) {
  (void)action;
  (void)parameter;
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

static GMenuModel *menu(void) {
  GMenu *menubar = g_menu_new();
  GMenu *file = g_menu_new();
  GMenu *edit = g_menu_new();
  GMenu *view = g_menu_new();

  g_menu_append(file, "_New", "app.new");
  g_menu_append(file, "_Quit", "app.quit");
  g_menu_append(edit, "_Copy", "app.copy");
  g_menu_append(edit, "_Paste", "app.paste");
  g_menu_append(view, "_Refresh", "app.refresh");

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
  add_action(application, "quit", G_CALLBACK(quit_action));
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
