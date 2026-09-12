import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../bindings/bindings.dart';
import '../rust_commands.dart';

part 'network_controller.g.dart';

@Riverpod(keepAlive: true)
class NetworkController extends _$NetworkController {
  @override
  void build() {}

  void join(NetworkJoinRequest request) {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(NetworkIntent.join(request));
  }

  void scan() {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(const NetworkIntent.scan());
  }

  void setWifiEnabled({required bool enabled}) {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(NetworkIntent.setWifiEnabled(enabled: enabled));
  }

  void connect(NetworkEntry entry, String? password) {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(
          NetworkIntent.connect(
            ssid: entry.ssid,
            bssid: entry.bssid,
            password: password,
          ),
        );
  }

  void disconnect(NetworkInterface interface) {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(NetworkIntent.disconnect(interface));
  }

  void setAutoConnect(NetworkInterface interface, {required bool enabled}) {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(NetworkIntent.setAutoConnect(interface, enabled: enabled));
  }

  void openSettings() {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(const NetworkIntent.openSettings());
  }
}
