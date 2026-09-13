import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import '../../catalog/catalog_frame.dart';

@UseCase(name: 'Test drive', type: MotionPlayground, path: '[Widgets]/Motion')
Widget buildMotionTestDrive(BuildContext context) => const MotionPlayground();

/// Interactive rehearsal of shared motion primitives in the bar's visual language.
class MotionPlayground extends StatefulWidget {
  const MotionPlayground({super.key});
  @override
  State<MotionPlayground> createState() => _MotionPlaygroundState();
}

enum _Tempo { normal, slow }

enum _Playback { manual, running }

class _MotionPlaygroundState extends State<MotionPlayground> {
  _Tempo tempo = _Tempo.normal;
  _Playback playback = _Playback.manual;
  bool reducedMotion = false;
  int appRevision = 0;
  int valueRevision = 0;
  int nextBanner = 3;
  List<int> banners = [2, 1, 0];
  Timer? timer;
  static const titles = ['Firefox', 'Visual Studio Code', 'Files', 'Terminal'];
  static const menus = [
    'File   Edit   View   History   Bookmarks',
    'File   Edit   Selection   View   Go',
    'File   Edit   View   Go   Help',
    'File   Edit   View   Search   Terminal',
  ];
  static const numbers = ['28.4', '31.2', '99.9', '100.0', '4.7', '28.4'];
  static const messages = [
    'Build completed successfully',
    'New PR merged: feat/motion',
    'Your screenshot is ready',
    'Connected to Orbital-5G',
  ];

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void switchApp() => setState(() => appRevision++);
  void updateValue() => setState(() => valueRevision++);
  void addBanner() =>
      setState(() => banners = [nextBanner++, ...banners].take(3).toList());
  void togglePlayback() {
    timer?.cancel();
    setState(
      () => playback = playback == _Playback.manual
          ? _Playback.running
          : _Playback.manual,
    );
    if (playback == _Playback.running) {
      timer = Timer.periodic(const Duration(milliseconds: 1100), (_) {
        switchApp();
        updateValue();
        addBanner();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final duration = Duration(milliseconds: tempo == _Tempo.normal ? 220 : 900);
    return CatalogCanvas(
      child: SizedBox(
        width: 660,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const HyprInstrumentHeader(
              title: 'Motion studio',
              icon: Icon(Icons.motion_photos_on_outlined),
              subtitle: 'Titles, live values & notifications',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed: togglePlayback,
                  child: Text(
                    playback == _Playback.manual ? 'Play all' : 'Pause',
                  ),
                ),
                ChoiceChip(
                  label: const Text('220 ms'),
                  selected: tempo == _Tempo.normal,
                  onSelected: (_) => setState(() => tempo = _Tempo.normal),
                ),
                ChoiceChip(
                  label: const Text('Slow motion'),
                  selected: tempo == _Tempo.slow,
                  onSelected: (_) => setState(() => tempo = _Tempo.slow),
                ),
                FilterChip(
                  label: const Text('Reduced motion'),
                  selected: reducedMotion,
                  onSelected: (value) => setState(() => reducedMotion = value),
                ),
              ],
            ),
            const SizedBox(height: 20),
            MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations:
                    reducedMotion || MediaQuery.disableAnimationsOf(context),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Stage(
                    title: '01  TEXT STATES SWAP',
                    subtitle: 'App title & global menu · official Flutter fade-through',
                    action: TextButton(
                      onPressed: switchApp,
                      child: const Text('Switch app'),
                    ),
                    child: SizedBox(
                      height: 78,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.desktop_windows_outlined,
                                size: 22,
                                color: Color(0xFFC4AEFF),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: HyprTextSwap(
                                  duration: duration,
                                  child: Text(
                                    titles[appRevision % titles.length],
                                    key: ValueKey(appRevision % titles.length),
                                    style: HyprInstrumentText.body.copyWith(
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          HyprTextSwap(
                            duration: duration,
                            child: Text(
                              menus[appRevision % menus.length],
                              key: ValueKey(appRevision % menus.length),
                              style: HyprTypography.bar,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Stage(
                    title: '02  NUMBER POP-IN',
                    subtitle: 'Changed digits only · try clicking faster than the transition',
                    action: TextButton(
                      onPressed: updateValue,
                      child: const Text('Update value'),
                    ),
                    child: SizedBox(
                      height: 96,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.south_rounded,
                            color: Color(0xFFB16BFF),
                            size: 40,
                          ),
                          const SizedBox(width: 14),
                          HyprDigitPop(
                            value: numbers[valueRevision % numbers.length],
                            duration: duration,
                            style: HyprTypography.mixerValue.copyWith(
                              fontSize: 52,
                              color: const Color(0xFFC28AFF),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text('Mbps', style: HyprInstrumentText.body),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Stage(
                    title: '03  BANNER STACKING',
                    subtitle:
                        'Three deep · click the front notification to dismiss',
                    action: TextButton(
                      onPressed: addBanner,
                      child: const Text('Add notification'),
                    ),
                    child: HyprBannerStack(
                      duration: duration,
                      banners: [
                        for (final id in banners)
                          HyprBanner(
                            id: id,
                            child: _Banner(
                              id: id,
                              message: messages[id % messages.length],
                              onDismiss: () => setState(
                                () => banners = banners
                                    .where((item) => item != id)
                                    .toList(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Motion rehearsal · shared primitives ready for integration',
              style: HyprInstrumentText.meta,
            ),
          ],
        ),
      ),
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget action;
  final Widget child;
  @override
  Widget build(BuildContext context) => HyprPopoverPanel(
    borderRadius: BorderRadius.circular(20),
    constraints: const BoxConstraints(),
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: HyprInstrumentText.title.copyWith(fontSize: 13),
              ),
            ),
            action,
          ],
        ),
        Text(subtitle, style: HyprInstrumentText.meta),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.id,
    required this.message,
    required this.onDismiss,
  });
  final int id;
  final String message;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Dismiss notification: $message',
    child: GestureDetector(
      onTap: onDismiss,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF191C25),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF555168)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFFC4AEFF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: HyprInstrumentText.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.close, size: 16, color: Color(0xFFBCBDD1)),
            ],
          ),
        ),
      ),
    ),
  );
}
