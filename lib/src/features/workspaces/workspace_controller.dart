import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../bindings/bindings.dart';
import '../rust_commands.dart';

part 'workspace_controller.g.dart';

@Riverpod(keepAlive: true)
class WorkspaceController extends _$WorkspaceController {
  @override
  void build() {}

  void previous(String? monitorName) {
    relative(-1, monitorName);
  }

  void next(String? monitorName) {
    relative(1, monitorName);
  }

  void relative(int delta, String? monitorName) {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(WorkspaceIntent.relative(delta, monitorName));
  }

  void select(int target, String? monitorName) {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(WorkspaceIntent.absolute(target, monitorName));
  }
}

final workspaceSettingsControllerProvider =
    NotifierProvider<WorkspaceSettingsController, void>(
      WorkspaceSettingsController.new,
    );

class WorkspaceSettingsController extends Notifier<void> {
  @override
  void build() {}

  void setIndicatorStyle(WorkspaceIndicatorStyle indicatorStyle) {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(WorkspaceSettingsIntent.setIndicatorStyle(indicatorStyle));
  }

  void setClickable({required bool clickable}) {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(WorkspaceSettingsIntent.setClickable(clickable: clickable));
  }

  void setVisibleRange(WorkspaceVisibleRange visibleRange) {
    ref
        .read(rustCommandDispatcherProvider)
        .dispatch(WorkspaceSettingsIntent.setVisibleRange(visibleRange));
  }
}
