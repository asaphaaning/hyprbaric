import '../../bindings/bindings.dart';

int _bytes(Uint64? value) => value?.toInt() ?? 0;

/// Compact CPU readout for the bar chip.
String formatCpuPercent(SystemStatus? status) {
  final int? percent = status?.cpuPercent;
  if (percent == null) {
    return '--%';
  }
  return '${percent.clamp(0, 100)}%';
}

/// Compact memory readout for the bar chip, as a percent of installed RAM.
String formatMemoryChip(SystemStatus? status) {
  final int total = _bytes(status?.memoryTotalBytes);
  if (total <= 0) {
    return '--%';
  }
  final int percent = ((_bytes(status?.memoryUsedBytes) * 100) / total)
      .round()
      .clamp(0, 100);
  return '$percent%';
}

/// Panel memory readout with a spaced unit, e.g. `1.8 GB`.
String formatMemoryPanel(SystemStatus? status) {
  final int total = _bytes(status?.memoryTotalBytes);
  if (total <= 0) {
    return '--';
  }
  return _panelBytes(_bytes(status?.memoryUsedBytes));
}

/// Panel disk occupancy as a percent of the root mount.
String formatDiskPercent(SystemStatus? status) {
  final int? used = status?.diskUsedBytes?.toInt();
  final int? total = status?.diskTotalBytes?.toInt();
  if (used == null || total == null || total <= 0) {
    return '--';
  }
  return '${((used * 100) / total).round().clamp(0, 100)}%';
}

double cpuRatio(SystemStatus? status) {
  return ((status?.cpuPercent ?? 0).clamp(0, 100)) / 100;
}

double memoryRatio(SystemStatus? status) {
  final int total = _bytes(status?.memoryTotalBytes);
  if (total <= 0) {
    return 0;
  }
  return (_bytes(status?.memoryUsedBytes) / total).clamp(0, 1);
}

double diskRatio(SystemStatus? status) {
  final int? used = status?.diskUsedBytes?.toInt();
  final int? total = status?.diskTotalBytes?.toInt();
  if (used == null || total == null || total <= 0) {
    return 0;
  }
  return (used / total).clamp(0, 1);
}

String formatUptime(SystemStatus? status) {
  final int seconds = status?.uptimeSeconds.toInt() ?? 0;
  if (seconds <= 0) {
    return '--';
  }
  final int hours = seconds ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  if (hours <= 0) {
    return '${minutes}m';
  }
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
}

String formatTemperature(SystemStatus? status) {
  final double? temperature = status?.temperatureCelsius;
  if (temperature == null) {
    return '--°C';
  }
  return '${temperature.round()}°C';
}

String formatProcesses(SystemStatus? status) {
  final int? count = status?.processCount;
  if (count == null || count <= 0) {
    return '--';
  }
  return '$count';
}

List<double> cpuHistory(SystemStatus? status) {
  return _history(status?.cpuHistory, fallback: cpuRatio(status));
}

List<double> memoryHistory(SystemStatus? status) {
  return _history(status?.memoryHistory, fallback: memoryRatio(status));
}

List<double> _history(List<int>? samples, {required double fallback}) {
  if (samples == null || samples.isEmpty) {
    return <double>[fallback];
  }
  return samples
      .map((int sample) => (sample.clamp(0, 100)) / 100)
      .toList(growable: false);
}

String _panelBytes(int bytes) {
  final _ByteDisplay display = _display(bytes);
  return '${display.value} ${display.unit}';
}

_ByteDisplay _display(int bytes) {
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  final String formatted = unitIndex == 0
      ? value.toStringAsFixed(0)
      : value >= 10
      ? (value - value.round()).abs() < 0.05
            ? value.round().toString()
            : value.toStringAsFixed(1)
      : value.toStringAsFixed(1);
  return _ByteDisplay(value: formatted, unit: units[unitIndex]);
}

class _ByteDisplay {
  const _ByteDisplay({required this.value, required this.unit});

  final String value;
  final String unit;
}
