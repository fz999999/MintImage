import 'package:flutter/material.dart';

import 'design/app_colors.dart';
import 'design/tokens.dart';

export 'design/app_colors.dart';
export 'design/tokens.dart';

/// **过渡期兼容层**——这里全是写死的亮色值，深色主题下会画出白块。
///
/// 新代码请改用 `AppColors.xxx(brightness)`；
/// 本类会随 UI 升级逐文件清空，**不要再新增引用**。
class AppThemeTokens {
  static const canvas = Color(0xFFF5F5F5);
  static const canvasTint = Color(0xFFF2F2F2);
  static const surface = Colors.white;
  static const surfaceSoft = Color(0xFFFAFAFA);
  static const surfaceMuted = Color(0xFFF0F0F0);
  static const primary = Color(0xFF0E7490);
  static const primaryStrong = Color(0xFF005A71);
  static const primarySoft = Color(0xFFE5F2F5);
  static const textPrimary = Color(0xFF242424);
  static const textSecondary = Color(0xFF616161);
  static const border = Color(0xFFDEDEDE);
  static const warningSurface = Color(0xFFFFF3D9);
  static const warningText = Color(0xFF9A6400);
  static const dangerSurface = Color(0xFFFFE7E7);
  static const dangerText = Color(0xFFAA2E2E);
}

/// 现成的装饰：卡片 / 玻璃层。
///
/// **必须传 [brightness]**（`Theme.of(context).brightness`），
/// 否则默认按亮色画，深色下会出白卡。
class AppDecorations {
  const AppDecorations._();

  static List<BoxShadow> softShadow(Brightness brightness) =>
      AppShadow.card(brightness);

  static List<BoxShadow> floatingShadow(Brightness brightness) =>
      AppShadow.floating(brightness);

  static BoxDecoration card({
    Brightness brightness = Brightness.light,
    double radius = AppRadius.md,
    Color? color,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: AppColors.border(brightness)),
      boxShadow: AppShadow.card(brightness),
    );
  }

  static BoxDecoration glass({
    Brightness brightness = Brightness.light,
    double radius = AppRadius.lg,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.glassFill(brightness),
          AppColors.glassFill(brightness).withValues(alpha: 0.82),
        ],
      ),
      border: Border.all(color: AppColors.glassBorder(brightness)),
      boxShadow: AppShadow.floating(brightness),
    );
  }
}

TextTheme _textTheme(Brightness brightness) {
  final primaryColor = AppColors.textPrimary(brightness);
  return ThemeData(brightness: brightness).textTheme
      .copyWith(
        headlineLarge: TextStyle(
          fontSize: AppFontSize.display,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
          color: primaryColor,
        ),
        headlineMedium: TextStyle(
          fontSize: AppFontSize.headline,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: primaryColor,
        ),
        titleLarge: TextStyle(
          fontSize: AppFontSize.headline,
          fontWeight: FontWeight.w700,
          color: primaryColor,
        ),
        titleMedium: TextStyle(
          fontSize: AppFontSize.title,
          fontWeight: FontWeight.w600,
          color: primaryColor,
        ),
        bodyLarge: TextStyle(
          fontSize: AppFontSize.body,
          fontWeight: FontWeight.w400,
          height: 1.45,
          color: primaryColor,
        ),
        bodyMedium: TextStyle(
          fontSize: AppFontSize.bodySm,
          fontWeight: FontWeight.w400,
          height: 1.45,
          color: primaryColor,
        ),
        bodySmall: TextStyle(
          fontSize: AppFontSize.label,
          fontWeight: FontWeight.w400,
          height: 1.4,
          color: AppColors.textSecondary(brightness),
        ),
        labelLarge: TextStyle(
          fontSize: AppFontSize.label,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          color: AppColors.textPrimary(brightness),
        ),
        labelMedium: TextStyle(
          fontSize: AppFontSize.micro,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          color: AppColors.textPrimary(brightness),
        ),
        labelSmall: TextStyle(
          fontSize: AppFontSize.caption,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          color: AppColors.textPrimary(brightness),
        ),
      )
      .apply(
        fontFamily: 'Segoe UI',
        fontFamilyFallback: const ['Microsoft YaHei', 'sans-serif'],
      );
}

ThemeData _buildBase(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final textTheme = _textTheme(brightness);

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.primaryContainer(brightness),
        brightness: brightness,
      ).copyWith(
        primary: AppColors.primaryContainer(brightness),
        onPrimary: AppColors.onPrimaryContainer(brightness),
        primaryContainer: AppColors.primarySoft(brightness),
        onPrimaryContainer: AppColors.primaryStrong(brightness),
        secondary: AppColors.textSecondary(brightness),
        onSecondary: AppColors.surface(brightness),
        secondaryContainer: AppColors.surfaceMuted(brightness),
        onSecondaryContainer: AppColors.textPrimary(brightness),
        onSurfaceVariant: AppColors.textSecondary(brightness),
        surface: AppColors.surface(brightness),
        onSurface: AppColors.textPrimary(brightness),
        surfaceContainerLowest: AppColors.canvas(brightness),
        surfaceContainerLow: AppColors.surface(brightness),
        surfaceContainer: AppColors.surfaceSoft(brightness),
        surfaceContainerHigh: AppColors.surfaceMuted(brightness),
        surfaceContainerHighest: AppColors.surfaceHigh(brightness),
        outline: AppColors.borderStrong(brightness),
        outlineVariant: AppColors.border(brightness),
        error: AppColors.dangerText(brightness),
        onError: isDark ? const Color(0xFF3D1A1A) : Colors.white,
      );

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Segoe UI',
    fontFamilyFallback: const ['Microsoft YaHei', 'sans-serif'],
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.canvas(brightness),
    canvasColor: AppColors.canvas(brightness),
    cardColor: AppColors.surface(brightness),
    dividerColor: AppColors.border(brightness),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.textPrimary(brightness),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      iconTheme: IconThemeData(
        color: AppColors.textPrimary(brightness),
        size: AppIconSize.md,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.border(brightness),
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surfaceHigh(brightness),
      contentTextStyle: TextStyle(color: AppColors.textPrimary(brightness)),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceSoft(brightness),
      labelStyle: TextStyle(
        fontSize: AppFontSize.label,
        color: AppColors.textPrimary(brightness),
        fontWeight: FontWeight.w500,
      ),
      selectedColor: AppColors.primarySoft(brightness),
      side: BorderSide(color: AppColors.border(brightness)),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceSoft(brightness),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: AppColors.textTertiary(brightness),
      ),
      labelStyle: textTheme.labelMedium,
      border: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: AppColors.border(brightness)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(color: AppColors.border(brightness)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.smAll,
        borderSide: BorderSide(
          color: AppColors.primary(brightness),
          width: 1.4,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.xs,
      ),
    ),
    // 颜色交给控件自身的 scheme 默认值，避免覆盖 FilledButton.tonal。
    // 普通 FilledButton 使用 primary，tonal 使用 secondaryContainer。
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(64, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xxs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: AppColors.primaryContainer(brightness),
        foregroundColor: AppColors.onPrimaryContainer(brightness),
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(64, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xxs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary(brightness),
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(64, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xxs,
        ),
        side: BorderSide(color: AppColors.borderStrong(brightness)),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary(brightness),
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(64, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.sm,
          vertical: AppSpace.xxs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface(brightness),
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shadowColor: AppColors.shadowStrong(brightness),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgAll,
        side: BorderSide(color: AppColors.border(brightness)),
      ),
      textStyle: textTheme.bodyMedium,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface(brightness),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      titleTextStyle: textTheme.titleMedium,
      contentTextStyle: textTheme.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.surface(brightness),
      modalBackgroundColor: AppColors.surface(brightness),
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.borderStrong(brightness),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.textSecondary(brightness),
        minimumSize: const Size(34, 34),
        padding: const EdgeInsets.all(AppSpace.xxs),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      textColor: AppColors.textPrimary(brightness),
      iconColor: AppColors.textSecondary(brightness),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(brightness),
        borderRadius: AppRadius.xsAll,
        border: Border.all(color: AppColors.border(brightness)),
      ),
      textStyle: TextStyle(
        fontSize: AppFontSize.micro,
        color: AppColors.textPrimary(brightness),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary(brightness),
      linearTrackColor: AppColors.surfaceMuted(brightness),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll(false),
      thickness: const WidgetStatePropertyAll(9),
      radius: const Radius.circular(AppRadius.full),
      thumbColor: WidgetStatePropertyAll(AppColors.borderStrong(brightness)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.onPrimaryContainer(brightness)
            : AppColors.surface(brightness),
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primaryContainer(brightness)
            : AppColors.surfaceMuted(brightness),
      ),
    ),
  );
}

/// 亮色主题。
ThemeData buildAppTheme() => _buildBase(Brightness.light);

/// 深色主题。
ThemeData buildAppDarkTheme() => _buildBase(Brightness.dark);
