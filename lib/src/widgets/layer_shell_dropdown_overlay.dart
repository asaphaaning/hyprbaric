import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/hypr_motion.dart';
import 'layer_shell_dropdown_model.dart';

class AnchoredMenuOverlay extends AnimatedWidget {
  const AnchoredMenuOverlay({
    super.key,
    required this.buttonKey,
    required this.overlayState,
    required this.anchor,
    required this.animation,
    required this.animationCurve,
    required this.transition,
    required this.transitionAlignment,
    this.menuKey,
    required this.menuWidth,
    required this.barHeight,
    required this.verticalGap,
    required this.child,
  }) : super(listenable: animation);

  final GlobalKey buttonKey;
  final OverlayState overlayState;
  final LayerShellDropdownAnchor anchor;
  final Animation<double> animation;
  final Curve animationCurve;
  final LayerShellDropdownTransition transition;
  final Alignment transitionAlignment;
  final GlobalKey? menuKey;
  final double menuWidth;
  final double barHeight;
  final double verticalGap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final RenderBox? buttonBox =
        buttonKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? overlayBox =
        overlayState.context.findRenderObject() as RenderBox?;
    if (buttonBox == null || overlayBox == null) {
      return const SizedBox.shrink();
    }

    final Offset buttonTopLeft = buttonBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final Rect buttonRect = buttonTopLeft & buttonBox.size;
    final double desiredLeft = switch (anchor) {
      LayerShellDropdownAnchor.left => buttonRect.left,
      LayerShellDropdownAnchor.center => buttonRect.center.dx - (menuWidth / 2),
      LayerShellDropdownAnchor.right => buttonRect.right - menuWidth,
    };
    final double left = desiredLeft.clamp(
      0.0,
      math.max(0.0, overlayBox.size.width - menuWidth),
    );
    return Positioned(
      left: left,
      top: math.max(buttonRect.bottom, barHeight) + verticalGap,
      width: menuWidth,
      child: SizedBox(
        key: menuKey,
        width: menuWidth,
        child: DropdownTransition(
          animation: animation,
          animationCurve: animationCurve,
          transition: transition,
          transitionAlignment: transitionAlignment,
          child: child,
        ),
      ),
    );
  }
}

class DropdownTransition extends AnimatedWidget {
  const DropdownTransition({
    super.key,
    required this.animation,
    required this.animationCurve,
    required this.transition,
    required this.transitionAlignment,
    required this.child,
    this.revealAlignment = Alignment.topCenter,
  }) : super(listenable: animation);

  final Animation<double> animation;
  final Curve animationCurve;
  final LayerShellDropdownTransition transition;
  final Alignment transitionAlignment;

  /// Which edge the revealed menu sits against inside its box.
  ///
  /// A menu that declares no width is given the whole overlay to sit in, so
  /// this decides where in that space it lands. Centring a menu whose anchor
  /// is an edge puts it somewhere its owner then has to correct it away from,
  /// and makes it slide whenever its width changes.
  final Alignment revealAlignment;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double rawProgress = animation.value.clamp(0.0, 1.0);
    return switch (transition) {
      LayerShellDropdownTransition.reveal => _buildReveal(rawProgress),
      LayerShellDropdownTransition.grow => _buildGrow(rawProgress),
    };
  }

  Widget _buildReveal(double rawProgress) {
    final double progress = animationCurve.transform(rawProgress);
    final double heightFactor = progress <= 0.0 ? 0.0001 : progress;
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: ClipRect(
        child: Align(
          alignment: revealAlignment,
          heightFactor: heightFactor,
          child: child,
        ),
      ),
    );
  }

  Widget _buildGrow(double rawProgress) {
    final double transformProgress = HyprMotion.growPopupTransformCurve
        .transform(rawProgress)
        .clamp(0.0, 1.0);
    final double opacityProgress = HyprMotion.growPopupOpacityCurve
        .transform(rawProgress)
        .clamp(0.0, 1.0);
    final double blurProgress = HyprMotion.growPopupBlurCurve
        .transform(rawProgress)
        .clamp(0.0, 1.0);
    final double factor =
        HyprMotion.growPopupHiddenScale +
        ((1 - HyprMotion.growPopupHiddenScale) * transformProgress);
    final double offsetY =
        HyprMotion.growPopupHiddenOffsetY * (1 - transformProgress);
    final double blur = HyprMotion.growPopupHiddenBlur * (1 - blurProgress);
    final Widget visualChild = blur > 0.01
        ? ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: child,
          )
        : child;

    return Opacity(
      opacity: opacityProgress,
      child: ClipRect(
        child: Align(
          alignment: transitionAlignment,
          widthFactor: factor,
          heightFactor: factor,
          child: Transform.translate(
            offset: Offset(0, offsetY),
            transformHitTests: false,
            child: Transform.scale(
              alignment: transitionAlignment,
              scale: factor,
              transformHitTests: false,
              child: visualChild,
            ),
          ),
        ),
      ),
    );
  }
}
