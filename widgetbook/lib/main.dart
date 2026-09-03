import 'package:flutter/material.dart';
import 'package:hyprbaric/widget_catalog.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

import 'catalog/catalog_theme.dart';
import 'main.directories.g.dart';

@App()
void main() {
  runApp(const HyprbaricWidgetbook());
}

class HyprbaricWidgetbook extends StatelessWidget {
  const HyprbaricWidgetbook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: directories,
      addons: <WidgetbookAddon>[
        MaterialThemeAddon(
          themes: <WidgetbookTheme<ThemeData>>[
            for (final MapEntry<String, HyprPalette> palette
                in CatalogPalettes.all.entries)
              WidgetbookTheme<ThemeData>(
                name: palette.key,
                data: catalogThemeFor(palette.value),
              ),
          ],
        ),
      ],
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: ThemeMode.dark,
    );
  }
}
