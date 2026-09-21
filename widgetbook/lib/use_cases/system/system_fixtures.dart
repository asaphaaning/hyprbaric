import 'package:hyprbaric/widget_catalog.dart';

abstract final class SystemFixtures {
  static Uint64 _bytes(int value) => Uint64.fromBigInt(BigInt.from(value));

  static const int gib = 1024 * 1024 * 1024;

  static SystemStatus reference({
    int cpuPercent = 12,
    double memoryGib = 1.8,
    int memoryTotalGib = 32,
    int diskPercent = 56,
    int uptimeSeconds = 2 * 3600 + 14 * 60,
    double temperature = 58,
    int processes = 238,
  }) {
    return SystemStatus(
      cpuPercent: cpuPercent,
      cpuHistory: _ramp(cpuPercent),
      memoryUsedBytes: _bytes((memoryGib * gib).round()),
      memoryTotalBytes: _bytes(memoryTotalGib * gib),
      memoryHistory: _ramp(((memoryGib / memoryTotalGib) * 100).round()),
      diskUsedBytes: _bytes(diskPercent),
      diskTotalBytes: _bytes(100),
      uptimeSeconds: _bytes(uptimeSeconds),
      temperatureCelsius: temperature,
      processCount: processes,
    );
  }

  static SystemStatus barReadout() {
    return reference(cpuPercent: 34, memoryGib: 11.2);
  }

  static SystemStatus idle() {
    return reference(
      cpuPercent: 3,
      memoryGib: 2.1,
      diskPercent: 18,
      temperature: 41,
      processes: 112,
    );
  }

  static SystemStatus high() {
    return reference(
      cpuPercent: 91,
      memoryGib: 29.4,
      diskPercent: 88,
      temperature: 79,
      processes: 412,
    );
  }

  static SystemStatus measuring() {
    return SystemStatus(
      cpuPercent: null,
      cpuHistory: const <int>[],
      memoryUsedBytes: _bytes(8 * gib),
      memoryTotalBytes: _bytes(32 * gib),
      memoryHistory: const <int>[25],
      diskUsedBytes: _bytes(40),
      diskTotalBytes: _bytes(100),
      uptimeSeconds: _bytes(90),
      temperatureCelsius: 46,
      processCount: 140,
    );
  }

  static SystemStatus unavailable() {
    return SystemStatus(
      cpuPercent: null,
      cpuHistory: const <int>[],
      memoryUsedBytes: _bytes(0),
      memoryTotalBytes: _bytes(0),
      memoryHistory: const <int>[],
      uptimeSeconds: _bytes(0),
      processCount: 0,
      message: 'memory occupancy is unavailable',
    );
  }

  static List<int> _ramp(int current) {
    final List<int> samples = <int>[
      8,
      11,
      9,
      14,
      18,
      16,
      22,
      19,
      24,
      28,
      31,
      current.clamp(0, 100),
    ];
    return samples;
  }
}
