import 'package:flutter/material.dart';

import '../../bindings/bindings.dart';
import '../../widgets/hypr_surface.dart';
import 'app_launcher_detail.dart';
import 'app_launcher_footer.dart';
import 'app_launcher_header.dart';
import 'app_launcher_results_list.dart';

class AppLauncherConsole extends StatelessWidget {
  const AppLauncherConsole({
    super.key,
    required this.results,
    required this.queryController,
    required this.queryFocusNode,
    required this.selectedIndex,
    required this.iconPathsByEntryId,
    required this.borderRadius,
    required this.onSelect,
    required this.onLaunch,
    required this.onClose,
    this.errorMessage,
  });

  final AppLauncherResults? results;
  final TextEditingController queryController;
  final FocusNode queryFocusNode;
  final int selectedIndex;
  final Map<String, String> iconPathsByEntryId;
  final BorderRadius borderRadius;
  final ValueChanged<int> onSelect;
  final ValueChanged<AppLauncherEntry> onLaunch;
  final VoidCallback onClose;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final List<AppLauncherEntry> entries =
        results?.entries ?? const <AppLauncherEntry>[];
    final bool loading =
        results == null || results!.phase == AppLauncherPhase.loading;
    final AppLauncherEntry? selectedEntry = entries.isEmpty
        ? null
        : entries[selectedIndex.clamp(0, entries.length - 1)];

    return HyprPopoverSurface(
      borderRadius: borderRadius,
      borderColor: HyprColors.popupStroke,
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AppLauncherHeader(
              queryController: queryController,
              queryFocusNode: queryFocusNode,
              onClose: onClose,
            ),
            if (errorMessage != null)
              LauncherErrorStrip(message: errorMessage!),
            SizedBox(
              height: 396,
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: AppLauncherResultsList(
                      results: results,
                      loading: loading,
                      iconPathsByEntryId: iconPathsByEntryId,
                      selectedIndex: selectedIndex,
                      onSelect: onSelect,
                      onLaunch: onLaunch,
                    ),
                  ),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: HyprColors.popupStroke,
                  ),
                  Expanded(
                    flex: 4,
                    child: AppLauncherDetailPane(
                      entry: selectedEntry,
                      iconPath: selectedEntry == null
                          ? null
                          : selectedEntry.iconPath ??
                                iconPathsByEntryId[selectedEntry.id],
                      onLaunch: selectedEntry == null
                          ? null
                          : () => onLaunch(selectedEntry),
                    ),
                  ),
                ],
              ),
            ),
            AppLauncherFooter(resultCount: entries.length),
          ],
        ),
      ),
    );
  }
}
