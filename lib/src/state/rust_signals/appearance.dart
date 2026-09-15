import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bindings/bindings.dart';

Stream<AppearanceStatus> _appearanceStatusStream() async* {
  final latest = AppearanceStatus.latestRustSignal;
  if (latest != null) {
    yield latest.message;
  }

  await for (final rustSignal in AppearanceStatus.rustSignalStream) {
    yield rustSignal.message;
  }
}

Stream<AppearanceCommandResult> _appearanceCommandResultStream() async* {
  final latest = AppearanceCommandResult.latestRustSignal;
  if (latest != null) {
    yield latest.message;
  }

  await for (final rustSignal in AppearanceCommandResult.rustSignalStream) {
    yield rustSignal.message;
  }
}

const AppearanceStatus defaultAppearanceStatus = AppearanceStatus(
  position: AppearancePosition.top,
  monitor: AppearanceMonitorTargetPrimary(),
  opacity: 77,
  cornerRadius: 12,
  accentHue: 218,
);

final appearanceStatusProvider = StreamProvider<AppearanceStatus>(
  (ref) => _appearanceStatusStream(),
);

final appearanceCommandResultProvider = StreamProvider<AppearanceCommandResult>(
  (ref) => _appearanceCommandResultStream(),
);

final appearancePreviewProvider =
    NotifierProvider<AppearancePreviewController, AppearanceStatus?>(
      AppearancePreviewController.new,
    );

class AppearancePreviewController extends Notifier<AppearanceStatus?> {
  @override
  AppearanceStatus? build() => null;

  void preview(AppearanceStatus status) {
    state = status;
  }

  void clear() {
    state = null;
  }
}

final currentAppearanceProvider = Provider<AppearanceStatus>((ref) {
  final preview = ref.watch(appearancePreviewProvider);
  if (preview != null) {
    return preview;
  }

  return ref
      .watch(appearanceStatusProvider)
      .maybeWhen(
        data: (AppearanceStatus status) => status,
        orElse: () => defaultAppearanceStatus,
      );
});
