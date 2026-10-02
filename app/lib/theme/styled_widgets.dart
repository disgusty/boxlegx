import 'package:flutter/material.dart';

import 'holo.dart';

// Обёртки над стандартными виджетами для стилей интерфейса. В Material 3 и
// Material 1 они отдают обычный виджет без изменений; в Holo — элемент
// Android 4.x, который темой не выразить (форма, регистр, раскладка).
// Стиль определяется по HoloThemeExt в Theme.of(context).
//
// Файл общий для веток main и legacy-api17.

/// Переключатель: в Holo — [HoloSwitch] («ВКЛ»/«ВЫКЛ»).
class StyledSwitch extends StatelessWidget {
  const StyledSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (HoloThemeExt.of(context) == null) {
      return Switch(value: value, onChanged: onChanged);
    }
    return HoloSwitch(value: value, onChanged: onChanged);
  }
}

/// Строка с переключателем: в Holo — строка списка с [HoloSwitch] справа
/// (как SwitchPreference в настройках Android 4.x).
class StyledSwitchListTile extends StatelessWidget {
  const StyledSwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;

  @override
  Widget build(BuildContext context) {
    if (HoloThemeExt.of(context) == null) {
      return SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: title,
        subtitle: subtitle,
        secondary: secondary,
        contentPadding: contentPadding,
        dense: dense,
      );
    }
    final enabled = onChanged != null;
    return ListTile(
      leading: secondary,
      title: title,
      subtitle: subtitle,
      contentPadding: contentPadding,
      dense: dense,
      enabled: enabled,
      trailing: HoloSwitch(value: value, onChanged: onChanged),
      onTap: enabled ? () => onChanged!(!value) : null,
    );
  }
}

/// Заголовок раздела. В Holo — разделитель списка
/// (Widget.Holo.TextView.ListSeparator): ЗАГЛАВНЫЕ, жирный 14sp, вторичный
/// цвет текста, линия 2dp снизу во всю ширину. Иначе — Text со стилем
/// [style] (по умолчанию titleMedium), как было.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final p = HoloThemeExt.of(context);
    if (p == null) {
      return Text(text,
          style: style ?? Theme.of(context).textTheme.titleMedium);
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.sectionLine, width: 2)),
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: p.textSecondary,
        ),
      ),
    );
  }
}

/// Вкладка с текстом. В Holo подпись ЗАГЛАВНЫМИ (Widget.Holo.ActionBar.TabText:
/// textAllCaps, 12sp bold — размер и вес задаёт TabBarTheme).
class StyledTab extends StatelessWidget implements PreferredSizeWidget {
  const StyledTab({super.key, required this.text});

  final String text;

  @override
  Size get preferredSize => const Tab(text: '').preferredSize;

  @override
  Widget build(BuildContext context) {
    final holo = HoloThemeExt.of(context) != null;
    return Tab(text: holo ? text.toUpperCase() : text);
  }
}

/// Диалог. В Holo — AlertDialog Android 4.x: голубой заголовок 22sp с
/// голубой чертой 2dp под ним, кнопки во всю ширину внизу, разделённые
/// тонкими линиями. Иначе — обычный [AlertDialog] с теми же параметрами.
class StyledAlertDialog extends StatelessWidget {
  const StyledAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.contentPadding,
    this.actionsAlignment,
    this.actionsPadding,
    this.actionsOverflowDirection,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? contentPadding;
  final MainAxisAlignment? actionsAlignment;
  final EdgeInsetsGeometry? actionsPadding;
  final VerticalDirection? actionsOverflowDirection;

  @override
  Widget build(BuildContext context) {
    final p = HoloThemeExt.of(context);
    if (p == null) {
      return AlertDialog(
        title: title,
        content: content,
        actions: actions,
        contentPadding: contentPadding,
        actionsAlignment: actionsAlignment,
        actionsPadding: actionsPadding,
        actionsOverflowDirection: actionsOverflowDirection,
      );
    }
    final theme = Theme.of(context);
    final acts = actions ?? const <Widget>[];
    // Кнопки диалога Holo — плоские (Widget.Holo.Button.Borderless), в том
    // числе «главная»: FilledButton/ElevatedButton здесь без подложки.
    final flat = (theme.textButtonTheme.style ?? const ButtonStyle()).copyWith(
      backgroundColor: ButtonStyleButton.allOrNull<Color>(Colors.transparent),
      foregroundColor: ButtonStyleButton.allOrNull<Color>(p.textPrimary),
      elevation: ButtonStyleButton.allOrNull<double>(0),
      shape: ButtonStyleButton.allOrNull<OutlinedBorder>(
          const RoundedRectangleBorder()),
    );
    final actionsTheme = theme.copyWith(
      textButtonTheme: TextButtonThemeData(style: flat),
      filledButtonTheme: FilledButtonThemeData(style: flat),
      elevatedButtonTheme: ElevatedButtonThemeData(style: flat),
    );
    return Dialog(
      backgroundColor: p.panel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2))),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: DefaultTextStyle(
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: HoloPalette.blue),
                  child: title!,
                ),
              ),
              Container(height: 2, color: HoloPalette.blue),
            ],
            if (content != null)
              Flexible(
                child: Padding(
                  padding: contentPadding ??
                      const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: DefaultTextStyle(
                    style: theme.textTheme.bodyMedium!
                        .copyWith(fontSize: 16, color: p.textPrimary),
                    child: content!,
                  ),
                ),
              ),
            if (acts.isNotEmpty) ...[
              Container(height: 1, color: p.listDivider),
              Theme(
                data: actionsTheme,
                child: SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      for (var i = 0; i < acts.length; i++) ...[
                        if (i > 0) Container(width: 1, color: p.listDivider),
                        Expanded(
                          child: SizedBox.expand(child: acts[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
