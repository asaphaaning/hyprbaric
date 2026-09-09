import 'dart:ui';

import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import 'setup_guide_state.dart';
import 'setup_guide_style.dart';

/// The image-backed live stage shown in the left half of the v6 guide.
class SetupGuidePreview extends StatelessWidget {
  const SetupGuidePreview({
    super.key,
    required this.step,
    required this.appearance,
    required this.workspaces,
  });

  final SetupStep step;
  final AppearanceStatus appearance;
  final WorkspaceSettingsStatus workspaces;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: SetupGuideColors.stageBase,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(setupGuideWallpaper, fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
              child: const ColoredBox(color: Color(0x79000000)),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-.65, -1.15),
                  radius: 1.25,
                  colors: <Color>[Color(0x1FFFFFFF), Colors.transparent],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(26, 26, 56, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 11),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: _stage(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _stage(BuildContext context) => switch (step) {
    SetupStep.welcome => <Widget>[
      _MiniDesktop(appearance: appearance),
      const SizedBox(height: 14),
      _WorkspaceModule(style: workspaces.indicatorStyle),
    ],
    SetupStep.transparency => <Widget>[
      _MiniDesktop(appearance: appearance),
      const SizedBox(height: 14),
      _OpacityModule(opacity: appearance.opacity),
    ],
    SetupStep.accent => <Widget>[
      _MiniDesktop(appearance: appearance),
      const SizedBox(height: 14),
      _AccentModule(hue: appearance.accentHue),
    ],
    SetupStep.globalMenu => <Widget>[
      _MiniDesktop(appearance: appearance),
      const SizedBox(height: 14),
      _WorkspaceModule(
        style: workspaces.indicatorStyle,
        label: 'MENUS',
        value: 'FILE  EDIT  VIEW',
      ),
    ],
    SetupStep.layout => <Widget>[
      _MiniDesktop(appearance: appearance, height: 148),
      const SizedBox(height: 14),
      _WorkspaceModule(
        style: workspaces.indicatorStyle,
        label: 'INDICATORS',
        value: workspaces.indicatorStyle == WorkspaceIndicatorStyle.roman
            ? 'ROMAN'
            : 'NUMERIC',
      ),
    ],
  };
}

class _MiniDesktop extends StatelessWidget {
  const _MiniDesktop({required this.appearance, this.height = 118});

  final AppearanceStatus appearance;
  final double height;

  @override
  Widget build(BuildContext context) {
    final bool bottom = appearance.position == AppearancePosition.bottom;
    final bool frosted = appearance.opacity < 100;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0x12FFFFFF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 6,
            offset: Offset(0, 2),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Image.asset(setupGuideWallpaper, fit: BoxFit.cover),
            Positioned(
              left: 16,
              top: bottom ? 18 : 34,
              child: Container(
                width: 116,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0x9E171922),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0x10FFFFFF)),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x99000000),
                      blurRadius: 14,
                      spreadRadius: -5,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: bottom ? Alignment.bottomCenter : Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.all(9),
                child: _MiniBar(opacity: appearance.opacity, frosted: frosted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.opacity, required this.frosted});

  final int opacity;
  final bool frosted;

  @override
  Widget build(BuildContext context) {
    final double alpha = frosted ? .10 + (opacity / 100) * .40 : 1;
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: frosted
            ? const Color(0xFF22252D).withValues(alpha: alpha)
            : const Color(0xFF25272E),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0x18FFFFFF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 12,
            spreadRadius: -5,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x17FFFFFF),
            offset: Offset(0, 1),
            blurStyle: BlurStyle.inner,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 13,
            height: 4,
            decoration: BoxDecoration(
              color: context.setupGuideAccent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 5),
          for (int index = 0; index < 4; index++) ...<Widget>[
            CircleAvatar(
              radius: 2,
              backgroundColor: index == 0 || index == 2
                  ? context.setupGuideAccentSoft.withValues(alpha: .72)
                  : const Color(0x667F8188),
            ),
            const SizedBox(width: 4),
          ],
          Container(
            width: 26,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0x2AFFFFFF),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 14,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0x2AFFFFFF),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const Spacer(),
          Container(
            width: 30,
            height: 9,
            decoration: BoxDecoration(
              color: const Color(0x4DFFFFFF),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceModule extends StatelessWidget {
  const _WorkspaceModule({
    required this.style,
    this.label = 'WORKSPACES',
    this.value = '5',
  });

  final WorkspaceIndicatorStyle style;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return _PreviewModule(
      label: label,
      value: value,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: _WorkspaceStrip(style: style),
      ),
    );
  }
}

class _OpacityModule extends StatelessWidget {
  const _OpacityModule({required this.opacity});

  final int opacity;

  @override
  Widget build(BuildContext context) {
    return _PreviewModule(
      label: 'OPACITY',
      value: opacity < 100 ? '$opacity%' : 'OFF',
      child: Container(
        height: 5,
        margin: const EdgeInsets.only(top: 9),
        decoration: setupWell(radius: 3),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: opacity < 100 ? opacity / 100 : 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  context.setupGuideAccent.withValues(alpha: .82),
                  context.setupGuideAccentSoft,
                ],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccentModule extends StatelessWidget {
  const _AccentModule({required this.hue});

  final int hue;

  static const List<double> _bars = <double>[
    .34,
    .62,
    .48,
    .86,
    .55,
    .72,
    .4,
    .66,
  ];

  @override
  Widget build(BuildContext context) {
    return _PreviewModule(
      label: 'METERS',
      value: '$hue°',
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 34,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _bars
                  .map(
                    (double value) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          height: 34 * value,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                context.setupGuideAccentSoft,
                                context.setupGuideAccent.withValues(alpha: .72),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List<Widget>.generate(4, (int index) {
              final double lightness = .72 - index * .08;
              final Color color = HSLColor.fromAHSL(
                1,
                hue.toDouble(),
                .72,
                lightness,
              ).toColor();
              return Expanded(
                child: Container(
                  height: 22,
                  margin: EdgeInsets.only(right: index == 3 ? 0 : 7),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x29FFFFFF),
                        offset: Offset(0, 1),
                        blurStyle: BlurStyle.inner,
                      ),
                      BoxShadow(
                        color: Color(0x4D000000),
                        blurRadius: 4,
                        offset: Offset(0, -2),
                        blurStyle: BlurStyle.inner,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PreviewModule extends StatelessWidget {
  const _PreviewModule({
    required this.label,
    required this.value,
    required this.child,
  });

  final String label;
  final String value;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xAD35363F), Color(0xC12A2C34)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1AFFFFFF),
            offset: Offset(0, 1),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Color(0x66000000),
            offset: Offset(0, -1),
            blurStyle: BlurStyle.inner,
          ),
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 18,
            spreadRadius: -10,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(label, style: setupMono(size: 8.5, spacing: 1.35)),
              Text(value, style: setupMono(size: 8.5, spacing: 1.35)),
            ],
          ),
          child,
        ],
      ),
    );
  }
}

class _WorkspaceStrip extends StatelessWidget {
  const _WorkspaceStrip({required this.style});

  final WorkspaceIndicatorStyle style;

  @override
  Widget build(BuildContext context) {
    const List<String> roman = <String>['I', 'II', 'III', 'IV', 'V'];
    return Row(
      children: List<Widget>.generate(5, (int index) {
        final bool active = index == 0;
        final bool occupied = index == 1 || index == 3;
        return SizedBox(
          width: 31,
          height: 20,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (active)
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: context.setupGuideAccent.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: context.setupGuideAccentSoft.withValues(
                        alpha: .72,
                      ),
                    ),
                  ),
                ),
              Text(
                style == WorkspaceIndicatorStyle.roman
                    ? roman[index]
                    : '${index + 1}',
                style: SetupGuideTypography.glyph(active: active),
              ),
              if (occupied)
                Positioned(
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 1.5,
                    backgroundColor: context.setupGuideAccentSoft.withValues(
                      alpha: .75,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
