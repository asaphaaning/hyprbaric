import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';
import '../rust_commands.dart';

final appearanceControllerProvider =
    NotifierProvider<AppearanceController, void>(AppearanceController.new);

class AppearanceController extends Notifier<void> {
  @override
  void build() {}

  void setPosition(AppearancePosition position) {
    _dispatch(AppearanceIntent.setPosition(position));
  }

  void setMonitor(AppearanceMonitorTarget monitor) {
    _dispatch(AppearanceIntent.setMonitor(monitor));
  }

  void setOpacity(int opacity) {
    if (opacity < 20 || opacity > 100) {
      return;
    }
    _dispatch(AppearanceIntent.setOpacity(opacity));
  }

  void setCornerRadius(int cornerRadius) {
    if (cornerRadius < 0 || cornerRadius > 32) {
      return;
    }
    _dispatch(AppearanceIntent.setCornerRadius(cornerRadius));
  }

  void setAccentHue(int accentHue) {
    if (accentHue < 0 || accentHue > 359) {
      return;
    }
    _dispatch(AppearanceIntent.setAccentHue(accentHue));
  }

  void restoreDefaults() {
    _dispatch(const AppearanceIntent.restoreDefaults());
  }

  void _dispatch(AppearanceIntent intent) {
    ref.read(rustCommandDispatcherProvider).dispatch(intent);
  }
}
