import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hyprbaric/src/widgets/hypr_surface.dart';
import 'package:hyprbaric/src/widgets/layer_shell_dropdown.dart';
import 'package:hyprbaric/src/widgets/popover_handoff.dart';

/// Two bar buttons whose popovers hand their shell to one another.
class _HandoffBar extends StatelessWidget {
  const _HandoffBar({required this.mixer, required this.power});

  final LayerShellDropdownController mixer;
  final LayerShellDropdownController power;

  void _switchTo(LayerShellDropdownController next) {
    if (next.isOpen) {
      next.close();
      return;
    }
    mixer.dismiss();
    power.dismiss();
    next.open();
  }

  Widget _dropdown(
    LayerShellDropdownController controller,
    String label,
    double width,
    double height,
  ) {
    return LayerShellDropdown(
      controller: controller,
      handoff: LayerShellDropdownHandoff.morph,
      menuWidth: width,
      menuRadius: HyprRadii.popoverRadius,
      buttonBuilder: (context, _, {required bool isOpen}) => TextButton(
        onPressed: () => _switchTo(controller),
        child: Text(label),
      ),
      menuBuilder: (context, _) => HyprInstrumentSurface(
        borderRadius: HyprRadii.popoverRadius,
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            children: <Widget>[
              for (int index = 0; index < 3; index++)
                PopoverStaggerItem(
                  index: index,
                  child: Text('$label section $index'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: SizedBox(
        height: 36,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _dropdown(mixer, 'Mixer', 354, 420),
            const SizedBox(width: 40),
            _dropdown(power, 'Power', 450, 260),
          ],
        ),
      ),
    );
  }
}

Future<void> _pumpBar(
  WidgetTester tester,
  LayerShellDropdownController mixer,
  LayerShellDropdownController power,
) async {
  tester.view.physicalSize = const Size(1600, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: _HandoffBar(mixer: mixer, power: power),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('switching popovers glides one shell into the next', (
    WidgetTester tester,
  ) async {
    final LayerShellDropdownController mixer = LayerShellDropdownController();
    final LayerShellDropdownController power = LayerShellDropdownController();
    await _pumpBar(tester, mixer, power);

    await tester.tap(find.text('Mixer'));
    await tester.pumpAndSettle();
    expect(find.text('Mixer section 0'), findsOneWidget);

    await tester.tap(find.text('Power'));
    await tester.pump();
    await tester.pump(HyprMotion.handoff * .25);

    // Mid-handoff the departing sections are still clearing out.
    expect(mixer.isOpen, isFalse);
    expect(power.isOpen, isTrue);
    expect(find.text('Mixer section 0'), findsOneWidget);
    expect(find.text('Power section 0'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Mixer section 0'), findsNothing);
    expect(find.text('Power section 2'), findsOneWidget);
  });

  testWidgets('departing contents ignore the pointer', (
    WidgetTester tester,
  ) async {
    final LayerShellDropdownController mixer = LayerShellDropdownController();
    final LayerShellDropdownController power = LayerShellDropdownController();
    await _pumpBar(tester, mixer, power);

    await tester.tap(find.text('Mixer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Power'));
    await tester.pump();

    expect(find.text('Mixer section 0').hitTestable(), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a plain dismissal leaves at once without a successor', (
    WidgetTester tester,
  ) async {
    final LayerShellDropdownController mixer = LayerShellDropdownController();
    final LayerShellDropdownController power = LayerShellDropdownController();
    await _pumpBar(tester, mixer, power);

    await tester.tap(find.text('Mixer'));
    await tester.pumpAndSettle();
    mixer.dismiss();
    await tester.pump();
    await tester.pump();

    expect(mixer.isOpen, isFalse);
    expect(find.text('Mixer section 0'), findsNothing);
  });

  testWidgets('toggling a popover opens and closes it instantly', (
    WidgetTester tester,
  ) async {
    final LayerShellDropdownController mixer = LayerShellDropdownController();
    final LayerShellDropdownController power = LayerShellDropdownController();
    await _pumpBar(tester, mixer, power);

    await tester.tap(find.text('Mixer'));
    await tester.pump();
    expect(mixer.isOpen, isTrue);
    expect(find.text('Mixer section 0').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Mixer'));
    await tester.pump();
    expect(mixer.isOpen, isFalse);
    expect(find.text('Mixer section 0'), findsNothing);
  });

  testWidgets('switching back mid-handoff reopens the first popover', (
    WidgetTester tester,
  ) async {
    final LayerShellDropdownController mixer = LayerShellDropdownController();
    final LayerShellDropdownController power = LayerShellDropdownController();
    await _pumpBar(tester, mixer, power);

    await tester.tap(find.text('Mixer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Power'));
    await tester.pump(HyprMotion.handoff * .3);
    await tester.tap(find.text('Mixer'));
    await tester.pumpAndSettle();

    expect(mixer.isOpen, isTrue);
    expect(power.isOpen, isFalse);
    expect(find.text('Mixer section 0'), findsOneWidget);
    expect(find.text('Power section 0'), findsNothing);
  });
}
