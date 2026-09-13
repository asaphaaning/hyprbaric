import 'package:flutter/material.dart';

/// A stable identity and reusable content for a stacked banner.
@immutable
class HyprBanner {
  const HyprBanner({required this.id, required this.child});

  /// Identity retained while other banners arrive or leave.
  final Object id;

  /// The production notification/card content.
  final Widget child;
}

/// Presents newest-first banners three deep, translating and scaling each card.
/// Only the front card accepts input or participates in accessibility.
class HyprBannerStack extends StatelessWidget {
  const HyprBannerStack({
    super.key,
    required this.banners,
    this.duration = const Duration(milliseconds: 220),
    this.itemExtent = 64,
  });

  /// Newest first. At most three entries are rendered; identities must be unique.
  final List<HyprBanner> banners;

  /// Retargetable movement time when a banner's depth changes.
  final Duration duration;

  /// Height reserved for each complete banner.
  final double itemExtent;

  @override
  Widget build(BuildContext context) {
    final time = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : duration;
    final visible = banners.take(3).toList(growable: false);
    return SizedBox(
      height: itemExtent + 28,
      child: Stack(
        key: ValueKey(MediaQuery.disableAnimationsOf(context)),
        children: [
          for (var depth = visible.length - 1; depth >= 0; depth--)
            AnimatedPositioned(
              key: ValueKey(visible[depth].id),
              duration: time,
              curve: Curves.easeOutCubic,
              top: depth * 12,
              left: depth * 12,
              right: depth * 12,
              height: itemExtent,
              child: IgnorePointer(
                ignoring: depth != 0,
                child: ExcludeSemantics(
                  excluding: depth != 0,
                  child: AnimatedOpacity(
                    duration: time,
                    opacity: 1 - depth * .22,
                    child: TweenAnimationBuilder<double>(
                      duration: time,
                      curve: Curves.easeOutCubic,
                      tween: Tween(begin: 0, end: 1),
                      builder: (context, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, -16 * (1 - value)),
                          child: Transform.scale(
                            scale: .96 + .04 * value,
                            child: child,
                          ),
                        ),
                      ),
                      child: visible[depth].child,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
