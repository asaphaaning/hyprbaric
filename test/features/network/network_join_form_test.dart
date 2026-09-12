import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/bindings/bindings.dart';
import 'package:hyprbaric/src/features/network/network_join_form.dart';

Widget form({
  required ValueChanged<NetworkJoinRequest> onJoin,
  NetworkCommandResult? result,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 396,
        child: NetworkJoinForm(
          result: result,
          activeSsid: null,
          onJoin: onJoin,
          onCancel: () {},
          onConnected: () {},
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'manual join preserves credentials and rejects unrelated failures',
    (tester) async {
      NetworkJoinRequest? sent;
      void capture(NetworkJoinRequest request) => sent = request;
      await tester.pumpWidget(form(onJoin: capture));
      await tester.enterText(find.byType(TextField), 'Private network');
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), ' secret ');
      await tester.pump();
      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(sent!.ssid, 'Private network');
      expect(sent!.hidden, isTrue);
      expect(sent!.autoConnect, isTrue);
      expect((sent!.security as NetworkSecurityPersonal).password, ' secret ');
      await tester.pumpWidget(
        form(
          onJoin: capture,
          result: const NetworkCommandResultFailed(
            command: NetworkCommandConnect(ssid: 'Other'),
            message: 'Unrelated',
          ),
        ),
      );
      expect(find.text('Connecting to Private network…'), findsOneWidget);
      expect(find.text('Unrelated'), findsNothing);
      await tester.pumpWidget(
        form(
          onJoin: capture,
          result: const NetworkCommandResultFailed(
            command: NetworkCommandConnect(ssid: 'Private network'),
            message: 'Authentication failed',
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Authentication failed'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        ' secret ',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('name validation uses bytes and a missing confirmation expires', (
    tester,
  ) async {
    await tester.pumpWidget(form(onJoin: (_) {}));
    await tester.enterText(find.byType(TextField), 'é' * 17);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(
      find.text('Network name must contain 1–32 UTF-8 bytes.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'Private');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'password123');
    await tester.pump();
    await tester.tap(find.text('Connect'));
    await tester.pump(const Duration(seconds: 45));
    expect(find.textContaining('Connection not confirmed.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
