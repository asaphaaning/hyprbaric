import 'package:flutter/material.dart';

import '../../widgets/hypr_surface.dart';
import 'settings_overlay_layout.dart';
import 'settings_tab_body.dart';
import 'settings_tabs.dart';

class SettingsOverlayContent extends StatelessWidget {
  const SettingsOverlayContent({
    super.key,
    required this.tab,
    required this.onTabChanged,
    required this.onClose,
  });

  final SettingsTab tab;
  final ValueChanged<SettingsTab> onTabChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: SettingsOverlayLayout.contentKey,
      width: SettingsOverlayLayout.width,
      height: SettingsOverlayLayout.height,
      child: Row(
        children: <Widget>[
          SettingsSidebar(activeTab: tab, onTabChanged: onTabChanged),
          const VerticalDivider(width: 1, color: HyprColors.borderSoft),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(SettingsOverlayLayout.bodyPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SettingsContentHeader(tab: tab, onClose: onClose),
                  const SizedBox(height: SettingsOverlayLayout.headerGap),
                  Expanded(child: SettingsTabBody(tab: tab)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
