#include "monitor.h"

#include <algorithm>

namespace {
GdkMonitor *primary_monitor(GdkDisplay *display) {
  GdkMonitor *monitor = gdk_display_get_primary_monitor(display);
  if (monitor == nullptr && gdk_display_get_n_monitors(display) > 0) {
    monitor = gdk_display_get_monitor(display, 0);
  }
  return monitor;
}

std::string monitor_model(GdkMonitor *monitor, int index) {
  const gchar *model = gdk_monitor_get_model(monitor);
  if (model != nullptr && model[0] != '\0') {
    return model;
  }
  return "Monitor " + std::to_string(index + 1);
}

std::string monitor_label(GdkMonitor *monitor, const std::string &model) {
  const gchar *manufacturer = gdk_monitor_get_manufacturer(monitor);
  if (manufacturer == nullptr || manufacturer[0] == '\0' ||
      model.find(manufacturer) != std::string::npos) {
    return model;
  }
  return std::string(manufacturer) + " " + model;
}
} // namespace

std::vector<MonitorDescriptor> hyprbaric_monitors() {
  GdkDisplay *display = gdk_display_get_default();
  if (display == nullptr) {
    return {};
  }

  const int count = gdk_display_get_n_monitors(display);
  GdkMonitor *primary = primary_monitor(display);
  std::vector<std::string> models;
  models.reserve(count);

  for (int index = 0; index < count; ++index) {
    models.push_back(
        monitor_model(gdk_display_get_monitor(display, index), index));
  }

  std::vector<MonitorDescriptor> monitors;
  monitors.reserve(count);
  for (int index = 0; index < count; ++index) {
    GdkMonitor *monitor = gdk_display_get_monitor(display, index);
    const std::string &model = models[index];
    const int duplicates =
        static_cast<int>(std::count(models.begin(), models.end(), model));
    const int occurrence = static_cast<int>(
        std::count(models.begin(), models.begin() + index + 1, model));
    std::string name = model;
    if (duplicates > 1) {
      name += " #" + std::to_string(occurrence);
    }
    if (name == "primary" || name == "all") {
      name = "Monitor: " + name;
    }

    std::string label = monitor_label(monitor, model);
    if (duplicates > 1) {
      label += " #" + std::to_string(occurrence);
    }

    GdkRectangle geometry = {0, 0, 0, 0};
    gdk_monitor_get_geometry(monitor, &geometry);

    monitors.push_back(MonitorDescriptor{
        .monitor = monitor,
        .name = std::move(name),
        .label = std::move(label),
        .is_primary = monitor == primary,
        .geometry = geometry,
        .refresh_rate_millihertz = gdk_monitor_get_refresh_rate(monitor),
    });
  }
  return monitors;
}

MonitorDescriptor hyprbaric_monitor_descriptor(GdkMonitor *monitor) {
  std::vector<MonitorDescriptor> monitors = hyprbaric_monitors();
  auto found = std::find_if(monitors.begin(), monitors.end(),
                            [monitor](const auto &candidate) {
                              return candidate.monitor == monitor;
                            });
  if (found != monitors.end()) {
    return *found;
  }
  return MonitorDescriptor{
      .monitor = monitor,
      .name = "Primary",
      .label = "Primary monitor",
      .is_primary = TRUE,
      .geometry = {0, 0, 0, 0},
      .refresh_rate_millihertz = 0,
  };
}

gboolean hyprbaric_has_monitor(const std::string &name) {
  const std::vector<MonitorDescriptor> monitors = hyprbaric_monitors();
  return std::any_of(
      monitors.begin(), monitors.end(),
      [&name](const auto &monitor) { return monitor.name == name; });
}
