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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          SettingsOverlayLayout.surfaceRadius,
        ),
        child: Row(
          children: <Widget>[
            ColoredBox(
              color: const Color(0x7007090E),
              child: SettingsSidebar(
                activeTab: tab,
                onTabChanged: onTabChanged,
              ),
            ),
            const VerticalDivider(width: 1, color: HyprColors.borderSoft),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xA03A4050), Color(0x601B1F29)],
                      ),
                      border: Border(
                        bottom: BorderSide(color: Color(0x457E86B4)),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(
                        SettingsOverlayLayout.bodyPadding,
                      ),
                      child: SettingsContentHeader(tab: tab, onClose: onClose),
                    ),
                  ),
                  Expanded(child: SettingsTabBody(tab: tab)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
