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

/// 圆角 5 档：角标 4 / 普通控件 6 / 卡片 10 / 浮层 12 / 圆形 999。
class AppRadius {
  const AppRadius._();

  /// 角标、标签。
  static const double xs = 4;

  /// 按钮、输入框、选择器。
  static const double sm = 6;

  /// 图卡、面板、分区卡。
  static const double md = 10;

  /// 输入栏、对话框、浮层。
  static const double lg = 12;

  /// 圆形。
  static const double full = 999;

  static BorderRadius get xsAll => BorderRadius.circular(xs);
  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
  static BorderRadius get fullAll => BorderRadius.circular(full);
}

/// 字号 8 档：12 / 13 / 14 / 15 / 16 / 18 / 22 / 28。
class AppFontSize {
  const AppFontSize._();

  /// 图上角标。
  static const double caption = 12;

  /// 辅助说明。
  static const double micro = 13;

  /// 标签、徽章。
  static const double label = 14;

  /// 正文小（元信息行）。
  static const double bodySm = 15;

  /// 正文。
  static const double body = 16;

  /// 小标题。
  static const double title = 18;

  /// 大标题。
  static const double headline = 22;

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

/// 中性阴影：普通卡片轻微分层，浮层保留适度抬升。
class AppShadow {
  const AppShadow._();

  /// 卡片。
  static List<BoxShadow> card(Brightness b) => [
    BoxShadow(
      color: AppColors.shadow(b),
      blurRadius: 4,
      spreadRadius: -1,
      offset: const Offset(0, 1),
    ),
  ];

  /// 抬升态（hover）。
  static List<BoxShadow> raised(Brightness b) => [
    BoxShadow(
      color: AppColors.shadowStrong(b),
      blurRadius: 12,
      spreadRadius: -3,
      offset: const Offset(0, 3),
    ),
  ];

  /// 浮层、输入栏。
  static List<BoxShadow> floating(Brightness b) => [
    BoxShadow(
      color: AppColors.shadowStrong(b),
      blurRadius: 20,
      spreadRadius: -4,
      offset: const Offset(0, 6),
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
