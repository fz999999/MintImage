import 'package:flutter/material.dart';

import 'app_colors.dart';

/// 间距刻度。**只用这 6 档**，不要再就地写数字。
class AppSpace {
  const AppSpace._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

/// 圆角 5 档：角标 6 / 图卡·按钮·输入框 12 / 面板 16 / 输入栏·对话框·浮层 22 / 圆形 999。
class AppRadius {
  const AppRadius._();

  /// 角标、标签。
  static const double xs = 6;

  /// 图卡、按钮、输入框。
  static const double sm = 12;

  /// 面板、分区卡。
  static const double md = 16;

  /// 输入栏、对话框、浮层。
  static const double lg = 22;

  /// 圆形。
  static const double full = 999;

  static BorderRadius get xsAll => BorderRadius.circular(xs);
  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get fullAll => BorderRadius.circular(full);
}

/// 字号 8 档：10 / 11 / 12 / 13 / 14 / 16 / 20 / 28。
class AppFontSize {
  const AppFontSize._();

  /// 图上角标。
  static const double caption = 10;

  /// 辅助说明。
  static const double micro = 11;

  /// 标签、徽章。
  static const double label = 12;

  /// 正文小（元信息行）。
  static const double bodySm = 13;

  /// 正文。
  static const double body = 14;

  /// 小标题。
  static const double title = 16;

  /// 大标题。
  static const double headline = 20;

  /// 展示级标题。
  static const double display = 28;
}

/// 图标 4 档。
class AppIconSize {
  const AppIconSize._();

  static const double xs = 12;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 28;
}

/// 阴影。亮色是青色软阴影，深色是黑投影。
class AppShadow {
  const AppShadow._();

  /// 卡片。
  static List<BoxShadow> card(Brightness b) => [
    BoxShadow(
      color: AppColors.shadow(b),
      blurRadius: 16,
      spreadRadius: -4,
      offset: const Offset(0, 4),
    ),
  ];

  /// 抬升态（hover）。
  static List<BoxShadow> raised(Brightness b) => [
    BoxShadow(
      color: AppColors.shadowStrong(b),
      blurRadius: 28,
      spreadRadius: -8,
      offset: const Offset(0, 10),
    ),
  ];

  /// 浮层、输入栏。
  static List<BoxShadow> floating(Brightness b) => [
    BoxShadow(
      color: AppColors.shadowStrong(b),
      blurRadius: 32,
      spreadRadius: -10,
      offset: const Offset(0, 14),
    ),
  ];

  static const List<BoxShadow> none = [];
}

/// 透明度。
class AppOpacity {
  const AppOpacity._();

  static const double hover = 0.06;
  static const double press = 0.12;
  static const double scrim = 0.72;
  static const double glassFill = 0.90;
  static const double chipFill = 0.92;
}

/// 动效时长与曲线。
class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 260);

  static const Curve curve = Curves.easeOut;
}
