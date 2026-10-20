import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design/app_colors.dart';
import 'design/tokens.dart';

export 'design/app_colors.dart';
export 'design/tokens.dart';

/// **过渡期兼容层**——这里全是写死的亮色值，深色主题下会画出白块。
///
/// 新代码请改用 `AppColors.xxx(brightness)`；
/// 本类会随 UI 升级逐文件清空，**不要再新增引用**。
class AppThemeTokens {
  static const canvas = Color(0xFFF8FAFF);
  static const canvasTint = Color(0xFFEFF7FF);
  static const surface = Colors.white;
  static const surfaceSoft = Color(0xFFF0F9FF);
  static const surfaceMuted = Color(0xFFE5F2FF);
  static const primary = Color(0xFF0E7490);
  static const primaryStrong = Color(0xFF005A71);
  static const primarySoft = Color(0xFFB9EAFF);
  static const textPrimary = Color(0xFF0B1C30);
  static const textSecondary = Color(0xFF5C7386);
  static const border = Color(0xFFD7E7F7);
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
  return GoogleFonts.manropeTextTheme().copyWith(
    headlineLarge: GoogleFonts.manrope(
      fontSize: AppFontSize.display,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
      color: primaryColor,
    ),
    headlineMedium: GoogleFonts.manrope(
      fontSize: AppFontSize.headline,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: primaryColor,
    ),
    titleLarge: GoogleFonts.manrope(
      fontSize: AppFontSize.headline,
      fontWeight: FontWeight.w700,
      color: primaryColor,
    ),
    titleMedium: GoogleFonts.manrope(
      fontSize: AppFontSize.title,
      fontWeight: FontWeight.w700,
      color: primaryColor,
    ),
    bodyLarge: GoogleFonts.manrope(
      fontSize: AppFontSize.body,
      height: 1.45,
      color: primaryColor,
    ),
    bodyMedium: GoogleFonts.manrope(
      fontSize: AppFontSize.bodySm,
      height: 1.45,
      color: primaryColor,
    ),
    bodySmall: GoogleFonts.manrope(
      fontSize: AppFontSize.label,
      height: 1.4,
      color: AppColors.textSecondary(brightness),
    ),
    labelLarge: GoogleFonts.manrope(
      fontSize: AppFontSize.label,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: AppColors.primaryStrong(brightness),
    ),
    labelMedium: GoogleFonts.manrope(
      fontSize: AppFontSize.micro,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.2,
      color: AppColors.primaryStrong(brightness),
    ),
    labelSmall: GoogleFonts.manrope(
      fontSize: AppFontSize.caption,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: AppColors.primaryStrong(brightness),
    ),
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
        primaryContainer: isDark
            ? AppColors.primarySoft(brightness)
            : const Color(0xFFD9F1FF),
        onPrimaryContainer: isDark
            ? AppColors.textPrimary(brightness)
            : AppColors.primaryStrong(brightness),
        secondary: AppColors.primarySoft(brightness),
        onSecondary: AppColors.primaryStrong(brightness),
        surface: AppColors.surface(brightness),
        onSurface: AppColors.textPrimary(brightness),
        surfaceContainerLowest: AppColors.canvas(brightness),
        surfaceContainerLow: AppColors.surface(brightness),
        surfaceContainer: AppColors.surfaceSoft(brightness),
        surfaceContainerHigh: AppColors.surfaceMuted(brightness),
        surfaceContainerHighest: AppColors.surfaceHigh(brightness),
        outline: AppColors.border(brightness),
        outlineVariant: AppColors.borderStrong(brightness),
        error: AppColors.dangerText(brightness),
        onError: isDark ? const Color(0xFF3D1A1A) : Colors.white,
      );

  return ThemeData(
    useMaterial3: true,
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
      contentTextStyle: GoogleFonts.manrope(
        color: AppColors.textPrimary(brightness),
      ),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceSoft(brightness),
      labelStyle: GoogleFonts.manrope(
        fontSize: AppFontSize.label,
        color: AppColors.primaryStrong(brightness),
        fontWeight: FontWeight.w700,
      ),
      selectedColor: AppColors.primarySoft(brightness),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.fullAll),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceSoft(brightness),
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: AppColors.textTertiary(brightness),
      ),
      labelStyle: textTheme.labelMedium,
      border: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.border(brightness)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.border(brightness)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.mdAll,
        borderSide: BorderSide(color: AppColors.primary(brightness), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryContainer(brightness),
        foregroundColor: AppColors.onPrimaryContainer(brightness),
        textStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.sm,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary(brightness),
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface(brightness),
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.primaryStrong(brightness),
        backgroundColor: AppColors.surfaceSoft(brightness),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
      ),
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      textColor: AppColors.textPrimary(brightness),
      iconColor: AppColors.primaryStrong(brightness),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh(brightness),
        borderRadius: AppRadius.xsAll,
        border: Border.all(color: AppColors.border(brightness)),
      ),
      textStyle: GoogleFonts.manrope(
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
