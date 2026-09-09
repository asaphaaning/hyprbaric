import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bindings/bindings.dart';
import '../features/global_menu/global_menu_bar.dart';
import '../layer_shell_controller.dart';
import '../state/monitor_workspace.dart';
import '../state/providers.dart';
import 'hypr_surface.dart';
import 'primitives/primitives.dart';
import 'workspace_strip.dart';

class LeftCluster extends ConsumerWidget {
  const LeftCluster({
    super.key,
    required this.appLauncherOpen,
    required this.onToggleAppLauncher,
    this.showGlobalMenu = false,
    this.logoKey,
  });

  final bool appLauncherOpen;
  final VoidCallback onToggleAppLauncher;
  final bool showGlobalMenu;
  final GlobalKey? logoKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<WorkspaceStatus> workspaceStatus = ref.watch(
      currentWorkspaceStatusProvider,
    );
    final WorkspaceSettingsStatus workspaceSettings = ref.watch(
      currentWorkspaceSettingsProvider,
    );
    final LayerShellMonitor? output = ref
        .watch(layerShellCurrentMonitorProvider)
        .asData
        ?.value;
    final Widget workspaceWidget = workspaceStatus.when(
      data: (WorkspaceStatus status) {
        final MonitorWorkspaceResolution resolution = resolveMonitorWorkspace(
          status,
          output,
        );
        return WorkspaceStrip(
          status: status,
          resolution: resolution,
          settings: workspaceSettings,
          onPrevious: () => ref
              .read(workspaceControllerProvider.notifier)
              .previous(resolution.monitorName),
          onNext: () => ref
              .read(workspaceControllerProvider.notifier)
              .next(resolution.monitorName),
          onSelect: (int target) => ref
              .read(workspaceControllerProvider.notifier)
              .select(target, resolution.monitorName),
        );
      },
      loading: () => const WorkspaceStripPlaceholder(label: '…'),
      error: (_, _) => const WorkspaceStripPlaceholder(label: '!'),
    );

    // The launcher and workspaces scale down to fit; the menu does not.
    // Shrinking menu text to buy room would make it the least legible thing on
    // the bar, so it scrolls within whatever space is left instead.
    final Widget launcherAndWorkspaces = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _HyprbaricLogoButton(
            key: logoKey,
            active: appLauncherOpen,
            onPressed: onToggleAppLauncher,
          ),
          const HyprDivider(
            height: 16,
            margin: EdgeInsets.symmetric(horizontal: 8),
          ),
          workspaceWidget,
        ],
      ),
    );

    if (!showGlobalMenu) {
      return Align(
        alignment: Alignment.centerLeft,
        child: launcherAndWorkspaces,
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // A row hands its non-flexible children unbounded width, which
              // would stop the box above ever scaling down and overflow the
              // bar instead. The cap is what it would have had on its own.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: launcherAndWorkspaces,
              ),
              const Flexible(child: GlobalMenuBar()),
            ],
          );
        },
      ),
    );
  }
}

class _HyprbaricLogoButton extends StatelessWidget {
  const _HyprbaricLogoButton({
    super.key,
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      semanticLabel: 'Open app launcher',
      onPressed: onPressed,
      builder: (BuildContext context, HyprInteractionState state) {
        final bool lit = active || state.active;
        return AnimatedScale(
          scale: state.pressed ? 0.96 : 1,
          duration: HyprMotion.hover,
          curve: HyprMotion.hoverCurve,
          child: AnimatedContainer(
            key: const ValueKey<String>('hyprbaric-logo-button'),
            duration: HyprMotion.hover,
            curve: HyprMotion.hoverCurve,
            width: 28,
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: ShapeDecoration(
              color: active
                  ? HyprColors.hoverStrong
                  : lit
                  ? HyprColors.hover
                  : Colors.transparent,
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.circular(7),
                side: BorderSide(
                  color: active
                      ? HyprColors.border
                      : lit
                      ? HyprColors.popupStroke
                      : Colors.transparent,
                  width: 1,
                ),
              ),
            ),
            child: IconTheme(
              data: IconThemeData(
                color: lit ? HyprColors.text : HyprColors.textMuted,
              ),
              child: const CustomPaint(painter: _HyprbaricLogoPainter()),
            ),
          ),
        );
      },
    );
  }
}

class _HyprbaricLogoPainter extends CustomPainter {
  const _HyprbaricLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = HyprColors.text.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final Paint fill = Paint()
      ..color = HyprColors.text.withValues(alpha: 0.20)
      ..style = PaintingStyle.fill;

    final RRect back = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.34, 0.5, 8, 8),
      const Radius.circular(1.5),
    );
    final RRect front = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, size.height * 0.34, 8, 8),
      const Radius.circular(1.5),
    );

    canvas.drawRRect(
      back,
      stroke..color = HyprColors.text.withValues(alpha: 0.45),
    );
    canvas.drawRRect(front, fill);
    canvas.drawRRect(
      front,
      stroke..color = HyprColors.text.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(covariant _HyprbaricLogoPainter oldDelegate) => false;
}
