import 'package:flutter/material.dart';

/// 语义色板。
///
/// **用法**：所有界面颜色都从这里按 [Brightness] 取值，不要直接写
/// `Color(0x...)`，也不要再用 `AppThemeTokens`（那是亮色常量，深色主题下会画出白块）。
///
/// ```dart
/// final b = Theme.of(context).brightness;
/// final bg = AppColors.surface(b);
/// ```
///
/// 表面与边框采用中性灰，青色保留给主操作、选中和焦点。
/// 主色实底固定 `#0E7490`，浅主色 `#81D1F0` 用于深色文字、描边、图标。
class AppColors {
  const AppColors._();

  static bool _dark(Brightness b) => b == Brightness.dark;

  // ------------------------------------------------------------- 表面 / 容器

  /// 页面底色。
  static Color canvas(Brightness b) =>
      _dark(b) ? const Color(0xFF181818) : const Color(0xFFF5F5F5);

  /// 页面底色渐变搭档。
  static Color canvasTint(Brightness b) =>
      _dark(b) ? const Color(0xFF1C1C1C) : const Color(0xFFF2F2F2);

  /// 卡片、面板、对话框实底。
  static Color surface(Brightness b) =>
      _dark(b) ? const Color(0xFF202020) : const Color(0xFFFFFFFF);

  /// 低一档容器底（分区、输入框）。
  static Color surfaceSoft(Brightness b) =>
      _dark(b) ? const Color(0xFF252525) : const Color(0xFFFAFAFA);

  /// 高一档容器底（hover、选中）。
  static Color surfaceMuted(Brightness b) =>
      _dark(b) ? const Color(0xFF2D2D2D) : const Color(0xFFF0F0F0);

  /// 最高容器底（浮层、弹出菜单）。
  static Color surfaceHigh(Brightness b) =>
      _dark(b) ? const Color(0xFF363636) : const Color(0xFFE8E8E8);

  /// 玻璃层填充（半透明，配 `BackdropFilter`）。
  static Color glassFill(Brightness b) =>
      _dark(b) ? const Color(0xF2202020) : const Color(0xF2FFFFFF);

  /// 玻璃层描边。
  static Color glassBorder(Brightness b) =>
      _dark(b) ? const Color(0x24FFFFFF) : const Color(0x1F000000);

  /// 常规描边。
  static Color border(Brightness b) =>
      _dark(b) ? const Color(0xFF3D3D3D) : const Color(0xFFDEDEDE);

  /// 强中性描边（hover、控件边界）；焦点使用 primary。
  static Color borderStrong(Brightness b) =>
      _dark(b) ? const Color(0xFF606060) : const Color(0xFFBDBDBD);

  /// 压暗遮罩。
  static Color scrim(Brightness b) =>
      _dark(b) ? const Color(0xB30B0F11) : const Color(0xB30B1C30);

  // ------------------------------------------------------------------- 主色

  /// 主色。**深色下是"浅主色"**，用于文字/图标/描边，不要当实底。
  static Color primary(Brightness b) =>
      _dark(b) ? const Color(0xFF81D1F0) : const Color(0xFF0E7490);

  /// 主色实底（按钮、当前导航项）。亮/暗都是 `#0E7490`。
  static Color primaryContainer(Brightness b) => const Color(0xFF0E7490);

  /// 主色实底上的文字。
  static Color onPrimaryContainer(Brightness b) =>
      _dark(b) ? const Color(0xFFD3F1FF) : const Color(0xFFFFFFFF);

  /// 深一档主色（标题、图标）。
  static Color primaryStrong(Brightness b) =>
      _dark(b) ? const Color(0xFFB9EAFF) : const Color(0xFF005A71);

  /// 主色弱化底（选中项、标签底）。
  static Color primarySoft(Brightness b) =>
      _dark(b) ? const Color(0xFF203D45) : const Color(0xFFE5F2F5);

  // ------------------------------------------------------------------- 文字

  static Color textPrimary(Brightness b) =>
      _dark(b) ? const Color(0xFFF0F0F0) : const Color(0xFF242424);

  static Color textSecondary(Brightness b) =>
      _dark(b) ? const Color(0xFFC4C4C4) : const Color(0xFF616161);

  /// 第三级文字（角标、辅助说明）。
  static Color textTertiary(Brightness b) =>
      _dark(b) ? const Color(0xFF9D9D9D) : const Color(0xFF767676);

  // ---------------------------------------------------------------- 状态色

  static Color successSurface(Brightness b) =>
      _dark(b) ? const Color(0xFF12372A) : const Color(0xFFE4F6EE);
  static Color successText(Brightness b) =>
      _dark(b) ? const Color(0xFF6EE7B7) : const Color(0xFF177245);
  static Color warningSurface(Brightness b) =>
      _dark(b) ? const Color(0xFF3B2E0E) : const Color(0xFFFFF3D9);
  static Color warningText(Brightness b) =>
      _dark(b) ? const Color(0xFFFCD34D) : const Color(0xFF9A6400);
  static Color dangerSurface(Brightness b) =>
      _dark(b) ? const Color(0xFF3D1A1A) : const Color(0xFFFFE7E7);
  static Color dangerText(Brightness b) =>
      _dark(b) ? const Color(0xFFFFB4AB) : const Color(0xFFAA2E2E);
  static Color infoSurface(Brightness b) =>
      _dark(b) ? const Color(0xFF12304F) : const Color(0xFFE8F3FF);
  static Color infoText(Brightness b) =>
      _dark(b) ? const Color(0xFF93CCFF) : const Color(0xFF1667C5);
  static Color neutralSurface(Brightness b) =>
      _dark(b) ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9);
  static Color neutralText(Brightness b) =>
      _dark(b) ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

  /// 收藏星标。
  static Color favorite(Brightness b) =>
      _dark(b) ? const Color(0xFFFFB86F) : const Color(0xFFB45309);

  // ---------------------------------------------------------------- 图片浮层

  /// 全屏看图器的底色（该场景亮暗都用深色，故两值相同）。
  static Color viewerCanvas(Brightness b) => const Color(0xFF16181C);

  /// 全屏看图器的棋盘格另一色。
  static Color viewerCanvasAlt(Brightness b) => const Color(0xFF23272D);

  /// 「提示词优化」按钮的彩条渐变（亮暗通用，饱和度高，深色下也够醒目）。
  static List<Color> optimizeGradient(Brightness b) => const [
    Color(0xFFFFC857),
    Color(0xFFFF6B6B),
    Color(0xFF3B82F6),
  ];

  /// 图上角标/状态徽章的半透明底。
  static Color imageChipFill(Brightness b) =>
      _dark(b) ? const Color(0xE60B0F11) : const Color(0xEBFFFFFF);

  /// 图上角标/状态徽章的文字。
  static Color imageChipText(Brightness b) =>
      _dark(b) ? const Color(0xFFF0F0F0) : const Color(0xFF242424);

  // ------------------------------------------------------------------- 阴影

  /// 普通卡片的轻微中性投影。
  static Color shadow(Brightness b) =>
      _dark(b) ? const Color(0x24000000) : const Color(0x0A000000);

  /// 更强的投影（浮层、输入栏）。
  static Color shadowStrong(Brightness b) =>
      _dark(b) ? const Color(0x66000000) : const Color(0x24000000);
}

/// 状态叠层透明度（hover / press / 遮罩）。
class AppStateLayer {
  const AppStateLayer._();

  static const double hover = 0.06;
  static const double press = 0.12;
  static const double scrim = 0.72;

  /// 在 [base] 上叠一层 [overlay]。
  static Color over(Color base, Color overlay, double opacity) =>
      Color.alphaBlend(overlay.withValues(alpha: opacity), base);

  /// hover 叠色。
  static Color hovered(Color base, Brightness b) =>
      over(base, b == Brightness.dark ? Colors.white : Colors.black, hover);

  /// 按下叠色。
  static Color pressed(Color base, Brightness b) =>
      over(base, b == Brightness.dark ? Colors.white : Colors.black, press);
}
