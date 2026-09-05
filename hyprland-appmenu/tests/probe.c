#include <wayland-client.h>

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "appmenu-client-protocol.h"

/// The Wayland globals required to publish one AppMenu endpoint.
struct client {
  struct wl_compositor *compositor;
  struct org_kde_kwin_appmenu_manager *manager;
};

static void registry_global(void *data, struct wl_registry *registry,
                            uint32_t name, const char *interface,
                            uint32_t version) {
  struct client *client = data;

  if (strcmp(interface, wl_compositor_interface.name) == 0) {
    client->compositor = wl_registry_bind(
        registry, name, &wl_compositor_interface, version < 4 ? version : 4);
  }

  if (strcmp(interface, org_kde_kwin_appmenu_manager_interface.name) == 0) {
    client->manager = wl_registry_bind(
        registry, name, &org_kde_kwin_appmenu_manager_interface, 1);
  }
}

static void registry_global_remove(void *data, struct wl_registry *registry,
                                   uint32_t name) {
  (void)data;
  (void)registry;
  (void)name;
}

static const struct wl_registry_listener REGISTRY_LISTENER = {
    .global = registry_global,
    .global_remove = registry_global_remove,
};

static long hold_milliseconds(int argc, char **argv) {
  if (argc == 1)
    return 0;

  if (argc != 3 || strcmp(argv[1], "--hold-ms") != 0) {
    fprintf(stderr, "usage: %s [--hold-ms milliseconds]\n", argv[0]);
    return -1;
  }

  char *end = NULL;
  const long value = strtol(argv[2], &end, 10);
  if (errno != 0 || !end || *end != '\0' || value < 0) {
    fprintf(stderr, "invalid hold duration: %s\n", argv[2]);
    return -1;
  }

  return value;
}

int main(int argc, char **argv) {
  const long hold = hold_milliseconds(argc, argv);
  if (hold < 0)
    return EXIT_FAILURE;

  struct wl_display *display = wl_display_connect(NULL);
  if (!display) {
    perror("wl_display_connect");
    return EXIT_FAILURE;
  }

  struct client client = {0};
  struct wl_registry *registry = wl_display_get_registry(display);
  wl_registry_add_listener(registry, &REGISTRY_LISTENER, &client);

  if (wl_display_roundtrip(display) < 0 || !client.compositor ||
      !client.manager) {
    fprintf(stderr,
            "Hyprland did not advertise the required AppMenu globals\n");
    wl_registry_destroy(registry);
    wl_display_disconnect(display);
    return EXIT_FAILURE;
  }

  struct wl_surface *surface = wl_compositor_create_surface(client.compositor);
  struct org_kde_kwin_appmenu *menu =
      org_kde_kwin_appmenu_manager_create(client.manager, surface);
  org_kde_kwin_appmenu_set_address(menu, "org.hyprbaric.AppMenuProbe",
                                   "/org/hyprbaric/AppMenuProbe");
  wl_display_roundtrip(display);

  printf("Published AppMenu endpoint for %ld ms\n", hold);
  fflush(stdout);

  if (hold > 0) {
    const struct timespec duration = {
        .tv_sec = hold / 1000,
        .tv_nsec = (hold % 1000) * 1000000L,
    };
    nanosleep(&duration, NULL);
  }

  org_kde_kwin_appmenu_release(menu);
  wl_surface_destroy(surface);
  wl_proxy_destroy((struct wl_proxy *)client.manager);
  wl_compositor_destroy(client.compositor);
  wl_registry_destroy(registry);
  wl_display_disconnect(display);
  return EXIT_SUCCESS;
}
