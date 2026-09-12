import 'dart:math' as math;

import 'package:hyprbaric/widget_catalog.dart';

/// Simulated traffic for the website only, within the ring's fixed Mbps scales.
///
/// A complete minute is ready on the first frame. Subsequent samples extend
/// the same continuous signal, so the initial history never resets or morphs.
abstract final class NetworkTrafficDemo {
  /// Pre-roll at half-second intervals gives both rings detailed silhouettes.
  static TrafficHistory prefill() {
    var history = const TrafficHistory.empty();
    for (var tick = 0; tick <= 120; tick++) {
      history = history.record(sample(Duration(milliseconds: tick * 500)));
    }
    return history;
  }

  /// Independent, layered bursts leave headroom below 60 down and 10 up.
  static TrafficSample sample(Duration at) {
    final seconds = at.inMicroseconds / Duration.microsecondsPerSecond;
    final download =
        35 +
        12 * math.sin(seconds * .47) +
        6 * math.sin(seconds * 1.31 + .8) +
        3 * math.sin(seconds * 2.73);
    final upload =
        5.6 +
        1.9 * math.sin(seconds * .61 + 1.4) +
        1.2 * math.sin(seconds * 1.57) +
        .5 * math.sin(seconds * 2.91 + .5);
    return TrafficSample(at: at, download: download, upload: upload);
  }

  /// Readouts and trace consume the same sample and decimal Mbps conversion.
  static NetworkTraffic traffic(TrafficSample sample) => NetworkTraffic(
    download: _transfer(sample.download, 1820000000),
    upload: _transfer(sample.upload, 284000000),
    pingMs: 12,
  );

  static NetworkTransfer _transfer(double mbps, int totalBytes) =>
      NetworkTransfer(
        bytesPerSecond: Uint64.fromBigInt(BigInt.from((mbps * 125000).round())),
        totalBytes: Uint64.fromBigInt(BigInt.from(totalBytes)),
      );
}
