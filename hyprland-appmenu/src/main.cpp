#include <hyprland/src/Compositor.hpp>
#include <hyprland/src/SharedDefs.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/view/Window.hpp>
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/protocols/XDGShell.hpp>
#include <hyprland/src/protocols/core/Compositor.hpp>
#include <hyprland/src/xwayland/XSurface.hpp>

#include <wayland-server-core.h>

#include <algorithm>
#include <cstdint>
#include <memory>
#include <optional>
#include <string>
#include <stdexcept>
#include <unordered_map>
#include <unordered_set>
#include <utility>
#include <vector>

#include "appmenu-server-protocol.h"
#include "gtk-shell-server-protocol.h"

namespace {

/// One D-BusMenu address published by a Wayland client.
struct Endpoint {
  std::string service;
  std::string path;
  std::optional<std::string> window_address;
};

/// An XWayland window's X11 identifier, used to join the AppMenu registrar.
struct X11Window {
  std::string address;
  uint32_t xid = 0;
};

/// A mapped window and the owner Hyprland reports for it.
///
/// Save/Open/Preferences dialogs take focus but do not export a menu. The
/// bar walks this link to the document window that still does.
struct ParentLink {
  std::string address;
  std::string parent;
};

class Registry;

/// GTK's D-Bus menu and action paths, published for one wl_surface.
///
/// `gtk_shell1` can name both an application menu and a menubar. The bar
/// keeps them distinct: `menu_path` is the menubar when one exists, otherwise
/// the app menu. `app_menu_path` is set only when both were published.
struct GtkEndpoint {
  std::string service;
  std::string menu_path;
  std::string app_menu_path;
  std::string application_path;
  std::string window_path;
  std::optional<std::string> window_address;
};

/// A client `wl_surface` as known to Hyprland at bind time.
///
/// AppMenu and `gtk_surface1` objects can outlive that `wl_surface`.
/// `CWLSurfaceResource::fromResource` dereferences the resource without a
/// liveness check, so later IPC must not call it on a stored pointer. The weak
/// handle expires with the compositor object; the protocol id is kept for
/// snapshot output after the surface is gone.
struct BoundSurface {
  WP<CWLSurfaceResource> resource;
  uint32_t id = 0;

  static BoundSurface from(wl_resource *surface) {
    BoundSurface bound;
    if (!surface)
      return bound;

    bound.id = wl_resource_get_id(surface);

    if (PROTO::compositor) {
      PROTO::compositor->forEachSurface(
          [&](const SP<CWLSurfaceResource> &candidate) {
            if (bound.resource || !candidate)
              return;

            const auto wrapper = candidate->getResource();
            if (wrapper && wrapper->resource() == surface)
              bound.resource = candidate;
          });
    }

    if (!bound.resource && wl_resource_get_user_data(surface))
      bound.resource = CWLSurfaceResource::fromResource(surface);

    return bound;
  }

  SP<CWLSurfaceResource> lock() const { return resource.lock(); }
};

/// One GTK shell surface bound to a wl_surface.
struct GtkSurface {
  Registry *owner = nullptr;
  wl_resource *resource = nullptr;
  BoundSurface surface;
  std::optional<GtkEndpoint> endpoint;
};

/// A client's AppMenu object, bound to one wl_surface.
struct Menu {
  Registry *owner = nullptr;
  wl_resource *resource = nullptr;
  BoundSurface surface;
  std::optional<Endpoint> endpoint;
};

/// The compositor-owned state for the AppMenu protocol.
///
class Registry {
public:
  explicit Registry(wl_display *display)
      : appmenu_global_(wl_global_create(
            display, &org_kde_kwin_appmenu_manager_interface, 1, this, bind)),
        gtk_global_(wl_global_create(display, &gtk_shell1_interface, 1, this,
                                     bind_gtk)) {}

  ~Registry() { close(); }

  Registry(const Registry &) = delete;
  Registry &operator=(const Registry &) = delete;

  /// Returns all currently published AppMenu endpoints.
  std::string snapshot(eHyprCtlOutputFormat format) const {
    const auto menus = endpoints();
    const auto gtk_surfaces = gtk_endpoints();
    const auto x11 = x11_windows();
    const auto parents = parent_links();

    if (format == FORMAT_JSON)
      return snapshot_json(menus, gtk_surfaces, x11, parents);

    if (menus.empty() && gtk_surfaces.empty() && x11.empty() &&
        parents.empty())
      return "No AppMenu endpoints.\n";

    std::string result;
    for (const auto *menu : menus) {
      result += "surface=" + std::to_string(menu->surface.id);
      if (const auto address = address_for(*menu))
        result += " address=" + *address;
      result += " service=" + menu->endpoint->service;
      result += " path=" + menu->endpoint->path + "\n";
    }

    for (const auto *surface : gtk_surfaces) {
      result += "surface=" + std::to_string(surface->surface.id);
      if (const auto address = address_for(*surface))
        result += " address=" + *address;
      result += " kind=gtk service=" + surface->endpoint->service;
      result += " menubar=" + surface->endpoint->menu_path;
      if (!surface->endpoint->app_menu_path.empty())
        result += " appmenu=" + surface->endpoint->app_menu_path;
      result += "\n";
    }

    for (const auto &window : x11) {
      result += "kind=x11 address=" + window.address;
      result += " xid=" + std::to_string(window.xid) + "\n";
    }

    for (const auto &link : parents) {
      result += "kind=parent address=" + link.address;
      result += " parent=" + link.parent + "\n";
    }

    return result;
  }

private:
  static void bind(wl_client *client, void *data, uint32_t version,
                   uint32_t id) {
    auto *registry = static_cast<Registry *>(data);
    auto *manager =
        wl_resource_create(client, &org_kde_kwin_appmenu_manager_interface,
                           std::min(version, 1U), id);

    if (!manager) {
      wl_client_post_no_memory(client);
      return;
    }

    wl_resource_set_implementation(manager, &manager_implementation, registry,
                                   destroy_manager);
    registry->managers_.insert(manager);
  }

  static void create_menu(wl_client *client, wl_resource *manager, uint32_t id,
                          wl_resource *surface) {
    auto *registry =
        static_cast<Registry *>(wl_resource_get_user_data(manager));
    if (!registry)
      return;

    auto *resource = wl_resource_create(client, &org_kde_kwin_appmenu_interface,
                                        wl_resource_get_version(manager), id);
    if (!resource) {
      wl_client_post_no_memory(client);
      return;
    }

    auto menu = std::make_unique<Menu>();
    menu->owner = registry;
    menu->resource = resource;
    menu->surface = BoundSurface::from(surface);

    auto *state = menu.get();
    registry->menus_.emplace(resource, std::move(menu));
    wl_resource_set_implementation(resource, &menu_implementation, state,
                                   destroy_menu);
  }

  static void bind_gtk(wl_client *client, void *data, uint32_t version,
                       uint32_t id) {
    auto *registry = static_cast<Registry *>(data);
    auto *shell = wl_resource_create(client, &gtk_shell1_interface,
                                     std::min(version, 1U), id);
    if (!shell) {
      wl_client_post_no_memory(client);
      return;
    }

    wl_resource_set_implementation(shell, &gtk_shell_implementation, registry,
                                   destroy_gtk_shell);
    registry->gtk_shells_.insert(shell);
    gtk_shell1_send_capabilities(shell, 1 | 2);
  }

  static void get_gtk_surface(wl_client *client, wl_resource *shell,
                              uint32_t id, wl_resource *surface) {
    auto *registry = static_cast<Registry *>(wl_resource_get_user_data(shell));
    if (!registry)
      return;

    auto *resource = wl_resource_create(client, &gtk_surface1_interface,
                                        wl_resource_get_version(shell), id);
    if (!resource) {
      wl_client_post_no_memory(client);
      return;
    }

    auto gtk_surface = std::make_unique<GtkSurface>();
    gtk_surface->owner = registry;
    gtk_surface->resource = resource;
    gtk_surface->surface = BoundSurface::from(surface);

    auto *state = gtk_surface.get();
    registry->gtk_surfaces_.emplace(resource, std::move(gtk_surface));
    wl_resource_set_implementation(resource, &gtk_surface_implementation,
                                   state, destroy_gtk_surface);
  }

  static void set_startup_id(wl_client *, wl_resource *, const char *) {}

  static void system_bell(wl_client *, wl_resource *, wl_resource *) {}

  static void set_dbus_properties(wl_client *, wl_resource *resource,
                                  const char *, const char *app_menu_path,
                                  const char *menubar_path,
                                  const char *window_path,
                                  const char *application_path,
                                  const char *service_name) {
    auto *surface = static_cast<GtkSurface *>(wl_resource_get_user_data(resource));
    if (!surface)
      return;

    const auto nonempty = [](const char *value) { return value && *value; };
    const auto menubar = nonempty(menubar_path) ? menubar_path : "";
    const auto app_menu = nonempty(app_menu_path) ? app_menu_path : "";
    const auto *menu_path = *menubar ? menubar : app_menu;
    if (!*menu_path || !service_name || !*service_name) {
      surface->endpoint.reset();
      return;
    }

    const auto *extra_app_menu =
        (*menubar && *app_menu && std::string(menubar) != app_menu) ? app_menu
                                                                    : "";

    surface->endpoint = GtkEndpoint{
        .service = service_name,
        .menu_path = menu_path,
        .app_menu_path = extra_app_menu,
        .application_path = application_path ? application_path : "",
        .window_path = window_path ? window_path : "",
        .window_address = surface->owner->window_address(surface->surface),
    };
  }

  static void set_modal(wl_client *, wl_resource *) {}

  static void unset_modal(wl_client *, wl_resource *) {}

  static void present(wl_client *, wl_resource *resource, uint32_t) {
    auto *surface =
        static_cast<GtkSurface *>(wl_resource_get_user_data(resource));
    if (!surface || !surface->endpoint)
      return;

    if (auto address = surface->owner->window_address(surface->surface))
      surface->endpoint->window_address = std::move(address);
  }

  static void set_address(wl_client *, wl_resource *resource,
                          const char *service_name, const char *object_path) {
    auto *menu = static_cast<Menu *>(wl_resource_get_user_data(resource));
    if (!menu)
      return;

    if (!service_name || !*service_name || !object_path || !*object_path) {
      menu->endpoint.reset();
      return;
    }

    menu->endpoint = Endpoint{
        .service = service_name,
        .path = object_path,
        .window_address = menu->owner->window_address(menu->surface),
    };
  }

  static void release_menu(wl_client *, wl_resource *resource) {
    wl_resource_destroy(resource);
  }

  static void destroy_manager(wl_resource *resource) {
    auto *registry =
        static_cast<Registry *>(wl_resource_get_user_data(resource));
    if (registry)
      registry->managers_.erase(resource);
  }

  static void destroy_menu(wl_resource *resource) {
    auto *menu = static_cast<Menu *>(wl_resource_get_user_data(resource));
    if (!menu)
      return;

    menu->owner->menus_.erase(resource);
  }

  static void destroy_gtk_shell(wl_resource *resource) {
    auto *registry = static_cast<Registry *>(wl_resource_get_user_data(resource));
    if (registry)
      registry->gtk_shells_.erase(resource);
  }

  static void destroy_gtk_surface(wl_resource *resource) {
    auto *surface = static_cast<GtkSurface *>(wl_resource_get_user_data(resource));
    if (surface)
      surface->owner->gtk_surfaces_.erase(resource);
  }

  std::vector<const Menu *> endpoints() const {
    std::vector<const Menu *> result;
    result.reserve(menus_.size());

    for (const auto &[_, menu] : menus_) {
      if (menu->endpoint)
        result.push_back(menu.get());
    }

    std::sort(result.begin(), result.end(),
              [](const Menu *left, const Menu *right) {
                return left->surface.id < right->surface.id;
              });

    return result;
  }

  std::vector<const GtkSurface *> gtk_endpoints() const {
    std::vector<const GtkSurface *> result;
    result.reserve(gtk_surfaces_.size());

    for (const auto &[_, surface] : gtk_surfaces_) {
      if (surface->endpoint)
        result.push_back(surface.get());
    }

    std::sort(result.begin(), result.end(),
              [](const GtkSurface *left, const GtkSurface *right) {
                return left->surface.id < right->surface.id;
              });

    return result;
  }

  /// Resolves the Hyprland window for a client surface.
  ///
  /// GTK often calls `set_dbus_properties` before the compositor has created a
  /// window for that `wl_surface`, so a lookup at request time can miss. The
  /// snapshot path asks again, and `present` retries after the window is shown.
  /// If the client has already destroyed the surface, the weak handle expires
  /// and the cached address from the last successful lookup is used instead.
  std::optional<std::string> window_address(const BoundSurface &surface) const {
    const auto surface_resource = surface.lock();
    if (!surface_resource)
      return std::nullopt;

    if (const auto window = std::move(Desktop::viewState()->query())
                                .surface(surface_resource)
                                .runWindow())
      return address_of(window);

    for (const auto &window : Desktop::windowState()->windows()) {
      if (window_owns_surface(window, surface_resource))
        return address_of(window);
    }

    return std::nullopt;
  }

  std::optional<std::string> address_for(const Menu &menu) const {
    return live_or_cached(menu.surface, menu.endpoint->window_address);
  }

  std::optional<std::string> address_for(const GtkSurface &surface) const {
    return live_or_cached(surface.surface, surface.endpoint->window_address);
  }

  std::optional<std::string>
  live_or_cached(const BoundSurface &surface,
                 const std::optional<std::string> &cached) const {
    if (auto live = window_address(surface))
      return live;
    return cached;
  }

  static std::string address_of(const PHLWINDOW &window) {
    return "0x" + pointer_hex(window.get());
  }

  static bool window_owns_surface(const PHLWINDOW &window,
                                  const SP<CWLSurfaceResource> &surface) {
    if (!window || !surface)
      return false;

    if (window->resource() == surface)
      return true;

    if (const auto xdg = window->m_xdgSurface.lock()) {
      if (xdg->m_surface.lock() == surface)
        return true;
    }

    if (const auto xwayland = window->m_xwaylandSurface.lock()) {
      if (xwayland->m_surface.lock() == surface)
        return true;
    }

    return false;
  }

  std::vector<X11Window> x11_windows() const {
    std::vector<X11Window> result;
    const auto &windows = Desktop::windowState()->windows();
    result.reserve(windows.size());

    for (const auto &window : windows) {
      if (!window || !window->m_isX11)
        continue;

      const auto xwayland = window->m_xwaylandSurface.lock();
      if (!xwayland || xwayland->m_xID == 0)
        continue;

      result.push_back(X11Window{
          .address = "0x" + pointer_hex(window.get()),
          .xid = xwayland->m_xID,
      });
    }

    return result;
  }

  std::vector<ParentLink> parent_links() const {
    std::vector<ParentLink> result;
    const auto &windows = Desktop::windowState()->windows();
    result.reserve(windows.size());

    for (const auto &window : windows) {
      if (!window)
        continue;

      const auto parent = window->parent();
      if (!parent)
        continue;

      result.push_back(ParentLink{
          .address = address_of(window),
          .parent = address_of(parent),
      });
    }

    return result;
  }

  void close() {
    while (!gtk_surfaces_.empty())
      wl_resource_destroy(gtk_surfaces_.begin()->first);

    while (!gtk_shells_.empty())
      wl_resource_destroy(*gtk_shells_.begin());

    while (!menus_.empty())
      wl_resource_destroy(menus_.begin()->first);

    while (!managers_.empty())
      wl_resource_destroy(*managers_.begin());

    if (gtk_global_) {
      wl_global_destroy(gtk_global_);
      gtk_global_ = nullptr;
    }

    if (appmenu_global_) {
      wl_global_destroy(appmenu_global_);
      appmenu_global_ = nullptr;
    }
  }

  std::string snapshot_json(
      const std::vector<const Menu *> &menus,
      const std::vector<const GtkSurface *> &gtk_surfaces,
      const std::vector<X11Window> &x11,
      const std::vector<ParentLink> &parents) const {
    std::string result = "[";
    bool first = true;
    const auto comma = [&] {
      if (!first)
        result += ',';
      first = false;
    };

    for (const auto *menu : menus) {
      comma();
      result += "{\"surface\":" + std::to_string(menu->surface.id);
      if (const auto address = address_for(*menu)) {
        result += ",\"address\":\"";
        result += *address;
        result += "\"";
      }
      result += ",\"kind\":\"dbusmenu\"";
      result += ",\"service\":\"" + escape_json(menu->endpoint->service) + "\"";
      result += ",\"path\":\"" + escape_json(menu->endpoint->path) + "\"}";
    }

    for (const auto *surface : gtk_surfaces) {
      comma();
      result += "{\"surface\":" + std::to_string(surface->surface.id);
      if (const auto address = address_for(*surface)) {
        result += ",\"address\":\"";
        result += *address;
        result += "\"";
      }
      result += ",\"kind\":\"gtk\"";
      result += ",\"service\":\"" +
                escape_json(surface->endpoint->service) + "\"";
      result += ",\"path\":\"" +
                escape_json(surface->endpoint->menu_path) + "\"";
      if (!surface->endpoint->app_menu_path.empty()) {
        result += ",\"app_menu_path\":\"" +
                  escape_json(surface->endpoint->app_menu_path) + "\"";
      }
      result += ",\"application_path\":\"" +
                escape_json(surface->endpoint->application_path) + "\"";
      result += ",\"window_path\":\"" +
                escape_json(surface->endpoint->window_path) + "\"}";
    }

    for (const auto &window : x11) {
      comma();
      result += "{\"kind\":\"x11\",\"address\":\"";
      result += escape_json(window.address);
      result += "\",\"xid\":";
      result += std::to_string(window.xid);
      result += "}";
    }

    for (const auto &link : parents) {
      comma();
      result += "{\"kind\":\"parent\",\"address\":\"";
      result += escape_json(link.address);
      result += "\",\"parent\":\"";
      result += escape_json(link.parent);
      result += "\"}";
    }

    return result + "]\n";
  }

  static std::string escape_json(const std::string &value) {
    constexpr char HEX[] = "0123456789abcdef";
    std::string result;
    result.reserve(value.size());

    for (const unsigned char character : value) {
      switch (character) {
      case '"':
        result += "\\\"";
        break;
      case '\\':
        result += "\\\\";
        break;
      case '\b':
        result += "\\b";
        break;
      case '\f':
        result += "\\f";
        break;
      case '\n':
        result += "\\n";
        break;
      case '\r':
        result += "\\r";
        break;
      case '\t':
        result += "\\t";
        break;
      default:
        if (character < 0x20) {
          result += "\\u00";
          result += HEX[character >> 4];
          result += HEX[character & 0x0F];
        } else {
          result += static_cast<char>(character);
        }
      }
    }

    return result;
  }

  static std::string pointer_hex(const void *pointer) {
    constexpr char DIGITS[] = "0123456789abcdef";
    const auto value = reinterpret_cast<std::uintptr_t>(pointer);
    std::string result;

    for (auto shift = static_cast<int>((sizeof(value) * 8) - 4); shift >= 0;
         shift -= 4)
      result += DIGITS[(value >> shift) & 0xF];

    const auto first = result.find_first_not_of('0');
    return first == std::string::npos ? "0" : result.substr(first);
  }

  inline static const struct org_kde_kwin_appmenu_manager_interface
      manager_implementation = {
          .create = create_menu,
  };
  inline static const struct org_kde_kwin_appmenu_interface
      menu_implementation = {
          .set_address = set_address,
          .release = release_menu,
  };

  inline static const struct gtk_shell1_interface gtk_shell_implementation = {
      .get_gtk_surface = get_gtk_surface,
      .set_startup_id = set_startup_id,
      .system_bell = system_bell,
  };
  inline static const struct gtk_surface1_interface gtk_surface_implementation = {
      .set_dbus_properties = set_dbus_properties,
      .set_modal = set_modal,
      .unset_modal = unset_modal,
      .present = present,
  };

  wl_global *appmenu_global_ = nullptr;
  wl_global *gtk_global_ = nullptr;
  std::unordered_set<wl_resource *> managers_;
  std::unordered_map<wl_resource *, std::unique_ptr<Menu>> menus_;
  std::unordered_set<wl_resource *> gtk_shells_;
  std::unordered_map<wl_resource *, std::unique_ptr<GtkSurface>> gtk_surfaces_;
};

std::unique_ptr<Registry> registry;
SP<SHyprCtlCommand> command;
HANDLE handle = nullptr;

} // namespace

#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wreturn-type-c-linkage"
#endif

APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE plugin_handle) {
  if (std::string(__hyprland_api_get_hash()) != __hyprland_api_get_client_hash())
    throw std::runtime_error("Hyprbaric AppMenu: compositor/header ABI mismatch");

  handle = plugin_handle;
  registry = std::make_unique<Registry>(g_pCompositor->m_wlDisplay);

  command = HyprlandAPI::registerHyprCtlCommand(
      handle, SHyprCtlCommand{
                  .name = "hyprbaric-appmenu",
                  .exact = true,
                  .fn = [](eHyprCtlOutputFormat format,
                           std::string) { return registry->snapshot(format); },
              });

  return {
      .name = "Hyprbaric AppMenu",
      .description =
          "Qt and GTK AppMenu protocol bridge for Hyprbaric",
      .author = "Hyprbaric",
      .version = "0.1.0",
  };
}

APICALL EXPORT void PLUGIN_EXIT() {
  if (command)
    HyprlandAPI::unregisterHyprCtlCommand(handle, command);

  command.reset();
  registry.reset();
  handle = nullptr;
}

#ifdef __clang__
#pragma clang diagnostic pop
#endif
