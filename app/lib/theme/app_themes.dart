import 'package:flutter/material.dart';

import 'app_style.dart';

/// Темы трёх стилей интерфейса.
///
/// - Material 3 — исходный вид L×Box (seed indigo, `useMaterial3: true`).
/// - Material 1 — Material Design 2014 (Android 5.0): палитра Indigo 500 /
///   Pink A200, типографика material2014, тени-elevation, углы 2dp,
///   чернильная волна (InkRipple), переход «fade upwards».
/// - Holo — Android Design 4.0 (ICS/JB): Holo Blue #33B5E5, тёмная панель
///   действий, плоские поверхности без теней, углы 2dp, нажатие — заливка
///   голубым без волны, табы с голубой полосой-индикатором.
///
/// Цвета Material 1 — из палитры Material Design 2014 (Indigo 500 #3F51B5,
/// Indigo 700 #303F9F, Pink A200 #FF4081; тёмная тема: фон #303030,
/// карточки/диалоги #424242, панель #212121). Цвета Holo — из ресурсов
/// фреймворка Android 4.x (`holo_blue_light` #33B5E5, `holo_blue_dark`
/// #0099CC, `background_holo_dark` #000000, `background_holo_light` #F3F3F3,
/// `bright_foreground_holo_dark` #F3F3F3, `dim_foreground_holo_dark` #BEBEBE,
/// `holo_red_light` #FF4444, `holo_orange_light` #FFBB33, `holo_green_light`
/// #99CC00).
ThemeData buildAppTheme(
  UiStyle style,
  Brightness brightness, {
  required bool reduceMotion,
}) {
  final theme = switch (style) {
    UiStyle.material3 => _material3(brightness, reduceMotion),
    UiStyle.material1 => _material1(brightness),
    UiStyle.holo => _holo(brightness),
  };
  if (!reduceMotion) return theme;
  // Упрощённые анимации: экраны открываются мгновенно — без перерисовки
  // двух страниц с прозрачностью/сдвигом в каждом кадре перехода.
  return theme.copyWith(
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _InstantPageTransitionsBuilder(),
      TargetPlatform.iOS: _InstantPageTransitionsBuilder(),
      TargetPlatform.linux: _InstantPageTransitionsBuilder(),
      TargetPlatform.macOS: _InstantPageTransitionsBuilder(),
      TargetPlatform.windows: _InstantPageTransitionsBuilder(),
      TargetPlatform.fuchsia: _InstantPageTransitionsBuilder(),
    }),
  );
}

class _InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const _InstantPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      child;
}

// ─────────────────────────────── Material 3 ───────────────────────────────

ThemeData _material3(Brightness brightness, bool reduceMotion) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: brightness,
      ),
      useMaterial3: true,
      // InkSparkle (дефолт M3 на Android) — фрагментный шейдер на каждое
      // нажатие; на слабых GPU заметно дороже обычной волны.
      splashFactory: reduceMotion ? InkRipple.splashFactory : null,
    );

// ─────────────────────────────── Material 1 ───────────────────────────────

const _indigo500 = Color(0xFF3F51B5);
const _indigo700 = Color(0xFF303F9F);
const _indigo100 = Color(0xFFC5CAE9);
const _indigo200 = Color(0xFF9FA8DA);
const _indigo900 = Color(0xFF1A237E);
const _pinkA200 = Color(0xFFFF4081);
const _red500 = Color(0xFFF44336);
const _red300 = Color(0xFFE57373);
const _amber500 = Color(0xFFFFC107);

ThemeData _material1(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final cs = dark
      ? const ColorScheme(
          brightness: Brightness.dark,
          primary: _indigo200,
          onPrimary: _indigo900,
          primaryContainer: _indigo700,
          onPrimaryContainer: Color(0xFFE8EAF6),
          secondary: _pinkA200,
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFF880E4F),
          onSecondaryContainer: Color(0xFFF8BBD0),
          tertiary: _amber500,
          onTertiary: Colors.black,
          tertiaryContainer: Color(0xFF6F5300),
          onTertiaryContainer: Color(0xFFFFECB3),
          error: _red300,
          onError: Colors.black,
          errorContainer: Color(0xFF8C1D18),
          onErrorContainer: Color(0xFFFFCDD2),
          surface: Color(0xFF303030),
          background: Color(0xFF303030),
          onSurface: Colors.white,
          onBackground: Colors.white,
          onSurfaceVariant: Color(0xB3FFFFFF),
          surfaceVariant: Color(0xFF545454),
          outline: Color(0xFF8A8A8A),
          outlineVariant: Color(0xFF5C5C5C),
          inverseSurface: Color(0xFFFAFAFA),
          onInverseSurface: Color(0xDE000000),
          inversePrimary: _indigo500,
          shadow: Colors.black,
          scrim: Colors.black,
          surfaceTint: Colors.transparent,
        )
      : const ColorScheme(
          brightness: Brightness.light,
          primary: _indigo500,
          onPrimary: Colors.white,
          primaryContainer: _indigo100,
          onPrimaryContainer: _indigo900,
          secondary: _pinkA200,
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFF8BBD0),
          onSecondaryContainer: Color(0xFF880E4F),
          tertiary: Color(0xFFFF8F00),
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFFFECB3),
          onTertiaryContainer: Color(0xFF5D3A00),
          error: _red500,
          onError: Colors.white,
          errorContainer: Color(0xFFFFCDD2),
          onErrorContainer: Color(0xFFB71C1C),
          surface: Color(0xFFFAFAFA),
          background: Color(0xFFFAFAFA),
          onSurface: Color(0xDE000000),
          onBackground: Color(0xDE000000),
          onSurfaceVariant: Color(0x8A000000),
          surfaceVariant: Color(0xFFE0E0E0),
          outline: Color(0xFF9E9E9E),
          outlineVariant: Color(0xFFE0E0E0),
          inverseSurface: Color(0xFF323232),
          onInverseSurface: Colors.white,
          inversePrimary: _indigo200,
          shadow: Colors.black,
          scrim: Colors.black,
          surfaceTint: Colors.transparent,
        );

  // Material 1: углы 2dp у кнопок, карточек, диалогов, меню.
  const r2 = BorderRadius.all(Radius.circular(2));
  const shape2 = RoundedRectangleBorder(borderRadius: r2);
  final barBg = dark ? const Color(0xFF212121) : _indigo500;
  final cardBg = dark ? const Color(0xFF424242) : Colors.white;
  final typography = Typography.material2014(platform: TargetPlatform.android);
  final textTheme = dark ? typography.white : typography.black;
  // Кнопки — ЗАГЛАВНЫМИ? Flutter не умеет text-transform темой, поэтому
  // отличие держим на весе Roboto Medium и цветах спецификации.
  const buttonText = TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
      letterSpacing: 0.5);

  return ThemeData(
    useMaterial3: false,
    brightness: brightness,
    colorScheme: cs,
    typography: typography,
    textTheme: textTheme,
    primaryColor: _indigo500,
    primaryColorDark: _indigo700,
    scaffoldBackgroundColor: cs.surface,
    canvasColor: cs.surface,
    cardColor: cardBg,
    dividerColor: dark ? const Color(0x1FFFFFFF) : const Color(0x1F000000),
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: barBg,
      foregroundColor: Colors.white,
      elevation: 4,
      scrolledUnderElevation: 4,
      centerTitle: false,
      titleTextStyle: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Color(0xB3FFFFFF),
      indicatorColor: _pinkA200,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelStyle: buttonText,
      unselectedLabelStyle: buttonText,
    ),
    cardTheme: CardTheme(
      color: cardBg,
      elevation: 2,
      shape: shape2,
      margin: const EdgeInsets.all(4),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: cardBg,
      elevation: 24,
      shape: shape2,
    ),
    popupMenuTheme: PopupMenuThemeData(color: cardBg, elevation: 8, shape: shape2),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: cardBg, elevation: 16),
    drawerTheme: DrawerThemeData(
      backgroundColor: cardBg,
      elevation: 16,
      shape: const RoundedRectangleBorder(),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF323232),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      actionTextColor: _pinkA200,
      behavior: SnackBarBehavior.fixed,
      shape: const RoundedRectangleBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _indigo500,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: shape2,
        textStyle: buttonText,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _indigo500,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: shape2,
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: dark ? _indigo200 : _indigo500,
        shape: shape2,
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: dark ? _indigo200 : _indigo500,
        shape: shape2,
        textStyle: buttonText,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const MaterialStatePropertyAll(shape2),
        backgroundColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected) ? cs.primaryContainer : null),
        foregroundColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected) ? cs.onPrimaryContainer : null),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _pinkA200,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: CircleBorder(),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? _pinkA200
              : (dark ? const Color(0xFFBDBDBD) : const Color(0xFFF1F1F1))),
      trackColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? _pinkA200.withOpacity(0.5)
              : (dark ? const Color(0x4DFFFFFF) : const Color(0x42000000))),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? _pinkA200 : null),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2))),
    ),
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? _pinkA200 : cs.onSurfaceVariant),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: cs.secondary),
    inputDecorationTheme: InputDecorationTheme(
      border: const UnderlineInputBorder(),
      focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: cs.primary, width: 2)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
    }),
  );
}

// ────────────────────────────────── Holo ──────────────────────────────────

const _holoBlue = Color(0xFF33B5E5); // holo_blue_light
const _holoBlueDark = Color(0xFF0099CC); // holo_blue_dark
const _holoRed = Color(0xFFFF4444); // holo_red_light
const _holoRedDark = Color(0xFFCC0000); // holo_red_dark
const _holoOrange = Color(0xFFFFBB33); // holo_orange_light
const _holoOrangeDark = Color(0xFFFF8800); // holo_orange_dark
const _holoActionBar = Color(0xFF222222); // ab_solid_dark_holo

ThemeData _holo(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final cs = dark
      ? const ColorScheme(
          brightness: Brightness.dark,
          primary: _holoBlue,
          onPrimary: Colors.black,
          primaryContainer: Color(0xFF0E3B4C),
          onPrimaryContainer: Color(0xFFA6E1F5),
          secondary: _holoBlue,
          onSecondary: Colors.black,
          secondaryContainer: Color(0xFF1F2F35),
          onSecondaryContainer: Color(0xFFC8E8F4),
          tertiary: _holoOrange,
          onTertiary: Colors.black,
          tertiaryContainer: Color(0xFF4D3A10),
          onTertiaryContainer: Color(0xFFFFE2A8),
          error: _holoRed,
          onError: Colors.black,
          errorContainer: Color(0xFF5C1414),
          onErrorContainer: Color(0xFFFFC2C2),
          surface: Color(0xFF101010),
          background: Color(0xFF101010),
          onSurface: Color(0xFFF3F3F3),
          onBackground: Color(0xFFF3F3F3), // bright_foreground_holo_dark
          onSurfaceVariant: Color(0xFFBEBEBE), // dim_foreground_holo_dark
          surfaceVariant: Color(0xFF323232),
          outline: Color(0xFF6E6E6E),
          outlineVariant: Color(0xFF3A3A3A),
          inverseSurface: Color(0xFFF3F3F3),
          onInverseSurface: Colors.black,
          inversePrimary: _holoBlueDark,
          shadow: Colors.black,
          scrim: Colors.black,
          surfaceTint: Colors.transparent,
        )
      : const ColorScheme(
          brightness: Brightness.light,
          primary: _holoBlueDark,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFCDEEFA),
          onPrimaryContainer: Color(0xFF003A4F),
          secondary: _holoBlueDark,
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFDDEFF6),
          onSecondaryContainer: Color(0xFF0B3443),
          tertiary: _holoOrangeDark,
          onTertiary: Colors.white,
          tertiaryContainer: Color(0xFFFFE6C2),
          onTertiaryContainer: Color(0xFF4D2900),
          error: _holoRedDark,
          onError: Colors.white,
          errorContainer: Color(0xFFFFD6D6),
          onErrorContainer: Color(0xFF5C0000),
          surface: Color(0xFFF3F3F3),
          background: Color(0xFFF3F3F3), // background_holo_light
          onSurface: Colors.black,
          onBackground: Colors.black, // bright_foreground_holo_light
          onSurfaceVariant: Color(0xFF5A5A5A),
          surfaceVariant: Color(0xFFD9D9D9),
          outline: Color(0xFF9A9A9A),
          outlineVariant: Color(0xFFCCCCCC),
          inverseSurface: Color(0xFF282828),
          onInverseSurface: Color(0xFFF3F3F3),
          inversePrimary: _holoBlue,
          shadow: Colors.black,
          scrim: Colors.black,
          surfaceTint: Colors.transparent,
        );

  // Holo — плоский: без теней, углы 2dp, нажатие подсвечивается голубым
  // (list_selector_holo: pressed = holo_blue_light).
  const r2 = BorderRadius.all(Radius.circular(2));
  const shape2 = RoundedRectangleBorder(borderRadius: r2);
  final panelBg = dark ? const Color(0xFF282828) : Colors.white;
  final buttonBg = dark ? const Color(0xFF3A3A3A) : const Color(0xFFDDDDDD);
  final pressed = _holoBlue.withOpacity(0.6);
  final focused = _holoBlue.withOpacity(0.3);
  final hairline = BorderSide(color: cs.outlineVariant);
  final typography = Typography.material2014(platform: TargetPlatform.android);
  final base = dark ? typography.white : typography.black;
  // Roboto ICS — заголовки обычного веса, без «жирных» M3-заголовков.
  final colored = base.apply(
    bodyColor: cs.onSurface,
    displayColor: cs.onSurface,
  );
  final textTheme = colored.copyWith(
    titleLarge: colored.titleLarge?.copyWith(fontWeight: FontWeight.w400),
  );

  MaterialStateProperty<Color?> overlay() =>
      MaterialStateProperty.resolveWith((s) {
        if (s.contains(MaterialState.pressed)) return pressed;
        if (s.contains(MaterialState.focused) ||
            s.contains(MaterialState.hovered)) {
          return focused;
        }
        return null;
      });

  final flatButton = ButtonStyle(
    shape: const MaterialStatePropertyAll(shape2),
    elevation: const MaterialStatePropertyAll(0),
    overlayColor: overlay(),
    splashFactory: NoSplash.splashFactory,
    textStyle: const MaterialStatePropertyAll(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w400)),
  );

  return ThemeData(
    useMaterial3: false,
    brightness: brightness,
    colorScheme: cs,
    typography: typography,
    textTheme: textTheme,
    primaryColor: _holoBlue,
    scaffoldBackgroundColor: cs.surface,
    canvasColor: cs.surface,
    cardColor: panelBg,
    dividerColor: cs.outlineVariant,
    // Без волны: Holo подсвечивает нажатый элемент заливкой.
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: pressed,
    focusColor: focused,
    hoverColor: focused,
    // Панель действий Holo — тёмная в обеих темах (Theme.Holo.Light.DarkActionBar).
    appBarTheme: const AppBarTheme(
      backgroundColor: _holoActionBar,
      foregroundColor: Color(0xFFF3F3F3),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w400, color: Color(0xFFF3F3F3)),
      iconTheme: IconThemeData(color: Color(0xFFF3F3F3)),
      actionsIconTheme: IconThemeData(color: Color(0xFFF3F3F3)),
    ),
    // Табы ICS: подписи заглавными у Holo были, но регистр строк — дело
    // локализации; полоса-индикатор — Holo Blue на всю ширину таба.
    tabBarTheme: const TabBarTheme(
      labelColor: Color(0xFFF3F3F3),
      unselectedLabelColor: Color(0xFFBEBEBE),
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: _holoBlue, width: 4),
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: _holoBlue,
      labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      splashFactory: NoSplash.splashFactory,
    ),
    cardTheme: CardTheme(
      color: panelBg,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: r2, side: hairline),
      margin: const EdgeInsets.all(4),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: panelBg,
      elevation: 0,
      shape: shape2,
      // Заголовок диалога Holo — голубой (alert_title_holo).
      titleTextStyle: const TextStyle(
          fontSize: 22, fontWeight: FontWeight.w400, color: _holoBlue),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: panelBg,
      elevation: 2,
      shape: RoundedRectangleBorder(side: hairline),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: panelBg,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: dark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F3F3),
      elevation: 0,
      shape: const RoundedRectangleBorder(),
    ),
    listTileTheme: ListTileThemeData(selectedColor: cs.primary),
    dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1),
    // Всплывающее сообщение — в духе Toast 4.x.
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF2E2E2E),
      contentTextStyle: TextStyle(color: Color(0xFFF3F3F3), fontSize: 14),
      actionTextColor: _holoBlue,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4))),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: flatButton.copyWith(
        backgroundColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.disabled)
                ? buttonBg.withOpacity(0.5)
                : buttonBg),
        foregroundColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.disabled)
                ? cs.onSurface.withOpacity(0.38)
                : cs.onSurface),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: flatButton.copyWith(
        backgroundColor: MaterialStatePropertyAll(buttonBg),
        foregroundColor: MaterialStatePropertyAll(cs.onSurface),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: flatButton.copyWith(
        foregroundColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.disabled)
                ? cs.onSurface.withOpacity(0.38)
                : cs.onSurface),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: flatButton.copyWith(
        foregroundColor: MaterialStatePropertyAll(cs.onSurface),
        side: MaterialStatePropertyAll(BorderSide(color: cs.outline)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        overlayColor: overlay(),
        splashFactory: NoSplash.splashFactory,
        shape: const MaterialStatePropertyAll(shape2),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const MaterialStatePropertyAll(shape2),
        side: MaterialStatePropertyAll(BorderSide(color: cs.outline)),
        overlayColor: overlay(),
        splashFactory: NoSplash.splashFactory,
        backgroundColor: MaterialStateProperty.resolveWith((s) =>
            s.contains(MaterialState.selected)
                ? _holoBlue.withOpacity(0.35)
                : null),
        foregroundColor: MaterialStatePropertyAll(cs.onSurface),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: buttonBg,
      foregroundColor: _holoBlue,
      elevation: 0,
      highlightElevation: 0,
      shape: RoundedRectangleBorder(borderRadius: r2, side: hairline),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? _holoBlue
              : (dark ? const Color(0xFF9A9A9A) : const Color(0xFFBDBDBD))),
      trackColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected)
              ? _holoBlue.withOpacity(0.4)
              : (dark ? const Color(0xFF3A3A3A) : const Color(0xFFDDDDDD))),
      trackOutlineColor: const MaterialStatePropertyAll(Colors.transparent),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? _holoBlue : null),
      checkColor: const MaterialStatePropertyAll(Colors.black),
      shape: const RoundedRectangleBorder(),
    ),
    radioTheme: RadioThemeData(
      fillColor: MaterialStateProperty.resolveWith((s) =>
          s.contains(MaterialState.selected) ? _holoBlue : cs.onSurfaceVariant),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _holoBlue,
      linearTrackColor: Color(0x3333B5E5),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: _holoBlue,
      thumbColor: _holoBlue,
    ),
    // EditText Holo: подчёркивание, в фокусе — Holo Blue.
    inputDecorationTheme: InputDecorationTheme(
      border: UnderlineInputBorder(borderSide: BorderSide(color: cs.outline)),
      enabledBorder:
          UnderlineInputBorder(borderSide: BorderSide(color: cs.outline)),
      focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _holoBlue, width: 2)),
      floatingLabelStyle: const TextStyle(color: _holoBlue),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: _holoBlue,
      selectionColor: _holoBlue.withOpacity(0.4),
      selectionHandleColor: _holoBlue,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(
        color: Color(0xFF2E2E2E),
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      textStyle: TextStyle(color: Color(0xFFF3F3F3)),
    ),
    // Переход ICS — короткое затухание; при упрощённых анимациях его
    // заменяет мгновенный (см. buildAppTheme).
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: _HoloPageTransitionsBuilder(),
    }),
  );
}

/// Переход между Activity в Android 4.x — быстрое затухание с лёгким
/// масштабированием (activity_open_enter_holo).
class _HoloPageTransitionsBuilder extends PageTransitionsBuilder {
  const _HoloPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved =
        CurvedAnimation(parent: animation, curve: Curves.decelerate);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}
