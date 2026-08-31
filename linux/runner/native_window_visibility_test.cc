#include "native_window_visibility.h"

#include <cstdlib>
#include <iostream>

namespace {
struct Scenario {
  const char *name;
  bool selected;
  bool first_frame_rendered;
  NativeWindowVisibility expected;
};
} // namespace

int main() {
  constexpr Scenario scenarios[] = {
      {
          "unselected windows remain hidden before rendering",
          false,
          false,
          NativeWindowVisibility::kHidden,
      },
      {
          "unselected windows remain hidden after rendering",
          false,
          true,
          NativeWindowVisibility::kHidden,
      },
      {
          "newly selected windows are primed before rendering",
          true,
          false,
          NativeWindowVisibility::kPriming,
      },
      {
          "selected windows become visible after rendering",
          true,
          true,
          NativeWindowVisibility::kVisible,
      },
  };

  for (const Scenario &scenario : scenarios) {
    const NativeWindowVisibility actual = native_window_visibility(
        scenario.selected, scenario.first_frame_rendered);
    if (actual != scenario.expected) {
      std::cerr << "Failed: " << scenario.name << '\n';
      return EXIT_FAILURE;
    }
  }

  return EXIT_SUCCESS;
}
