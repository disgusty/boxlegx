import 'package:flutter/material.dart';

/// Акцентные цвета для стилей Material 3 и Material 1 — основные цвета
/// палитры Material Design 2014. Material 3 строит из выбранного цвета
/// схему (seed), Material 1 красит им панель приложения и элементы.
/// Фон в обоих стилях от акцента не зависит; Holo акцент не использует.
///
/// Файл общий для веток main и legacy-api17.
abstract final class AccentPalette {
  /// По умолчанию — Indigo: исходный вид LxBox.
  static const MaterialColor defaultColor = Colors.indigo;

  static const List<MaterialColor> colors = [
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.brown,
    Colors.blueGrey,
  ];

  /// Цвет по сохранённому номеру в [colors]; неизвестный — по умолчанию.
  static MaterialColor byIndex(int? index) =>
      index != null && index >= 0 && index < colors.length
          ? colors[index]
          : defaultColor;

  /// Тёмный текст поверх цвета (светлые оттенки: lime, amber, lightGreen…).
  static bool needsDarkForeground(MaterialColor c) =>
      ThemeData.estimateBrightnessForColor(c.shade500) == Brightness.light;
}
