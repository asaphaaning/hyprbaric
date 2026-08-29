#ifndef FLUTTER_LAYER_SHELL_HOST_H_
#define FLUTTER_LAYER_SHELL_HOST_H_

#include <flutter_linux/flutter_linux.h>

#include "native_window_state.h"

void hyprbaric_layer_shell_host_register(FlBinaryMessenger *messenger,
                                         NativeWindowState *state,
                                         const char *suffix);

#endif // FLUTTER_LAYER_SHELL_HOST_H_
