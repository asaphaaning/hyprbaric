// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workspace_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WorkspaceController)
final workspaceControllerProvider = WorkspaceControllerProvider._();

final class WorkspaceControllerProvider
    extends $NotifierProvider<WorkspaceController, void> {
  WorkspaceControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceControllerHash();

  @$internal
  @override
  WorkspaceController create() => WorkspaceController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$workspaceControllerHash() =>
    r'4d5977fd9654b3c91f5b2f06c31b77510fe3a387';

abstract class _$WorkspaceController extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
