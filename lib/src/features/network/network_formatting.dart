import '../../bindings/bindings.dart';

/// Returns the compact radio band label used in the Wi-Fi list.
///
/// The current signal payload does not expose a frequency. This deliberately
/// keeps the display-only inference at the presentation boundary; connection
/// behaviour never depends on the SSID's name.
String networkBandLabel(NetworkEntry entry) {
  final String ssid = entry.ssid.toUpperCase();
  if (ssid.contains('5G') || ssid.contains('5 GHZ')) {
    return '5G';
  }
  if (ssid.contains('2.4') || ssid.contains('2G')) {
    return '2.4G';
  }
  return networkStrengthLabel(entry.strength);
}

String formatTransferRateValue(Uint64 bytesPerSecond) {
  final NetworkByteDisplay display = byteDisplay(bytesPerSecond.toInt());
  return display.value;
}

String formatTransferRateUnit(Uint64 bytesPerSecond) {
  final NetworkByteDisplay display = byteDisplay(bytesPerSecond.toInt());
  return '${display.unit}/s';
}

double megabytesPerSecond(Uint64 bytesPerSecond) {
  return bytesPerSecond.toInt() / (1024 * 1024);
}

String formatBytes(Uint64 bytes) {
  final NetworkByteDisplay display = byteDisplay(bytes.toInt());
  return '${display.value} ${display.unit}';
}

String networkStrengthLabel(int strength) {
  final int clamped = strength.clamp(0, 100);
  if (clamped >= 80) {
    return 'STRONG';
  }
  if (clamped >= 50) {
    return 'GOOD';
  }
  if (clamped > 0) {
    return 'WEAK';
  }
  return 'HIDDEN';
}

NetworkByteDisplay byteDisplay(int bytes) {
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }

  final String formatted = unitIndex == 0
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(value >= 10 ? 1 : 2);
  return NetworkByteDisplay(value: formatted, unit: units[unitIndex]);
}

class NetworkByteDisplay {
  const NetworkByteDisplay({required this.value, required this.unit});

  final String value;
  final String unit;
}
