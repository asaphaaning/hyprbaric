import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/layer_shell_hit_region.dart';

void main() {
  test(
    'non-Linux hosts observe menu geometry and preserve owner isolation',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final manager = LayerShellRegionManager(barHeight: 40);
      addTearDown(manager.dispose);
      final owner = Object();
      final reports = <LayerShellMenuRegion?>[];
      manager.menuRegion.addListener(
        () => reports.add(manager.menuRegion.value),
      );

      const rect = Rect.fromLTWH(100, 48, 280, 320);
      await manager.updateRegion(menuRect: rect, owner: owner);
      await manager.updateRegion(menuRect: rect, owner: owner);
      expect(reports, hasLength(1));
      expect(reports.single?.rect, rect);

      await manager.updateRegion(menuRect: null, owner: Object());
      expect(manager.menuRegion.value?.rect, rect);
      await manager.updateRegion(menuRect: null, owner: owner);
      expect(reports, hasLength(2));
      expect(reports.last, isNull);
    },
  );
}
