import 'package:flutter/foundation.dart';

/// One observed pair of rates, in decimal megabits per second.
@immutable
class TrafficSample {
  const TrafficSample({
    required this.at,
    required this.download,
    required this.upload,
  });

  /// Monotonic time since the collector started.
  final Duration at;

  /// Received megabits per second.
  final double download;

  /// Sent megabits per second.
  final double upload;
}

/// A rolling minute of observed traffic. Missing history remains missing.
///
/// Samples are chronological. The ring projects age clockwise from twelve:
/// `NOW → 15s → 30s → 45s`. A predecessor just outside the window is retained
/// to interpolate the boundary without fabricating a new observation.
@immutable
class TrafficHistory {
  const TrafficHistory.empty() : samples = const [];

  TrafficHistory._(Iterable<TrafficSample> samples)
    : samples = List.unmodifiable(samples);

  static const window = Duration(seconds: 60);

  /// Observations from oldest to newest, including one boundary predecessor.
  final List<TrafficSample> samples;

  TrafficSample? get latest => samples.lastOrNull;

  /// Adds an observation; duplicate timestamps replace, stale ones are ignored.
  TrafficHistory record(TrafficSample sample) {
    final previous = latest;
    if (previous != null && sample.at < previous.at) return this;
    final cutoff = sample.at - window;
    final retained = samples.where((value) => value.at < sample.at).toList();
    while (retained.length > 1 && retained[1].at <= cutoff) {
      retained.removeAt(0);
    }
    return TrafficHistory._([...retained, sample]);
  }

  /// Recorded extent, independent of sampling cadence or traffic magnitude.
  Duration get extent => samples.isEmpty
      ? Duration.zero
      : Duration(
          microseconds: (samples.last.at - samples.first.at).inMicroseconds
              .clamp(0, window.inMicroseconds),
        );
}
