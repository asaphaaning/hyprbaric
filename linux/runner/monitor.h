#ifndef FLUTTER_MONITOR_H_
#define FLUTTER_MONITOR_H_

#include <gtk/gtk.h>

#include <string>
#include <vector>

struct MonitorDescriptor {
  GdkMonitor *monitor = nullptr;
  std::string name;
  std::string label;
  gboolean is_primary = FALSE;
  GdkRectangle geometry = {0, 0, 0, 0};
  int refresh_rate_millihertz = 0;
};

std::vector<MonitorDescriptor> hyprbaric_monitors();

MonitorDescriptor hyprbaric_monitor_descriptor(GdkMonitor *monitor);

gboolean hyprbaric_has_monitor(const std::string &name);

#endif // FLUTTER_MONITOR_H_
