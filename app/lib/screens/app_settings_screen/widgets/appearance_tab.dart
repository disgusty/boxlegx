import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../services/l10n/locale_controller.dart';
import '../../../theme/app_style.dart';

/// §541 — Appearance tab для App Settings: всё про внешний вид (тема,
/// компоновка — поворот и две колонки списка узлов, язык).
///
/// Stateless, как [GeneralTab]: значения и callback'и приходят от
/// `_AppSettingsScreenState`; тема и язык читаются из своих контроллеров
/// напрямую (экран слушает их через AnimatedBuilder).
class AppearanceTab extends StatelessWidget {
  const AppearanceTab({
    super.key,
    required this.loaded,
    required this.allowRotation,
    required this.nodeListTwoColumns,
    required this.padding,
    required this.onAllowRotationChanged,
    required this.onNodeListTwoColumnsChanged,
  });

  final bool loaded;
  final bool allowRotation;

  /// §541 — две колонки списка узлов на широком окне (§537).
  final bool nodeListTwoColumns;
  final EdgeInsets padding;

  final ValueChanged<bool> onAllowRotationChanged;
  final ValueChanged<bool> onNodeListTwoColumnsChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: padding,
      children: [
        Text(getLocalText.s("Appearance"),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Column(
            children: ThemeMode.values.map((mode) {
              final label = switch (mode) {
                ThemeMode.system => getLocalText.s("System"),
                ThemeMode.light => getLocalText.s("Light"),
                ThemeMode.dark => getLocalText.s("Dark"),
              };
              final icon = switch (mode) {
                ThemeMode.system => Icons.brightness_auto,
                ThemeMode.light => Icons.light_mode,
                ThemeMode.dark => Icons.dark_mode,
              };
              return RadioListTile<ThemeMode>(
                value: mode,
                groupValue: themeNotifier.mode,
                onChanged: (v) { if (v != null) themeNotifier.setMode(v); },
                title: Text(label),
                secondary: Icon(icon),
              );
            }).toList(),
          ),
        const SizedBox(height: 8),
        // Стиль интерфейса: Material 3 (исходный) / Material 1 / Holo.
        // Применяется сразу — MaterialApp слушает appStyle.
        Text(getLocalText.s("Interface style"),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Column(
            children: UiStyle.values.map((style) {
              final (label, subtitle) = switch (style) {
                UiStyle.material3 => (
                    getLocalText.s("Material Design 3"),
                    getLocalText.s("Default modern look"),
                  ),
                UiStyle.material1 => (
                    getLocalText.s("Material Design 1"),
                    getLocalText.s("Classic look of Android 5.0 Lollipop"),
                  ),
                UiStyle.holo => (
                    getLocalText.s("Holo"),
                    getLocalText.s("Look of Android 4.0–4.4"),
                  ),
              };
              return RadioListTile<UiStyle>(
                value: style,
                groupValue: appStyle.style,
                onChanged: (v) { if (v != null) appStyle.setStyle(v); },
                title: Text(label),
                subtitle: Text(subtitle),
                secondary: Icon(switch (style) {
                  UiStyle.material3 => Icons.auto_awesome_outlined,
                  UiStyle.material1 => Icons.layers_outlined,
                  UiStyle.holo => Icons.grid_view,
                }),
              );
            }).toList(),
          ),
        SwitchListTile(
          title: Text(getLocalText.s("Simplified animations")),
          subtitle: Text(getLocalText.s("Instant screen transitions and fewer moving effects. Smoother on old and slow devices.")),
          secondary: const Icon(Icons.animation),
          value: appStyle.reduceMotion,
          onChanged: appStyle.setReduceMotion,
        ),
        // Рендеринг: GPU (OpenGL ES) по умолчанию, CPU — запасной путь для
        // слабых или несовместимых GPU. Применяется после перезапуска.
        SwitchListTile(
          title: Text(getLocalText.s("Render on CPU (software)")),
          subtitle: Text(getLocalText.s("Draw the interface on the processor instead of the graphics chip. Use it if the screen stays blank or glitches; slower. Applies after the app restarts.")),
          secondary: const Icon(Icons.memory),
          value: appStyle.softwareRendering,
          onChanged: appStyle.setSoftwareRendering,
        ),
        const SizedBox(height: 8),
        // §541 — компоновка: поворот и две колонки списка узлов в одном месте.
        Text(getLocalText.s("Layout"),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        // §220 — снятие портретной фиксации (планшетный фидбэк). Применяется
        // сразу, без рестарта; уважает системный auto-rotate.
        SwitchListTile(
          title: Text(getLocalText.s("Allow rotation")),
          subtitle: Text(getLocalText.s("Rotate to landscape when the device turns — handy on tablets. Follows the system auto-rotate setting.")),
          secondary: const Icon(Icons.screen_rotation),
          value: allowRotation,
          onChanged: loaded ? onAllowRotationChanged : null,
        ),
        // §541 — гейт двухколоночной раскладки §537; применяется сразу через
        // SettingsStorage.nodeListTwoColumns.
        SwitchListTile(
          title: Text(getLocalText.s("Two columns on wide screens")),
          subtitle: Text(getLocalText.s("Show the node list in two columns when the window is at least 600 dp wide (tablets, landscape, split-screen).")),
          secondary: const Icon(Icons.view_column_outlined),
          value: nodeListTwoColumns,
          onChanged: loaded ? onNodeListTwoColumnsChanged : null,
        ),
        const SizedBox(height: 8),
        // §279 — выбор языка приложения; смена применяется мгновенно через
        // LocaleController (полный пайплайн: ARB + template + rebuild).
        Text(getLocalText.s("Language"),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Column(
          children: [
            _langTile('system', getLocalText.s("System default"),
                icon: Icons.language),
            // Эндонимы: каждая метка на своём языке, сознательно не из ARB
            // текущей локали.
            _langTile('en', 'English'), // l10n-exempt: endonym
            _langTile('ru', 'Русский'), // l10n-exempt: endonym
            _langTile('zh', '中文（简体）'), // l10n-exempt: endonym
          ],
        ),
      ],
    );
  }

  Widget _langTile(String value, String title, {IconData? icon}) =>
      RadioListTile<String>(
        value: value,
        groupValue: LocaleController.I.setting,
        onChanged: (v) { if (v != null) LocaleController.I.set(v); },
        title: Text(title),
        secondary: icon == null ? null : Icon(icon),
      );
}
