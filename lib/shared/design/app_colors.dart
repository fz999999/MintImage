import 'package:flutter/material.dart';

/// 语义色。亮 / 暗两套，随 `ThemeMode` 自动切换。
///
/// 现状问题：47 处硬编码颜色、token 定义了却不用（例如 `_NewVersionBadge`
/// 在 home_page.dart 里自己写了 `#E4F6EE` / `#93D7B5` / `#177245`）。
/// 这里补齐成功 / 信息 / 中性三组缺失语义色，并把全部颜色收敛到一处。
class AppColors {
  const AppColors._();

  // ---------------------------------------------------------------------
  // 亮色
  // ---------------------------------------------------------------------

  static const Color canvasLight = Color(0xFFF8FAFF);
  static const Color canvasTintLight = Color(0xFFEFF7FF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceSoftLight = Color(0xFFF0F9FF);
  static const Color surfaceMutedLight = Color(0xFFE5F2FF);
  static const Color primaryLight = Color(0xFF0E7490);
  static const Color primaryStrongLight = Color(0xFF005A71);
  static const Color primarySoftLight = Color(0xFFB9EAFF);
  static const Color textPrimaryLight = Color(0xFF0B1C30);
  static const Color textSecondaryLight = Color(0xFF5C7386);
  static const Color borderLight = Color(0xFFD7E7F7);
  static const Color borderStrongLight = Color(0xFFB9D5EC);

  // 暗色：底色抬升到蓝灰区间，文字提到高对比档
  static const Color canvasDark = Color(0xFF0F172A);
  static const Color canvasTintDark = Color(0xFF131C2E);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceSoftDark = Color(0xFF243349);
  static const Color surfaceMutedDark = Color(0xFF2B3B53);
  static const Color primaryDark = Color(0xFF22D3EE);
  static const Color primaryStrongDark = Color(0xFF67E8F9);
  static const Color primarySoftDark = Color(0xFF164E63);
  static const Color textPrimaryDark = Color(0xFFE2E8F0);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color borderDark = Color(0xFF334155);
  static const Color borderStrongDark = Color(0xFF475569);

  // ---------------------------------------------------------------------
  // 状态语义色（亮色）
  // ---------------------------------------------------------------------

  static const Color successSurfaceLight = Color(0xFFE4F6EE);
  static const Color successTextLight = Color(0xFF177245);
  static const Color successBorderLight = Color(0xFF93D7B5);

  static const Color infoSurfaceLight = Color(0xFFE8F3FF);
  static const Color infoTextLight = Color(0xFF1667C5);
  static const Color infoBorderLight = Color(0xFFA8CFF0);

  static const Color warningSurfaceLight = Color(0xFFFFF3D9);
  static const Color warningTextLight = Color(0xFF9A6400);
  static const Color warningBorderLight = Color(0xFFEFD08A);

  static const Color dangerSurfaceLight = Color(0xFFFFE7E7);
  static const Color dangerTextLight = Color(0xFFAA2E2E);
  static const Color dangerBorderLight = Color(0xFFF3B4B4);

  static const Color neutralSurfaceLight = Color(0xFFF1F5F9);
  static const Color neutralTextLight = Color(0xFF475569);

  // 收藏星标：现状散落 Colors.orange.shade700 / shade800，统一为品牌琥珀
  static const Color favoriteLight = Color(0xFFB45309);
  static const Color favoriteDark = Color(0xFFFBBF24);

  // ---------------------------------------------------------------------
  // 状态语义色（暗色）
  // ---------------------------------------------------------------------

  static const Color successSurfaceDark = Color(0xFF12372A);
  static const Color successTextDark = Color(0xFF6EE7B7);
  static const Color successBorderDark = Color(0xFF1D6B4F);

  static const Color infoSurfaceDark = Color(0xFF12304F);
  static const Color infoTextDark = Color(0xFF7DD3FC);
  static const Color infoBorderDark = Color(0xFF1D5480);

  static const Color warningSurfaceDark = Color(0xFF3B2E0E);
  static const Color warningTextDark = Color(0xFFFCD34D);
  static const Color warningBorderDark = Color(0xFF7A5F14);

  static const Color dangerSurfaceDark = Color(0xFF3D1A1A);
  static const Color dangerTextDark = Color(0xFFFCA5A5);
  static const Color dangerBorderDark = Color(0xFF7F2E2E);

  static const Color neutralSurfaceDark = Color(0xFF1F2937);
  static const Color neutralTextDark = Color(0xFFCBD5E1);

  // ---------------------------------------------------------------------
  // 按亮度取色
  // ---------------------------------------------------------------------

  static Color canvas(Brightness b) =>
      b == Brightness.dark ? canvasDark : canvasLight;
  static Color canvasTint(Brightness b) =>
      b == Brightness.dark ? canvasTintDark : canvasTintLight;
  static Color surface(Brightness b) =>
      b == Brightness.dark ? surfaceDark : surfaceLight;
  static Color surfaceSoft(Brightness b) =>
      b == Brightness.dark ? surfaceSoftDark : surfaceSoftLight;
  static Color surfaceMuted(Brightness b) =>
      b == Brightness.dark ? surfaceMutedDark : surfaceMutedLight;
  static Color primary(Brightness b) =>
      b == Brightness.dark ? primaryDark : primaryLight;
  static Color primaryStrong(Brightness b) =>
      b == Brightness.dark ? primaryStrongDark : primaryStrongLight;
  static Color primarySoft(Brightness b) =>
      b == Brightness.dark ? primarySoftDark : primarySoftLight;
  static Color textPrimary(Brightness b) =>
      b == Brightness.dark ? textPrimaryDark : textPrimaryLight;
  static Color textSecondary(Brightness b) =>
      b == Brightness.dark ? textSecondaryDark : textSecondaryLight;
  static Color border(Brightness b) =>
      b == Brightness.dark ? borderDark : borderLight;
  static Color borderStrong(Brightness b) =>
      b == Brightness.dark ? borderStrongDark : borderStrongLight;

  static Color successSurface(Brightness b) =>
      b == Brightness.dark ? successSurfaceDark : successSurfaceLight;
  static Color successText(Brightness b) =>
      b == Brightness.dark ? successTextDark : successTextLight;
  static Color successBorder(Brightness b) =>
      b == Brightness.dark ? successBorderDark : successBorderLight;

  static Color infoSurface(Brightness b) =>
      b == Brightness.dark ? infoSurfaceDark : infoSurfaceLight;
  static Color infoText(Brightness b) =>
      b == Brightness.dark ? infoTextDark : infoTextLight;
  static Color infoBorder(Brightness b) =>
      b == Brightness.dark ? infoBorderDark : infoBorderLight;

  static Color warningSurface(Brightness b) =>
      b == Brightness.dark ? warningSurfaceDark : warningSurfaceLight;
  static Color warningText(Brightness b) =>
      b == Brightness.dark ? warningTextDark : warningTextLight;
  static Color warningBorder(Brightness b) =>
      b == Brightness.dark ? warningBorderDark : warningBorderLight;

  static Color dangerSurface(Brightness b) =>
      b == Brightness.dark ? dangerSurfaceDark : dangerSurfaceLight;
  static Color dangerText(Brightness b) =>
      b == Brightness.dark ? dangerTextDark : dangerTextLight;
  static Color dangerBorder(Brightness b) =>
      b == Brightness.dark ? dangerBorderDark : dangerBorderLight;

  static Color neutralSurface(Brightness b) =>
      b == Brightness.dark ? neutralSurfaceDark : neutralSurfaceLight;
  static Color neutralText(Brightness b) =>
      b == Brightness.dark ? neutralTextDark : neutralTextLight;

  static Color favorite(Brightness b) =>
      b == Brightness.dark ? favoriteDark : favoriteLight;
}

/// 悬停 / 按下态底色。桌面端鼠标是一等公民，需要统一的状态反馈。
class AppStateLayer {
  const AppStateLayer._();

  static Color hover(Color base) =>
      base.withValues(alpha: base.computeLuminance() > 0.5 ? 0.06 : 0.08);

  static Color press(Color base) =>
      base.withValues(alpha: base.computeLuminance() > 0.5 ? 0.12 : 0.14);

  static Color scrim(Brightness b) =>
      b == Brightness.dark ? const Color(0xB3000000) : const Color(0xB8000000);
}