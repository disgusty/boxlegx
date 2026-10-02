import 'package:flutter/material.dart';

import '../services/l10n/locale_controller.dart';

// Holo (Android 4.0–4.4) — элементы, которые не выражаются цветами темы.
//
// Значения сняты с ресурсов фреймворка Android 4.2 (AOSP jb-mr1-release,
// core/res/res): drawable/background_holo_*.xml, 9-patch-ассеты
// drawable-xhdpi/*_holo_*.9.png (цвета и толщины линий — по пикселям,
// xhdpi = 2 px на dp) и values/styles.xml (размеры шрифтов, отступы).
//
// Файл общий для веток main (Flutter 3.47) и legacy-api17 (Flutter 3.13):
// только API, которое есть в обеих версиях.

/// Палитра Holo для одной яркости.
@immutable
class HoloPalette {
  const HoloPalette._({
    required this.brightness,
    required this.windowTop,
    required this.windowBottom,
    required this.textPrimary,
    required this.textSecondary,
    required this.sectionLine,
    required this.listDivider,
    required this.fieldLine,
    required this.switchTrack,
    required this.panel,
    required this.button,
  });

  final Brightness brightness;

  /// Фон окна — вертикальный градиент (background_holo_dark/light).
  final Color windowTop;
  final Color windowBottom;

  /// bright_foreground_holo_* / dim_foreground_holo_*.
  final Color textPrimary;
  final Color textSecondary;

  /// Линия под заголовком раздела (list_section_divider_holo_*, 2dp).
  final Color sectionLine;

  /// Разделитель строк списка (list_divider_holo_*, 1dp).
  final Color listDivider;

  /// Подчёркивание поля ввода (textfield_default_holo_*, 1dp).
  final Color fieldLine;

  /// Дорожка переключателя (switch_bg_holo_*).
  final Color switchTrack;

  /// Панель диалога / меню (dialog_full_holo_*).
  final Color panel;

  /// Кнопка (btn_default_normal_holo_*): полупрозрачный серый.
  final Color button;

  static const dark = HoloPalette._(
    brightness: Brightness.dark,
    windowTop: Color(0xFF000000),
    windowBottom: Color(0xFF272D33),
    textPrimary: Color(0xFFF3F3F3),
    textSecondary: Color(0xFFBEBEBE),
    sectionLine: Color(0x33FFFFFF),
    listDivider: Color(0x26FFFFFF),
    fieldLine: Color(0x4DFFFFFF),
    switchTrack: Color(0x99333333),
    panel: Color(0xFF282828),
    button: Color(0x66999999),
  );

  static const light = HoloPalette._(
    brightness: Brightness.light,
    windowTop: Color(0xFFE8E8E8),
    windowBottom: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF323232),
    sectionLine: Color(0x33000000),
    listDivider: Color(0x1A000000),
    fieldLine: Color(0x4D000000),
    switchTrack: Color(0x4D999999),
    panel: Color(0xFFFFFFFF),
    button: Color(0x66999999),
  );

  /// holo_blue_light — главный акцент Holo.
  static const blue = Color(0xFF33B5E5);

  /// holo_blue_dark — поле ввода в фокусе, нажатия на светлом фоне.
  static const blueDark = Color(0xFF0099CC);

  LinearGradient get windowGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [windowTop, windowBottom],
      );
}

/// Маркер темы Holo: есть в ThemeData только у стиля Holo. Обёртки
/// (styled_widgets.dart) по нему решают, рисовать ли Holo-элементы, —
/// через Theme.of, поэтому смена стиля перерисовывает их сама.
@immutable
class HoloThemeExt extends ThemeExtension<HoloThemeExt> {
  const HoloThemeExt(this.palette);

  final HoloPalette palette;

  static HoloPalette? of(BuildContext context) =>
      Theme.of(context).extension<HoloThemeExt>()?.palette;

  @override
  HoloThemeExt copyWith({HoloPalette? palette}) =>
      HoloThemeExt(palette ?? this.palette);

  @override
  HoloThemeExt lerp(ThemeExtension<HoloThemeExt>? other, double t) =>
      t < 0.5 || other is! HoloThemeExt ? this : other;
}

/// Фон окна Holo под страницей (каждый маршрут рисует свой — так соседние
/// страницы не просвечивают друг через друга во время перехода).
class HoloWindowBackground extends StatelessWidget {
  const HoloWindowBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = HoloThemeExt.of(context);
    if (p == null) return child;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: p.windowGradient),
      child: child,
    );
  }
}

/// Переключатель Holo (Widget.Holo.CompoundButton.Switch): прямоугольная
/// дорожка и ползунок на половину ширины с надписью «ВКЛ»/«ВЫКЛ»; включён —
/// ползунок справа и голубой, выключен — слева и серый. switchMinWidth 96dp
/// на телефоне ужат до 88dp, чтобы помещаться рядом с текстом строки.
class HoloSwitch extends StatelessWidget {
  const HoloSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double width = 88;
  static const double height = 28;

  @override
  Widget build(BuildContext context) {
    final p = HoloThemeExt.of(context) ?? HoloPalette.dark;
    final enabled = onChanged != null;
    final on = getLocalText.s("ON");
    final off = getLocalText.s("OFF");
    // Ползунок: switch_thumb_activated_holo (голубой градиент 0099CC) и
    // switch_thumb_holo (серый градиент); надпись — secondary_text_holo_dark.
    final thumbGradient = value
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3CB1D8), Color(0xFF0099CC), Color(0xFF007EA8)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFC8C8C8), Color(0xFF9E9E9E), Color(0xFF4C4C4C)],
          );
    final thumb = Container(
      width: width / 2,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: thumbGradient,
        borderRadius: const BorderRadius.all(Radius.circular(2)),
      ),
      child: Text(
        value ? on : off,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: value ? Colors.white : const Color(0xFF1E1E1E),
        ),
      ),
    );
    return Semantics(
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        onHorizontalDragEnd: enabled
            ? (d) {
                final v = d.primaryVelocity ?? 0;
                if (v > 0 && !value) onChanged!(true);
                if (v < 0 && value) onChanged!(false);
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: p.switchTrack,
              borderRadius: const BorderRadius.all(Radius.circular(2)),
            ),
            child: Align(
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: thumb,
            ),
          ),
        ),
      ),
    );
  }
}

/// Подчёркивание поля ввода Holo (textfield_*_holo): линия по низу и
/// короткие вертикальные «засечки» на краях.
class HoloUnderlineInputBorder extends UnderlineInputBorder {
  const HoloUnderlineInputBorder({
    super.borderSide = const BorderSide(color: Color(0x4DFFFFFF)),
  });

  static const double _tick = 4;

  @override
  HoloUnderlineInputBorder copyWith({
    BorderSide? borderSide,
    BorderRadius? borderRadius,
  }) =>
      HoloUnderlineInputBorder(borderSide: borderSide ?? this.borderSide);

  @override
  HoloUnderlineInputBorder scale(double t) =>
      HoloUnderlineInputBorder(borderSide: borderSide.scale(t));

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0.0,
    double gapPercentage = 0.0,
    TextDirection? textDirection,
  }) {
    final paint = Paint()
      ..color = borderSide.color
      ..strokeWidth = borderSide.width
      ..style = PaintingStyle.stroke;
    final y = rect.bottom - borderSide.width / 2;
    canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
    canvas.drawLine(Offset(rect.left + borderSide.width / 2, y),
        Offset(rect.left + borderSide.width / 2, y - _tick), paint);
    canvas.drawLine(Offset(rect.right - borderSide.width / 2, y),
        Offset(rect.right - borderSide.width / 2, y - _tick), paint);
  }
}

/// Индикатор вкладок Holo (tab_indicator_ab_holo): у выбранной вкладки —
/// толстая голубая полоса 6dp; тонкую 1,5dp-полосу под всем рядом вкладок
/// рисует панель действий (её нижняя граница).
class HoloTabIndicator extends Decoration {
  const HoloTabIndicator();

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _HoloTabPainter();
}

class _HoloTabPainter extends BoxPainter {
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final size = cfg.size;
    if (size == null) return;
    const h = 6.0;
    canvas.drawRect(
      Rect.fromLTWH(offset.dx, offset.dy + size.height - h, size.width, h),
      Paint()..color = HoloPalette.blue,
    );
  }
}
