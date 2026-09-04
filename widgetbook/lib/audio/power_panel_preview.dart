import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hyprbaric/widget_catalog.dart';

import '../use_cases/power/power_fixtures.dart';

/// Interactive power preview shared by Widgetbook and the website.
class PowerPanelPreview extends StatefulWidget {
  const PowerPanelPreview({super.key, this.initialStatus});

  final PowerStatus? initialStatus;

  @override
  State<PowerPanelPreview> createState() => _PowerPanelPreviewState();
}

class _PowerPanelPreviewState extends State<PowerPanelPreview> {
  late PowerStatus _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus ?? PowerFixtures.laptop();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: PowerPanel(
        borderRadius: HyprRadii.popoverRadius,
        status: AsyncData<PowerStatus>(_status),
        latestResult: null,
        onSetProfile: _setProfile,
      ),
    );
  }

  void _setProfile(PowerProfile profile) {
    setState(() => _status = _status.copyWith(activeProfile: () => profile));
  }
}
