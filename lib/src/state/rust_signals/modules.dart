import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';

Stream<ModulesStatus> _modulesStatusStream() async* {
  final latest = ModulesStatus.latestRustSignal;
  if (latest != null) {
    yield latest.message;
  }

  await for (final rustSignal in ModulesStatus.rustSignalStream) {
    yield rustSignal.message;
  }
}

Stream<ModuleCommandResult> _moduleCommandResultStream() async* {
  final latest = ModuleCommandResult.latestRustSignal;
  if (latest != null) {
    yield latest.message;
  }

  await for (final rustSignal in ModuleCommandResult.rustSignalStream) {
    yield rustSignal.message;
  }
}

const ModulesStatus defaultModulesStatus = ModulesStatus(
  entries: <ModuleEntry>[
    ModuleEntry(module: ModuleId.activeWindowTitle, enabled: true),
    ModuleEntry(module: ModuleId.systemTray, enabled: true),
    ModuleEntry(module: ModuleId.notifications, enabled: true),
    ModuleEntry(module: ModuleId.audioDisplay, enabled: true),
    // Off until asked for: it takes over application menu bars and needs a
    // compositor plugin, so it is not something to arrive by default.
    ModuleEntry(module: ModuleId.globalMenu, enabled: false),
  ],
);

final modulesStatusProvider = StreamProvider<ModulesStatus>(
  (ref) => _modulesStatusStream(),
);

final moduleCommandResultProvider = StreamProvider<ModuleCommandResult>(
  (ref) => _moduleCommandResultStream(),
);

final currentModulesProvider = Provider<ModulesStatus>((ref) {
  return ref
      .watch(modulesStatusProvider)
      .maybeWhen(
        data: (ModulesStatus status) => status,
        orElse: () => defaultModulesStatus,
      );
});

extension ModulesStatusView on ModulesStatus {
  bool isEnabled(ModuleId module) {
    for (final ModuleEntry entry in entries) {
      if (entry.module == module) {
        return entry.enabled;
      }
    }
    return true;
  }
}
