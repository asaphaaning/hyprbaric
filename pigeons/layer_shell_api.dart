import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'hyprbaric',
    dartOut: 'lib/src/native/layer_shell_api.g.dart',
    dartOptions: DartOptions(),
    gobjectHeaderOut: 'linux/runner/layer_shell_api.g.h',
    gobjectSourceOut: 'linux/runner/layer_shell_api.g.cc',
    gobjectOptions: GObjectOptions(),
  ),
)
enum NativeLayerShellLayer { background, bottom, top, overlay }

enum NativeLayerShellKeyboardMode { none, exclusive, onDemand }

enum NativeLayerShellBarEdge { top, bottom }

enum NativeLayerShellMonitorTargetKind { primary, all, named, hidden }

class NativeLayerShellMonitorTarget {
  NativeLayerShellMonitorTargetKind kind;
  String? name;
}

class NativeLayerShellMonitor {
  String name;
  String label;
  bool isPrimary;
  int x;
  int y;
  int width;
  int height;
  int refreshRateMillihertz;
}

class NativeLayerShellAnchors {
  bool? top;
  bool? bottom;
  bool? left;
  bool? right;
}

class NativeLayerShellMargins {
  int? top;
  int? bottom;
  int? left;
  int? right;
}

class NativeLayerShellSize {
  int? width;
  int? height;
}

class NativeLayerShellRegion {
  int x;
  int y;
  int width;
  int height;
  int radiusTopLeft;
  int radiusTopRight;
  int radiusBottomRight;
  int radiusBottomLeft;
}

class NativeLayerShellRegionRequest {
  int barHeight;
  NativeLayerShellBarEdge barEdge;
  NativeLayerShellRegion? menu;
  List<NativeLayerShellRegion> passiveRegions;
  bool captureAllClicks;
}

class NativeLayerShellPanelConfig {
  String appNamespace;
  NativeLayerShellLayer layer;
  NativeLayerShellAnchors anchors;
  NativeLayerShellMargins margins;
  NativeLayerShellSize size;
  int exclusiveZone;
  bool autoExclusiveZone;
  NativeLayerShellKeyboardMode keyboardMode;
  NativeLayerShellMonitorTarget monitor;
}

@HostApi()
abstract class NativeLayerShellHostApi {
  List<NativeLayerShellMonitor> listMonitors();
  NativeLayerShellMonitor? currentMonitor();
  void configurePanel(NativeLayerShellPanelConfig config);
  void setLayer(NativeLayerShellLayer layer);
  void setNamespace(String appNamespace);
  void setAnchors(NativeLayerShellAnchors anchors);
  void setMargins(NativeLayerShellMargins margins);
  void setExclusiveZone(int zone);
  void setAutoExclusiveZone(bool enabled);
  void setKeyboardMode(NativeLayerShellKeyboardMode mode);
  void setSize(NativeLayerShellSize size);
  void setRegion(NativeLayerShellRegionRequest request);
}
