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
/// 亮色基调 `#F8FAFF` 系（沿用历史配色）；深色取 Stitch 稿的中性灰
/// （`#101416` / `#181C1E` / `#1C2022` / `#272B2C` / `#313537`）。
/// 主色实底固定 `#0E7490`，浅主色 `#81D1F0` 只用于文字、描边、图标。
class AppColors {
  const AppColors._();

  static bool _dark(Brightness b) => b == Brightness.dark;

  // ------------------------------------------------------------- 表面 / 容器

  /// 页面底色。
  static Color canvas(Brightness b) =>
      _dark(b) ? const Color(0xFF101416) : const Color(0xFFF8FAFF);

  /// 页面底色渐变搭档。
  static Color canvasTint(Brightness b) =>
      _dark(b) ? const Color(0xFF14181B) : const Color(0xFFEFF7FF);

  /// 卡片、面板、对话框实底。
  static Color surface(Brightness b) =>
      _dark(b) ? const Color(0xFF181C1E) : const Color(0xFFFFFFFF);

  /// 低一档容器底（分区、输入框）。
  static Color surfaceSoft(Brightness b) =>
      _dark(b) ? const Color(0xFF1C2022) : const Color(0xFFF0F9FF);

  /// 高一档容器底（hover、选中）。
  static Color surfaceMuted(Brightness b) =>
      _dark(b) ? const Color(0xFF272B2C) : const Color(0xFFE5F2FF);

  /// 最高容器底（浮层、弹出菜单）。
  static Color surfaceHigh(Brightness b) =>
      _dark(b) ? const Color(0xFF313537) : const Color(0xFFDBEDFF);

  /// 玻璃层填充（半透明，配 `BackdropFilter`）。
  static Color glassFill(Brightness b) =>
      _dark(b) ? const Color(0xE61C2022) : const Color(0xE6FFFFFF);

  /// 玻璃层描边。
  static Color glassBorder(Brightness b) =>
      _dark(b) ? const Color(0x14FFFFFF) : const Color(0xD1FFFFFF);

  /// 常规描边。
  static Color border(Brightness b) =>
      _dark(b) ? const Color(0x14FFFFFF) : const Color(0xFFD7E7F7);

  /// 强描边（聚焦、选中）。
  static Color borderStrong(Brightness b) =>
      _dark(b) ? const Color(0x2EFFFFFF) : const Color(0xFFB9D5EC);

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
      _dark(b) ? const Color(0xFF164E63) : const Color(0xFFB9EAFF);

  // ------------------------------------------------------------------- 文字

  static Color textPrimary(Brightness b) =>
      _dark(b) ? const Color(0xFFE0E3E5) : const Color(0xFF0B1C30);

  static Color textSecondary(Brightness b) =>
      _dark(b) ? const Color(0xFFBEC8CD) : const Color(0xFF5C7386);

  /// 第三级文字（角标、辅助说明）。
  static Color textTertiary(Brightness b) =>
      _dark(b) ? const Color(0xFF899297) : const Color(0xFF8497A8);

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
      _dark(b) ? const Color(0xFFE0E3E5) : const Color(0xFF0B1C30);

  // ------------------------------------------------------------------- 阴影

  /// 彩色彩软阴影（亮）/ 黑投影（深）。
  static Color shadow(Brightness b) =>
      _dark(b) ? const Color(0x99000000) : const Color(0x140E7490);

  /// 更强的投影（浮层、输入栏）。
  static Color shadowStrong(Brightness b) =>
      _dark(b) ? const Color(0xCC000000) : const Color(0x1A0E7490);
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
