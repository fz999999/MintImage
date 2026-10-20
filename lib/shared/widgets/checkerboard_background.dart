import 'package:flutter/material.dart';

/// 透明图片的「棋盘格」底：透明区域显示成灰白格子，
/// 不透明的图片会把自己盖住，所以可以无脑套在所有生成图上。
///
/// 不加这层的话，透明背景的图放在白色卡片上看起来和「白底」一模一样，
/// 用户会以为模型没给透明通道。
class CheckerboardBackground extends StatelessWidget {
  const CheckerboardBackground({
    super.key,
    required this.child,
    this.cellSize = 12,
    this.lightColor = const Color(0xFFFFFFFF),
    this.darkColor = const Color(0xFFE7EFF7),
  });

  final Widget child;
  final double cellSize;
  final Color lightColor;
  final Color darkColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: _CheckerboardPainter(
            cellSize: cellSize,
            lightColor: lightColor,
            darkColor: darkColor,
          ),
        ),
        child,
      ],
    );
  }
}

class _CheckerboardPainter extends CustomPainter {
  const _CheckerboardPainter({
    required this.cellSize,
    required this.lightColor,
    required this.darkColor,
  });

  final double cellSize;
  final Color lightColor;
  final Color darkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final light = Paint()..color = lightColor;
    final dark = Paint()..color = darkColor;
    canvas.drawRect(Offset.zero & size, light);

    final columns = (size.width / cellSize).ceil();
    final rows = (size.height / cellSize).ceil();

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        if ((row + column).isEven) {
          continue;
        }
        canvas.drawRect(
          Rect.fromLTWH(column * cellSize, row * cellSize, cellSize, cellSize),
          dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerboardPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize ||
        oldDelegate.lightColor != lightColor ||
        oldDelegate.darkColor != darkColor;
  }
}
