import 'package:flutter/material.dart';

import '../../../main.dart';
import '../../../services/l10n/locale_controller.dart';
import '../../../theme/accent.dart';
import '../../../theme/app_style.dart';

import '../../../theme/styled_widgets.dart';
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
        SectionTitle(getLocalText.s("Appearance")),
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
        SectionTitle(getLocalText.s("Interface style")),
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
        // Акцентный цвет — Material 3 (seed схемы) и Material 1 (панель и
        // элементы). Фон и светлая/тёмная тема не меняются; у Holo своя
        // палитра, поэтому для него выбор скрыт.
        if (appStyle.style != UiStyle.holo) ...[
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: Text(getLocalText.s("Accent color")),
            subtitle: Text(getLocalText.s("Color of the top bar and controls. The background stays the same.")),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final color in AccentPalette.colors)
                  _AccentSwatch(
                    color: color,
                    selected: color == appStyle.accent,
                    onTap: () => appStyle.setAccent(color),
                  ),
              ],
            ),
          ),
        ],
        StyledSwitchListTile(
          title: Text(getLocalText.s("Simplified animations")),
          subtitle: Text(getLocalText.s("Instant screen transitions and fewer moving effects. Smoother on old and slow devices.")),
          secondary: const Icon(Icons.animation),
          value: appStyle.reduceMotion,
          onChanged: appStyle.setReduceMotion,
        ),
        // Рендеринг: GPU (OpenGL ES) по умолчанию, CPU — запасной путь для
        // слабых или несовместимых GPU. Применяется после перезапуска.
        StyledSwitchListTile(
          title: Text(getLocalText.s("Render on CPU (software)")),
          subtitle: Text(getLocalText.s("Draw the interface on the processor instead of the graphics chip. Use it if the screen stays blank or glitches; slower. Applies after the app restarts.")),
          secondary: const Icon(Icons.memory),
          value: appStyle.softwareRendering,
          onChanged: appStyle.setSoftwareRendering,
        ),
        const SizedBox(height: 8),
        // §541 — компоновка: поворот и две колонки списка узлов в одном месте.
        SectionTitle(getLocalText.s("Layout")),
        const SizedBox(height: 8),
        // §220 — снятие портретной фиксации (планшетный фидбэк). Применяется
        // сразу, без рестарта; уважает системный auto-rotate.
        StyledSwitchListTile(
          title: Text(getLocalText.s("Allow rotation")),
          subtitle: Text(getLocalText.s("Rotate to landscape when the device turns — handy on tablets. Follows the system auto-rotate setting.")),
          secondary: const Icon(Icons.screen_rotation),
          value: allowRotation,
          onChanged: loaded ? onAllowRotationChanged : null,
        ),
        // §541 — гейт двухколоночной раскладки §537; применяется сразу через
        // SettingsStorage.nodeListTwoColumns.
        StyledSwitchListTile(
          title: Text(getLocalText.s("Two columns on wide screens")),
          subtitle: Text(getLocalText.s("Show the node list in two columns when the window is at least 600 dp wide (tablets, landscape, split-screen).")),
          secondary: const Icon(Icons.view_column_outlined),
          value: nodeListTwoColumns,
          onChanged: loaded ? onNodeListTwoColumnsChanged : null,
        ),
        const SizedBox(height: 8),
        // §279 — выбор языка приложения; смена применяется мгновенно через
        // LocaleController (полный пайплайн: ARB + template + rebuild).
        SectionTitle(getLocalText.s("Language")),
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

/// Кружок цвета в выборе акцента; выбранный — с галочкой.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final MaterialColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.shade500,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(
                    color: Theme.of(context).colorScheme.onSurface, width: 2)
                : null,
          ),
          child: selected
              ? Icon(Icons.check,
                  size: 20,
                  color: AccentPalette.needsDarkForeground(color)
                      ? Colors.black87
                      : Colors.white)
              : null,
        ),
      ),
    );
  }
}
