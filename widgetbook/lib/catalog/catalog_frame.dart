import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';

class CatalogFrame extends StatelessWidget {
  const CatalogFrame({
    super.key,
    required this.child,
    this.width,
    this.padding = const EdgeInsets.all(32),
  });

  final Widget child;
  final double? width;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: width ?? 520),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: HyprColors.surfaceStrong,
                border: Border.all(color: HyprColors.border),
                borderRadius: HyprRadii.panelRadius,
              ),
              child: Padding(
                padding: const EdgeInsets.all(HyprSpacing.loose),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
