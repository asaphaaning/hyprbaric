import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'network_chrome.dart';

/// The attached continuation shown beneath a selected secured Wi-Fi entry.
///
/// The entry and this drawer intentionally share [NetworkWifiColors.expanded]
/// so selecting a network reads as one continuous surface rather than a row
/// opening a second popover.
class NetworkPasswordPrompt extends StatelessWidget {
  const NetworkPasswordPrompt({
    super.key,
    required this.ssid,
    required this.controller,
    required this.focusNode,
    required this.showPassword,
    required this.connecting,
    required this.errorMessage,
    required this.onToggleVisibility,
    required this.onCancel,
    required this.onSubmit,
  });

  final String ssid;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showPassword;
  final bool connecting;
  final String? errorMessage;
  final VoidCallback onToggleVisibility;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    // A sibling panel below the row, not a container nested inside it.
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: DecoratedBox(
        // `::before` draws a 1px accent hairline that fades out halfway
        // across the panel; the gradient layer supplies it and the inner
        // fill masks everything but the edge.
        decoration: ShapeDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              context.hyprPalette.accent.withValues(alpha: 0.11),
              Colors.transparent,
            ],
            stops: const <double>[0, 0.5],
          ),
          shape: const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ),
        shadows: <BoxShadow>[
          BoxShadow(
            color: NetworkWifiColors.cast,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
          BoxShadow(
            color: NetworkWifiColors.castStrong,
            blurRadius: 7,
            offset: Offset(0, 3),
            spreadRadius: -3,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: AnimatedSize(
          duration: HyprMotion.popup,
          curve: HyprMotion.popupCurve,
          alignment: Alignment.topCenter,
          child: connecting
              ? _NetworkConnectingStatus(ssid: ssid)
              : _NetworkPasswordForm(
                  ssid: ssid,
                  controller: controller,
                  focusNode: focusNode,
                  showPassword: showPassword,
                  errorMessage: errorMessage,
                  onToggleVisibility: onToggleVisibility,
                  onCancel: onCancel,
                  onSubmit: onSubmit,
                ),
        ),
      ),
    );
  }
}

class _NetworkConnectingStatus extends StatelessWidget {
  const _NetworkConnectingStatus({required this.ssid});

  final String ssid;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const HyprSpinner.inline(),
        const SizedBox(width: 8),
        // Two tones: the verb stays quiet so the network name carries the row.
        Expanded(
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(text: 'Joining '),
                TextSpan(
                  text: ssid,
                  style: const TextStyle(
                    color: NetworkMenuColors.fg1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: '\u2026'),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyprTypography.popRow.copyWith(
              color: NetworkMenuColors.fg2,
              fontSize: HyprTypography.size(11.5),
              letterSpacing: 0,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _NetworkPasswordForm extends StatelessWidget {
  const _NetworkPasswordForm({
    required this.ssid,
    required this.controller,
    required this.focusNode,
    required this.showPassword,
    required this.errorMessage,
    required this.onToggleVisibility,
    required this.onCancel,
    required this.onSubmit,
  });

  final String ssid;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showPassword;
  final String? errorMessage;
  final VoidCallback onToggleVisibility;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _NetworkPasswordSlot(
          ssid: ssid,
          controller: controller,
          focusNode: focusNode,
          showPassword: showPassword,
          onToggleVisibility: onToggleVisibility,
          onSubmit: onSubmit,
        ),
        const SizedBox(height: 9),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder:
              (BuildContext context, TextEditingValue value, Widget? child) {
                return _NetworkPasswordActions(
                  password: value.text,
                  onCancel: onCancel,
                  onSubmit: onSubmit,
                );
              },
        ),
        if (errorMessage case final String message) ...<Widget>[
          const SizedBox(height: 7),
          Text(
            message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: HyprTypography.popMeta.copyWith(
              color: HyprColors.danger,
              fontSize: HyprTypography.size(10),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _NetworkPasswordSlot extends StatelessWidget {
  const _NetworkPasswordSlot({
    required this.ssid,
    required this.controller,
    required this.focusNode,
    required this.showPassword,
    required this.onToggleVisibility,
    required this.onSubmit,
  });

  final String ssid;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showPassword;
  final VoidCallback onToggleVisibility;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return HyprTextFieldChrome(
      focusNode: focusNode,
      color: NetworkWifiColors.well,
      focusedColor: NetworkWifiColors.wellFocused,
      borderColor: Colors.transparent,
      focusedBorderColor: NetworkWifiColors.focus,
      focusedShadows: const <BoxShadow>[
        BoxShadow(color: Color(0x80000000), spreadRadius: 4),
        BoxShadow(color: NetworkWifiColors.focus, spreadRadius: 3),
      ],
      borderRadius: BorderRadius.circular(9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      shadows: const <BoxShadow>[
        BoxShadow(color: Color(0x70000000), offset: Offset(0, 1)),
        BoxShadow(color: Color(0x0FFFFFFF), offset: Offset(0, -1)),
      ],
      child: Row(
        children: <Widget>[
          Icon(
            Icons.lock_outline_rounded,
            size: 13,
            color: NetworkMenuColors.fg3.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: !showPassword,
              onSubmitted: (String value) {
                if (value.isNotEmpty) {
                  onSubmit();
                }
              },
              style: HyprTypography.popRowStrong.copyWith(
                color: NetworkMenuColors.fg1,
                fontSize: HyprTypography.size(12),
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Password for $ssid',
                hintStyle: HyprTypography.popRow.copyWith(
                  color: NetworkMenuColors.fg3.withValues(alpha: 0.62),
                  fontSize: HyprTypography.size(12),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 9),
          _NetworkPasswordVisibilityButton(
            shown: showPassword,
            onPressed: onToggleVisibility,
          ),
          const SizedBox(width: 9),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder:
                (BuildContext context, TextEditingValue value, Widget? child) {
                  return _NetworkPasswordStrengthTicks(password: value.text);
                },
          ),
        ],
      ),
    );
  }
}

class _NetworkPasswordVisibilityButton extends StatelessWidget {
  const _NetworkPasswordVisibilityButton({
    required this.shown,
    required this.onPressed,
  });

  final bool shown;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      semanticLabel: shown ? 'Hide password' : 'Show password',
      onPressed: onPressed,
      behavior: HitTestBehavior.deferToChild,
      builder: (BuildContext context, HyprInteractionState state) {
        return AnimatedDefaultTextStyle(
          duration: HyprMotion.hover,
          curve: HyprMotion.hoverCurve,
          style: HyprTypography.compactMonoStrong.copyWith(
            color: state.hovered
                ? NetworkMenuColors.fg1
                : NetworkMenuColors.fg3,
            fontSize: HyprTypography.size(10.5),
            letterSpacing: 0.63,
            height: 1,
          ),
          child: Text(shown ? 'Hide' : 'Show'),
        );
      },
    );
  }
}

class _NetworkPasswordStrengthTicks extends StatelessWidget {
  const _NetworkPasswordStrengthTicks({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final int strength = _passwordStrength(password);
    final Color color = switch (strength) {
      1 => const Color(0xFFF15B56),
      2 => const Color(0xFFF1C55B),
      3 => const Color(0xFF5DD98A),
      _ => NetworkMenuColors.fg3.withValues(alpha: 0.28),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int index = 0; index < 3; index += 1)
          Padding(
            padding: EdgeInsets.only(right: index == 2 ? 0 : 3),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: index < strength
                    ? color
                    : NetworkMenuColors.fg3.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(1),
                boxShadow: index < strength
                    ? <BoxShadow>[
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 3,
                        ),
                      ]
                    : null,
              ),
              child: const SizedBox(width: 3, height: 9),
            ),
          ),
      ],
    );
  }
}

class _NetworkPasswordActions extends StatelessWidget {
  const _NetworkPasswordActions({
    required this.password,
    required this.onCancel,
    required this.onSubmit,
  });

  final String password;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _NetworkPasswordAction(label: 'Cancel', onPressed: onCancel),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _NetworkPasswordAction(
            key: const ValueKey<String>('network-connect-submit'),
            label: 'Join',
            onPressed: onSubmit,
            enabled: password.isNotEmpty,
            emphasized: true,
          ),
        ),
      ],
    );
  }
}

class _NetworkPasswordAction extends StatelessWidget {
  const _NetworkPasswordAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return HyprCommandButton(
      label: label,
      onPressed: onPressed,
      enabled: enabled,
      borderRadius: HyprRadii.panelRadius,
      padding: const EdgeInsets.symmetric(vertical: 9),
      constraints: const BoxConstraints(),
      maxLines: 1,
      disabledOpacity: 0.3,
      color: emphasized
          ? NetworkWifiColors.actionEmphasized
          : NetworkWifiColors.well,
      hoverColor: NetworkWifiColors.actionHovered,
      pressedColor: NetworkWifiColors.actionPressed,
      foregroundColor: NetworkMenuColors.fg2,
      hoverForegroundColor: NetworkMenuColors.fg2,
      // The raised edge drops away on press, which is the whole affordance.
      shadowsBuilder: (HyprInteractiveTileState state) => state.pressed
          ? const <BoxShadow>[]
          : const <BoxShadow>[
              BoxShadow(color: Color(0x70000000), offset: Offset(0, 1)),
              BoxShadow(color: Color(0x0FFFFFFF), offset: Offset(0, -1)),
            ],
      pressedScale: 1,
      textStyle: HyprTypography.popRowStrong.copyWith(
        fontSize: HyprTypography.size(11.5),
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1,
      ),
    );
  }
}

int _passwordStrength(String password) {
  if (password.isEmpty) {
    return 0;
  }
  if (password.length < 6) {
    return 1;
  }
  if (password.length < 10) {
    return 2;
  }
  return 3;
}
