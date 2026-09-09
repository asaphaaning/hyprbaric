#include <gtk/gtk.h>

static void activate_action(GSimpleAction *action, GVariant *parameter,
                            gpointer user_data) {
  const char *name = g_action_get_name(G_ACTION(action));
  g_print("activate %s\n", name);
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

static GMenuModel *app_menu(void) {
  GMenu *menu = g_menu_new();
  g_menu_append(menu, "_About Dual Menu", "app.about");
  g_menu_append(menu, "_Quit", "app.quit");
  return G_MENU_MODEL(menu);
}

static GMenuModel *menubar(void) {
  GMenu *bar = g_menu_new();
  GMenu *file = g_menu_new();
  GMenu *edit = g_menu_new();

  g_menu_append(file, "_New", "app.new");
  g_menu_append(edit, "_Copy", "app.copy");
  g_menu_append_submenu(bar, "_File", G_MENU_MODEL(file));
  g_menu_append_submenu(bar, "_Edit", G_MENU_MODEL(edit));
  g_object_unref(file);
  g_object_unref(edit);

  return G_MENU_MODEL(bar);
}

static void startup(GtkApplication *application, gpointer user_data) {
  GMenuModel *application_menu = app_menu();
  GMenuModel *bar = menubar();

  (void)user_data;
  add_action(application, "about", G_CALLBACK(activate_action));
  add_action(application, "new", G_CALLBACK(activate_action));
  add_action(application, "copy", G_CALLBACK(activate_action));
  add_action(application, "quit", G_CALLBACK(quit_action));
  gtk_application_set_app_menu(application, application_menu);
  gtk_application_set_menubar(application, bar);
  g_object_unref(application_menu);
  g_object_unref(bar);
}

static void activate(GtkApplication *application, gpointer user_data) {
  GtkWidget *window = gtk_application_window_new(application);
  GtkWidget *label = gtk_label_new("GTK3 application menu + menubar");

  (void)user_data;
  gtk_window_set_default_size(GTK_WINDOW(window), 420, 180);
  gtk_window_set_title(GTK_WINDOW(window), "Hyprbaric GTK3 Dual Menu Probe");
  gtk_container_add(GTK_CONTAINER(window), label);
  gtk_widget_show_all(window);
}

int main(int argc, char **argv) {
  GtkApplication *application = gtk_application_new(
      "org.hyprbaric.Gtk3DualMenuProbe", G_APPLICATION_DEFAULT_FLAGS);

  g_signal_connect(application, "startup", G_CALLBACK(startup), NULL);
  g_signal_connect(application, "activate", G_CALLBACK(activate), NULL);
  int status = g_application_run(G_APPLICATION(application), argc, argv);
  g_object_unref(application);

  return status;
}
