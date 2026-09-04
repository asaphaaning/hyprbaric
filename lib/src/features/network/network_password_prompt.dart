import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../widgets/hypr_surface.dart';
import '../../widgets/primitives/primitives.dart';
import 'network_chrome.dart';

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
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: DecoratedBox(
            decoration: const ShapeDecoration(
              color: Color(0x99010204),
              shape: RoundedSuperellipseBorder(
                borderRadius: BorderRadius.all(Radius.circular(9)),
                side: BorderSide(color: Color(0x14FFFFFF)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _NetworkPasswordTitle(ssid: ssid, connecting: connecting),
                  const SizedBox(height: 10),
                  if (connecting)
                    Row(
                      children: <Widget>[
                        const SizedBox.square(
                          dimension: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Joining $ssid...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: HyprTypography.popRow.copyWith(
                              color: NetworkMenuColors.fg2,
                              fontSize: HyprTypography.size(11.5),
                            ),
                          ),
                        ),
                      ],
                    )
                  else ...<Widget>[
                    _NetworkPasswordInputRow(
                      controller: controller,
                      focusNode: focusNode,
                      showPassword: showPassword,
                      onSubmit: onSubmit,
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: controller,
                      builder:
                          (
                            BuildContext context,
                            TextEditingValue value,
                            Widget? child,
                          ) {
                            return _NetworkPasswordStrengthRow(
                              password: value.text,
                              showPassword: showPassword,
                              onToggleVisibility: onToggleVisibility,
                              onCancel: onCancel,
                            );
                          },
                    ),
                  ],
                  if (errorMessage != null) ...<Widget>[
                    const SizedBox(height: 7),
                    Text(
                      errorMessage!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: HyprTypography.popMeta.copyWith(
                        color: HyprColors.danger,
                        fontSize: HyprTypography.size(11),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NetworkPasswordTitle extends StatelessWidget {
  const _NetworkPasswordTitle({required this.ssid, required this.connecting});

  final String ssid;
  final bool connecting;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          connecting ? 'Joining ' : 'Join ',
          style: HyprTypography.popRowStrong.copyWith(
            color: NetworkMenuColors.fg2,
            fontSize: HyprTypography.size(12),
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
            height: 1,
          ),
        ),
        Flexible(
          child: Text(
            ssid,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: HyprTypography.popRowStrong.copyWith(
              color: NetworkMenuColors.fg1,
              fontSize: HyprTypography.size(12),
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _NetworkPasswordInputRow extends StatelessWidget {
  const _NetworkPasswordInputRow({
    required this.controller,
    required this.focusNode,
    required this.showPassword,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showPassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return HyprTextFieldChrome(
      focusNode: focusNode,
      color: Colors.black.withValues(alpha: 0.45),
      focusedColor: Colors.black.withValues(alpha: 0.60),
      borderColor: const Color(0x0FFFFFFF),
      // Focus swaps the border out for a two-step halo. CSS paints the first
      // shadow on top, Flutter paints the last, so the order is reversed:
      // the black 4px ring goes down first and the accent 3px ring over it.
      focusedBorderColor: Colors.transparent,
      focusedShadows: const <BoxShadow>[
        BoxShadow(color: Color(0x80000000), spreadRadius: 4),
        BoxShadow(color: Color(0xFF2F5168), spreadRadius: 3),
      ],
      borderRadius: BorderRadius.circular(8),
      padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              obscureText: !showPassword,
              onSubmitted: (_) => onSubmit(),
              style: HyprTypography.popRowStrong.copyWith(
                color: NetworkMenuColors.fg1,
                fontSize: HyprTypography.size(12),
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Enter password',
                hintStyle: HyprTypography.popRow.copyWith(
                  color: NetworkMenuColors.fg3,
                  fontSize: HyprTypography.size(12),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder:
                (BuildContext context, TextEditingValue value, Widget? child) {
                  return _NetworkConnectButton(
                    onPressed: onSubmit,
                    enabled: value.text.isNotEmpty,
                  );
                },
          ),
        ],
      ),
    );
  }
}

class _NetworkConnectButton extends StatelessWidget {
  const _NetworkConnectButton({required this.onPressed, required this.enabled});

  final VoidCallback onPressed;
  final bool enabled;

  /// The accent gradient in `.wifi-connect-btn` is overridden further down the
  /// reference stylesheet: the button ends up as a tone-on-tone raised face,
  /// shaped by light rather than colour, with a near-black glyph.
  static const List<Color> _face = <Color>[
    Color(0x572B2E34),
    Color(0x661D1F25),
  ];
  static const List<Color> _faceHover = <Color>[
    Color(0x703A3D44),
    Color(0x80282B31),
  ];
  static const List<Color> _facePressed = <Color>[
    Color(0x9E090B0F),
    Color(0xA80F1217),
  ];

  @override
  Widget build(BuildContext context) {
    return HyprInteractionRegion(
      key: const ValueKey<String>('network-connect-submit'),
      semanticLabel: 'Connect to network',
      onPressed: onPressed,
      builder: (BuildContext context, HyprInteractionState state) {
        final bool hovered = enabled && state.hovered && !state.pressed;
        final bool pressed = enabled && state.pressed;
        final List<Color> colors = pressed
            ? _facePressed
            : hovered
            ? _faceHover
            : _face;
        return AnimatedScale(
          scale: hovered ? 1.08 : 1,
          duration: const Duration(milliseconds: 100),
          curve: const Cubic(0.34, 1.6, 0.64, 1),
          child: AnimatedOpacity(
            opacity: enabled ? (hovered ? 0.85 : 1) : 0.3,
            duration: const Duration(milliseconds: 120),
            child: AnimatedContainer(
              duration: HyprMotion.hover,
              curve: HyprMotion.hoverCurve,
              transform: Matrix4.translationValues(0, pressed ? 0.5 : 0, 0),
              decoration: ShapeDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: colors,
                ),
                shape: const RoundedSuperellipseBorder(
                  borderRadius: BorderRadius.all(Radius.circular(7)),
                ),
                // `--st-cast`: the face sits on the panel, it does not glow.
                shadows: pressed
                    ? null
                    : const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x80000000),
                          offset: Offset(0, 1),
                        ),
                        BoxShadow(
                          color: Color(0x80000000),
                          blurRadius: 4,
                          spreadRadius: -2,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: ClipRSuperellipse(
                borderRadius: const BorderRadius.all(Radius.circular(7)),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    if (!pressed) ...<Widget>[
                      // `--st-lit` / `--st-dark`.
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: ColoredBox(
                          color: hovered
                              ? const Color(0x24FFFFFF)
                              : const Color(0x16FFFFFF),
                          child: const SizedBox(height: 1),
                        ),
                      ),
                      const Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: ColoredBox(
                          color: Color(0x73000000),
                          child: SizedBox(height: 1),
                        ),
                      ),
                    ] else
                      const Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0x8C000000),
                                Color(0x00000000),
                              ],
                              stops: <double>[0, 0.4],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox.square(
                      dimension: 32,
                      child: Icon(
                        Iconsax.arrow_right_1_copy,
                        color: Color(0xFF030303),
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NetworkPasswordStrengthRow extends StatelessWidget {
  const _NetworkPasswordStrengthRow({
    required this.password,
    required this.showPassword,
    required this.onToggleVisibility,
    required this.onCancel,
  });

  final String password;
  final bool showPassword;
  final VoidCallback onToggleVisibility;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final int strength = _passwordStrength(password);
    // The reference routes these through its meter ladder: green / yellow /
    // red, each with a matching glow.
    final Color color = switch (strength) {
      1 => const Color(0xFFF53E39),
      2 => const Color(0xFFFAD03E),
      3 => const Color(0xFF57CE70),
      _ => Colors.white.withValues(alpha: 0.08),
    };
    return Row(
      children: <Widget>[
        Row(
          children: <Widget>[
            for (int index = 0; index < 3; index += 1)
              Padding(
                padding: EdgeInsets.only(right: index == 2 ? 0 : 3),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: index < strength
                        ? color
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: index < strength
                        ? <BoxShadow>[
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                  child: const SizedBox(width: 18, height: 3),
                ),
              ),
          ],
        ),
        const Spacer(),
        _NetworkPasswordTextButton(
          label: showPassword ? 'Hide' : 'Show',
          onPressed: onToggleVisibility,
        ),
        const SizedBox(width: 10),
        _NetworkPasswordTextButton(label: 'Cancel', onPressed: onCancel),
      ],
    );
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
}

class _NetworkPasswordTextButton extends StatelessWidget {
  const _NetworkPasswordTextButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return HyprCommandButton(
      label: label,
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(vertical: 3),
      constraints: const BoxConstraints(minHeight: 18),
      foregroundColor: NetworkMenuColors.fg3,
      hoverForegroundColor: NetworkMenuColors.fg1,
      hoverColor: Colors.transparent,
      textStyle: HyprTypography.popRowStrong.copyWith(
        fontSize: HyprTypography.size(11.5),
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      maxLines: 1,
    );
  }
}
