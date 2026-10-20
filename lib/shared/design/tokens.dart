import 'package:flutter/material.dart';

/// 设计令牌：间距 / 圆角 / 字号 / 图标 / 阴影 / 透明度 / 动效。
///
/// 全项目所有视觉常量都应从这里取，禁止在业务代码里写字面量。
/// 目的：把现状里的 14 种圆角、9 档字号、30 余种 alpha 收敛成有限集合。
class AppSpace {
  const AppSpace._();

  /// 4 —— 图标与文字的最小间隙
  static const double xxs = 4;

  /// 8 —— 组件内元素间距
  static const double xs = 8;

  /// 12 —— 卡片内边距、列表项横向内边距
  static const double sm = 12;

  /// 16 —— 区块之间的标准间距
  static const double md = 16;

  /// 24 —— 大区块之间的间距
  static const double lg = 24;

  /// 32 —— 页面级留白
  static const double xl = 32;
}

/// 圆角：14 种取值收敛为 5 种。
class AppRadius {
  const AppRadius._();

  /// 6 —— 元信息胶囊、内联徽章
  static const double xs = 6;

  /// 10 —— 图卡、按钮、输入框、选择器
  static const double sm = 10;

  /// 14 —— 面板、上下文栏
  static const double md = 14;

  /// 20 —— 对话框、浮层、底部输入栏容器
  static const double lg = 20;

  /// 999 —— 状态胶囊、头像、圆形按钮
  static const double full = 999;
}

/// 字号：9 档收敛为 7 档，全部经由 [TextTheme] 使用。
class AppFontSize {
  const AppFontSize._();

  /// 28 —— 空态标题
  static const double displaySm = 28;

  /// 20 —— 页面标题
  static const double titleLg = 20;

  /// 16 —— 区块标题、AppBar 标题
  static const double titleMd = 16;

  /// 14 —— 正文、输入框文字
  static const double bodyLg = 14;

  /// 13 —— 卡片描述、列表项
  static const double bodyMd = 13;

  /// 12 —— 标签、次要文字
  static const double labelMd = 12;

  /// 11 —— 图标旁文字、时间戳
  static const double labelSm = 11;
}

/// 图标尺寸：12 种收敛为 4 种。
class AppIconSize {
  const AppIconSize._();

  /// 12 —— 标签内联图标
  static const double xs = 12;

  /// 16 —— 按钮图标
  static const double sm = 16;

  /// 20 —— 工具栏图标
  static const double md = 20;

  /// 28 —— 空态、品牌图形
  static const double lg = 28;
}

/// 阴影：3 档。
class AppShadow {
  const AppShadow._();

  /// 图卡常态
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F0E7490),
      blurRadius: 16,
      spreadRadius: -4,
      offset: Offset(0, 4),
    ),
  ];

  /// 悬停、浮层、右键菜单
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(
      color: Color(0x1F0E7490),
      blurRadius: 28,
      spreadRadius: -8,
      offset: Offset(0, 10),
    ),
  ];

  /// 底部输入栏：中性投影，避免主色染色
  static const List<BoxShadow> input = <BoxShadow>[
    BoxShadow(
      color: Color(0x0F000000),
      blurRadius: 24,
      spreadRadius: -6,
      offset: Offset(0, 8),
    ),
  ];
}

/// 透明度：30 余种组合收敛为 5 档语义命名。
class AppOpacity {
  const AppOpacity._();

  /// 0.06 —— 悬停底色
  static const double hover = 0.06;

  /// 0.12 —— 按下态、选中底
  static const double press = 0.12;

  /// 0.72 —— 弹层遮罩
  static const double scrim = 0.72;

  /// 0.86 —— 玻璃质感输入栏填充
  static const double glassFill = 0.86;

  /// 0.92 —— 图内信息胶囊填充
  static const double chipFill = 0.92;
}

/// 动效时长与缓动。
class AppMotion {
  const AppMotion._();

  /// 悬停、按下等微交互
  static const Duration fast = Duration(milliseconds: 120);

  /// 面板展开、浮层
  static const Duration normal = Duration(milliseconds: 180);

  /// 页面级转场
  static const Duration slow = Duration(milliseconds: 260);

  static const Curve curve = Curves.easeOut;
}