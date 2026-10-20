import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design/app_colors.dart';
import 'design/tokens.dart';

/// 语义色令牌。
///
/// 保留原有 API 名称与亮色色值，避免全库一次性大改引入回归；
/// 新代码请优先用 `AppColors` + `Theme.of(context).colorScheme`，
/// 以获得亮/暗自动切换能力。
class AppThemeTokens {
  const AppThemeTokens._();

  static const canvas = AppColors.canvasLight;
  static const canvasTint = AppColors.canvasTintLight;
  static const surface = AppColors.surfaceLight;
  static const surfaceSoft = AppColors.surfaceSoftLight;
  static const surfaceMuted = AppColors.surfaceMutedLight;
  static const primary = AppColors.primaryLight;
  static const primaryStrong = AppColors.primaryStrongLight;
  static const primarySoft = AppColors.primarySoftLight;
  static const textPrimary = AppColors.textPrimaryLight;
  static const textSecondary = AppColors.textSecondaryLight;
  static const border = AppColors.borderLight;

  static const warningSurface = AppColors.warningSurfaceLight;
  static const warningText = AppColors.warningTextLight;
  static const dangerSurface = AppColors.dangerSurfaceLight;
  static const dangerText = AppColors.dangerTextLight;

  static const successSurface = AppColors.successSurfaceLight;
  static const successText = AppColors.successTextLight;
  static const infoSurface = AppColors.infoSurfaceLight;
  static const infoText = AppColors.infoTextLight;
  static const neutralSurface = AppColors.neutralSurfaceLight;
  static const neutralText = AppColors.neutralTextLight;
}

/// 装饰工具。圆角 / 阴影全部引用 [AppRadius] / [AppShadow]。
class AppDecorations {
  const AppDecorations._();

  /// 图卡常态阴影
  static List<BoxShadow> get cardShadow => AppShadow.card;

  /// 悬停 / 浮层阴影
  static List<BoxShadow> get softShadow => AppShadow.raised;

  /// 浮层阴影（与 [softShadow] 同档，保留旧名）
  static List<BoxShadow> get floatingShadow => AppShadow.raised;

  /// 底部输入栏阴影：中性色，不随主色染色
  static List<BoxShadow> get inputShadow => AppShadow.input;

  static BoxDecoration card({
    double radius = AppRadius.md,
    Color color = AppColors.surfaceLight,
    Color? borderColor,
    List<BoxShadow>? shadow,
    Brightness brightness = Brightness.light,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ?? AppColors.border(brightness),
        width: 0.5,
      ),
      boxShadow: shadow ?? AppShadow.card,
    );
  }

  static BoxDecoration glass({
    double radius = AppRadius.lg,
    Brightness brightness = Brightness.light,
  }) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      color: AppColors.surface(brightness).withValues(
        alpha: AppOpacity.glassFill,
      ),
      border: Border.all(
        color: AppColors.border(brightness),
        width: 0.5,
      ),
      boxShadow: AppShadow.input,
    );
  }
}

TextTheme _buildTextTheme(Color textPrimary, Color textSecondary) {
  TextStyle style(double size, FontWeight weight, Color color, {double? height}) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      height: height,
      color: color,
    );
  }

  return TextTheme(
    displaySmall: style(
      AppFontSize.displaySm,
      FontWeight.w700,
      textPrimary,
      height: 1.2,
    ),
    headlineLarge: style(
      AppFontSize.displaySm,
      FontWeight.w700,
      textPrimary,
      height: 1.2,
    ),
    headlineMedium: style(
      AppFontSize.titleLg,
      FontWeight.w700,
      textPrimary,
      height: 1.25,
    ),
    titleLarge: style(AppFontSize.titleLg, FontWeight.w700, textPrimary),
    titleMedium: style(AppFontSize.titleMd, FontWeight.w700, textPrimary),
    titleSmall: style(AppFontSize.bodyLg, FontWeight.w600, textPrimary),
    bodyLarge: style(AppFontSize.bodyLg, FontWeight.w400, textPrimary,
        height: 1.45),
    bodyMedium: style(AppFontSize.bodyMd, FontWeight.w400, textPrimary,
        height: 1.45),
    bodySmall: style(AppFontSize.labelMd, FontWeight.w400, textSecondary,
        height: 1.4),
    labelLarge: GoogleFonts.inter(
      fontSize: AppFontSize.bodyLg,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
      color: textPrimary,
    ),
    labelMedium: GoogleFonts.inter(
      fontSize: AppFontSize.labelMd,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: textPrimary,
    ),
    labelSmall: GoogleFonts.inter(
      fontSize: AppFontSize.labelSm,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
      color: textSecondary,
    ),
  );
}

ThemeData _buildBase(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final canvas = AppColors.canvas(brightness);
  final surface = AppColors.surface(brightness);
  final surfaceSoft = AppColors.surfaceSoft(brightness);
  final surfaceMuted = AppColors.surfaceMuted(brightness);
  final primary = AppColors.primary(brightness);
  final textPrimary = AppColors.textPrimary(brightness);
  final textSecondary = AppColors.textSecondary(brightness);
  final borderColor = AppColors.border(brightness);

  // 暗色下主色是亮青色，白字对比度不足，按钮文字改用深墨色。
  final onPrimary = isDark ? const Color(0xFF04222B) : Colors.white;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
  ).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    secondary: AppColors.primarySoft(brightness),
    onSecondary: AppColors.primaryStrong(brightness),
    surface: surface,
    onSurface: textPrimary,
    surfaceContainerHighest: surfaceMuted,
    surfaceContainerHigh: surfaceMuted,
    surfaceContainer: surfaceSoft,
    surfaceContainerLow: surface,
    outline: borderColor,
    outlineVariant: borderColor,
    error: AppColors.dangerText(brightness),
    onError: isDark ? const Color(0xFF2B0A0A) : Colors.white,
  );

  final textTheme = _buildTextTheme(textPrimary, textSecondary);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: canvas,
    canvasColor: canvas,
    cardColor: surface,
    dividerColor: borderColor,
    textTheme: textTheme,
    // 焦点可见：桌面端必须能看出焦点在哪
    focusColor: primary.withValues(alpha: AppOpacity.press),
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    dividerTheme: DividerThemeData(
      color: borderColor,
      thickness: 0.5,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark
          ? AppColors.surfaceMuted(brightness)
          : AppColors.primaryStrong(brightness),
      contentTextStyle: GoogleFonts.manrope(
        fontSize: AppFontSize.bodyMd,
        color: isDark ? textPrimary : Colors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceSoft,
      selectedColor: AppColors.primarySoft(brightness),
      labelStyle: GoogleFonts.inter(
        fontSize: AppFontSize.labelMd,
        color: AppColors.primaryStrong(brightness),
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: textTheme.bodyMedium?.copyWith(
        color: textSecondary.withValues(alpha: 0.9),
      ),
      labelStyle: textTheme.labelMedium?.copyWith(color: textSecondary),
      floatingLabelStyle: textTheme.labelMedium?.copyWith(
        color: AppColors.primary(brightness),
      ),
      border: _inputBorder(borderColor),
      enabledBorder: _inputBorder(borderColor),
      focusedBorder: _inputBorder(primary, width: 1.5),
      errorBorder: _inputBorder(AppColors.dangerText(brightness)),
      focusedErrorBorder: _inputBorder(AppColors.dangerText(brightness),
          width: 1.5),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: onPrimary,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        textStyle: textTheme.labelLarge,
        minimumSize: const Size(0, 40),
        side: BorderSide(color: borderColor),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.xs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: textTheme.labelLarge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: AppColors.primaryStrong(brightness),
        // 现状强制白底导致暗色下出现白色方块，改为仅 hover 时出底
        backgroundColor: Colors.transparent,
        highlightColor: AppStateLayer.press(primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: borderColor, width: 0.5),
      ),
      textStyle: textTheme.bodyMedium,
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(surface),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: borderColor, width: 0.5),
          ),
        ),
        padding: const WidgetStatePropertyAll<EdgeInsets>(
          EdgeInsets.symmetric(vertical: AppSpace.xxs),
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: surface,
      showDragHandle: true,
      dragHandleColor: textSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: isDark ? surfaceMuted : AppColors.textPrimary(brightness),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      textStyle: GoogleFonts.manrope(
        fontSize: AppFontSize.labelSm,
        color: isDark ? textPrimary : canvas,
      ),
      waitDuration: const Duration(milliseconds: 500),
    ),
    scrollbarTheme: ScrollbarThemeData(
      // 现状无滚动条，桌面端图墙无法定位
      thumbVisibility: const WidgetStatePropertyAll<bool>(false),
      thickness: const WidgetStatePropertyAll<double>(9),
      radius: const Radius.circular(AppRadius.full),
      thumbColor: WidgetStatePropertyAll<Color>(
        borderColor.withValues(alpha: 0.9),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primary,
      inactiveTrackColor: surfaceMuted,
      thumbColor: primary,
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? onPrimary : surface),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? primary
            : surfaceMuted,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: surfaceMuted,
      circularTrackColor: surfaceMuted,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: 0,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      iconColor: AppColors.primaryStrong(brightness),
    ),
  );
}

OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.sm),
    borderSide: BorderSide(color: color, width: width),
  );
}

ThemeData buildAppTheme() => _buildBase(Brightness.light);

ThemeData buildAppDarkTheme() => _buildBase(Brightness.dark);