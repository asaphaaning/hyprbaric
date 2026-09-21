import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/features/system/system_chip.dart';
import 'package:hyprbaric/src/features/system/system_formatting.dart';
import 'package:hyprbaric/src/features/system/system_gauge.dart';
import 'package:hyprbaric/src/features/system/system_panel.dart';
import 'package:hyprbaric/src/widgets/hypr_surface.dart';

void main() {
  test('cpu and memory chip labels match the bar readout', () {
    final SystemStatus status = _status();

    expect(formatCpuPercent(status), '12%');
    expect(formatMemoryChip(status), '6%');
    expect(formatMemoryPanel(status), '1.8 GB');
    expect(formatDiskPercent(status), '56%');
    expect(formatUptime(status), '2h 14m');
    expect(formatTemperature(status), '58°C');
    expect(formatProcesses(status), '238');
  });

  testWidgets('the chip shows both occupancy readouts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SystemChip(
            status: _status(cpu: 34, memoryGib: 11.2),
            isOpen: false,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.text('CPU'), findsOneWidget);
    expect(find.text('34%'), findsOneWidget);
    expect(find.text('MEM'), findsOneWidget);
    expect(find.text('35%'), findsOneWidget);
  });

  testWidgets('the popover keeps the analog gauge and occupancy meters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: SystemPanel(
              borderRadius: SystemPanel.radius,
              status: AsyncValue<SystemStatus>.data(_status()),
            ),
          ),
        ),
      ),
    );

    expect(find.text('SYSTEM'), findsOneWidget);
    expect(tester.getSize(find.byType(SystemPanel)).width, SystemPanel.width);
    expect(find.byType(SystemGauge), findsOneWidget);
    expect(find.text('CPU'), findsWidgets);
    expect(find.text('Memory'), findsOneWidget);
    expect(find.text('Disk'), findsOneWidget);
    expect(find.text('UPTIME'), findsOneWidget);
    expect(find.text('2h 14m'), findsOneWidget);
    expect(find.text('CPU TEMP'), findsOneWidget);
    expect(find.text('58°C'), findsOneWidget);
    expect(find.text('PROCESSES'), findsOneWidget);
    expect(find.text('238'), findsOneWidget);
  });

  testWidgets('an unavailable snapshot keeps the empty occupancy state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Center(
            child: SystemPanel(
              borderRadius: SystemPanel.radius,
              status: AsyncValue<SystemStatus>.data(
                SystemStatus(
                  cpuHistory: const <int>[],
                  memoryUsedBytes: Uint64.fromBigInt(BigInt.zero),
                  memoryTotalBytes: Uint64.fromBigInt(BigInt.zero),
                  memoryHistory: const <int>[],
                  uptimeSeconds: Uint64.fromBigInt(BigInt.zero),
                  processCount: 0,
                  message: 'memory occupancy is unavailable',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('memory occupancy is unavailable'), findsOneWidget);
    expect(find.byType(SystemGauge), findsNothing);
  });
}

SystemStatus _status({int cpu = 12, double memoryGib = 1.8}) {
  const int gib = 1024 * 1024 * 1024;
  return SystemStatus(
    cpuPercent: cpu,
    cpuHistory: <int>[8, 10, cpu],
    memoryUsedBytes: Uint64.fromBigInt(BigInt.from((memoryGib * gib).round())),
    memoryTotalBytes: Uint64.fromBigInt(BigInt.from(32 * gib)),
    memoryHistory: const <int>[30, 32],
    diskUsedBytes: Uint64.fromBigInt(BigInt.from(56)),
    diskTotalBytes: Uint64.fromBigInt(BigInt.from(100)),
    uptimeSeconds: Uint64.fromBigInt(BigInt.from(8040)),
    temperatureCelsius: 58,
    processCount: 238,
  );
}
