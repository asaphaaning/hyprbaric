import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'session_controller.dart';

class SessionLauncherCard extends StatelessWidget {
  const SessionLauncherCard({
    super.key,
    required this.borderRadius,
    required this.actions,
    required this.selectedAction,
    required this.confirmingAction,
    required this.confirmChoice,
    required this.errorMessage,
    required this.onActionTap,
    required this.onCancel,
    required this.onConfirm,
  });

  final BorderRadius borderRadius;
  final List<SessionAction> actions;
  final SessionAction? selectedAction;
  final SessionAction? confirmingAction;
  final SessionConfirmChoice confirmChoice;
  final String? errorMessage;
  final void Function(SessionAction action) onActionTap;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return HyprPopoverSurface(
      borderRadius: borderRadius,
      borderColor: HyprColors.popupStroke,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 240, maxWidth: 240),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: AnimatedSwitcher(
            duration: HyprMotion.switcher,
            switchInCurve: HyprMotion.switchInCurve,
            switchOutCurve: HyprMotion.switchOutCurve,
            child: confirmingAction == null
                ? SessionLauncherActions(
                    key: const ValueKey<String>('session-launcher-actions'),
                    actions: actions,
                    selectedAction: selectedAction,
                    errorMessage: errorMessage,
                    onActionTap: onActionTap,
                  )
                : SessionLauncherConfirm(
                    key: ValueKey<String>(
                      'session-confirm-${confirmingAction!.name}',
                    ),
                    action: confirmingAction!,
                    confirmChoice: confirmChoice,
                    errorMessage: errorMessage,
                    onCancel: onCancel,
                    onConfirm: onConfirm,
                  ),
          ),
        ),
      ),
    );
  }
}

class SessionLauncherActions extends StatelessWidget {
  const SessionLauncherActions({
    super.key,
    required this.actions,
    required this.selectedAction,
    required this.errorMessage,
    required this.onActionTap,
  });

  final List<SessionAction> actions;
  final SessionAction? selectedAction;
  final String? errorMessage;
  final void Function(SessionAction action) onActionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SessionPopoverTitle(label: 'Session'),
        const SizedBox(height: 10),
        for (final SessionAction action in actions)
          SessionPowerRow(
            action: action,
            selected: action == selectedAction,
            onTap: () => onActionTap(action),
          ),
        if (errorMessage != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            errorMessage!,
            style: HyprTypography.popRow.copyWith(
              color: HyprColors.danger,
              fontSize: HyprTypography.size(12),
            ),
          ),
        ],
      ],
    );
  }
}

class SessionLauncherConfirm extends StatelessWidget {
  const SessionLauncherConfirm({
    super.key,
    required this.action,
    required this.confirmChoice,
    required this.errorMessage,
    required this.onCancel,
    required this.onConfirm,
  });

  final SessionAction action;
  final SessionConfirmChoice confirmChoice;
  final String? errorMessage;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SessionPopoverTitle(label: 'Confirm'),
        const SizedBox(height: 10),
        SessionPowerRow(action: action, selected: true, onTap: onConfirm),
        const SizedBox(height: 10),
        Text(
          action.confirmationPrompt,
          style: HyprTypography.popRow.copyWith(
            color: SessionMenuColors.fg2,
            height: 1.25,
          ),
        ),
        if (errorMessage != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            errorMessage!,
            style: HyprTypography.popRow.copyWith(
              color: HyprColors.danger,
              fontSize: HyprTypography.size(12),
            ),
          ),
        ],
        const SizedBox(height: 12),
        const SessionDivider(),
        const SizedBox(height: 10),
        OverflowBar(
          alignment: MainAxisAlignment.end,
          spacing: 8,
          overflowSpacing: 8,
          children: <Widget>[
            SessionConfirmButton(
              onPressed: onCancel,
              label: 'Cancel',
              selected: confirmChoice == SessionConfirmChoice.cancel,
            ),
            SessionConfirmButton(
              onPressed: onConfirm,
              label: 'Confirm ${action.label}',
              danger: true,
              selected: confirmChoice == SessionConfirmChoice.confirm,
            ),
          ],
        ),
      ],
    );
  }
}

abstract final class SessionMenuColors {
  static const Color fg0 = Color(0xF7F0F4F8);
  static const Color fg1 = Color(0xECCBD2DA);
  static const Color fg2 = Color(0xC8BEC7D0);
  static const Color fg3 = Color(0xA0929DA8);
  static const Color hover = HyprColors.hover;
  static const Color selected = HyprColors.hoverStrong;
  static const Color dangerHover = HyprColors.dangerHoverSoft;
  static const Color dangerFill = Color(0x1FE16658);
  static const Color dangerActionHover = HyprColors.dangerHover;
  static const Color dangerText = Color(0xFFFF8D82);
  static const Color iconFill = Color(0x0DFFFFFF);
}

class SessionPopoverTitle extends StatelessWidget {
  const SessionPopoverTitle({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return HyprPanelHeader(
      title: label,
      uppercaseTitle: true,
      titleStyle: HyprTypography.popTitle.copyWith(
        color: SessionMenuColors.fg3,
        letterSpacing: 0,
      ),
    );
  }
}

class SessionPowerRow extends StatelessWidget {
  const SessionPowerRow({
    super.key,
    required this.action,
    required this.selected,
    required this.onTap,
  });

  final SessionAction action;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool danger = action.isDanger;
    final String? detail = action.detailLabel;

    return Padding(
      padding: EdgeInsets.zero,
      child: HyprInteractionRegion(
        onPressed: onTap,
        builder: (BuildContext context, HyprInteractionState state) {
          final Color fill = selected
              ? danger
                    ? SessionMenuColors.dangerHover
                    : SessionMenuColors.selected
              : state.hovered
              ? danger
                    ? SessionMenuColors.dangerHover
                    : SessionMenuColors.hover
              : Colors.transparent;
          return Material(
            color: fill,
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              key: ValueKey<String>('session-action-${action.name}'),
              padding: const EdgeInsets.all(10),
              child: Row(
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: danger
                          ? SessionMenuColors.dangerFill
                          : SessionMenuColors.iconFill,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: SizedBox.square(
                      dimension: 28,
                      child: Icon(
                        action.icon,
                        color: danger
                            ? SessionMenuColors.dangerText
                            : SessionMenuColors.fg1,
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          action.label,
                          style: HyprTypography.popRow.copyWith(
                            color: SessionMenuColors.fg0,
                          ),
                        ),
                        if (detail != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            detail,
                            style: HyprTypography.popMeta.copyWith(
                              color: SessionMenuColors.fg3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SessionConfirmButton extends StatelessWidget {
  const SessionConfirmButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.danger = false,
    this.selected = false,
  });

  final VoidCallback onPressed;
  final String label;
  final bool danger;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color fill = selected
        ? danger
              ? SessionMenuColors.dangerActionHover
              : SessionMenuColors.hover
        : danger
        ? SessionMenuColors.dangerHover
        : Colors.transparent;
    final Color foreground = selected
        ? SessionMenuColors.fg0
        : danger
        ? SessionMenuColors.fg0
        : SessionMenuColors.fg2;

    return HyprCommandButton(
      onPressed: onPressed,
      label: label,
      variant: danger
          ? HyprCommandButtonVariant.danger
          : HyprCommandButtonVariant.quiet,
      color: fill,
      hoverColor: danger
          ? SessionMenuColors.dangerActionHover
          : SessionMenuColors.hover,
      foregroundColor: foreground,
      hoverForegroundColor: danger
          ? SessionMenuColors.fg0
          : SessionMenuColors.fg1,
      padding: const EdgeInsets.all(10),
      constraints: const BoxConstraints(minHeight: 36),
      textStyle: HyprTypography.popRow,
    );
  }
}

class SessionDivider extends StatelessWidget {
  const SessionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0x00FFFFFF),
              HyprColors.borderSoft,
              Color(0x00FFFFFF),
            ],
          ),
        ),
      ),
    );
  }
}

extension SessionActionIconView on SessionAction {
  IconData get icon => switch (this) {
    SessionAction.lock => Icons.lock_rounded,
    SessionAction.suspend => Icons.bedtime_rounded,
    SessionAction.logout => Icons.logout_rounded,
    SessionAction.restart => Icons.restart_alt_rounded,
    SessionAction.shutdown => Icons.power_settings_new_rounded,
    SessionAction.rebootToFirmware => Icons.developer_board_rounded,
  };
}
