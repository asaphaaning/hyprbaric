import 'package:flutter/widgets.dart';

import '../audio/preview_registry.dart';

/// Fits a complete production preview into its landing-page host element.
class PreviewViewport extends StatelessWidget {
  const PreviewViewport({super.key, required this.preview});

  /// The panel rendered at its canonical layout width before scaling.
  final LandingPreview preview;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: preview.width,
          child: RepaintBoundary(child: preview.build()),
        ),
      ),
    );
  }
}
