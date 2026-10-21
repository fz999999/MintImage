import 'package:flutter/material.dart';

/// Constrains content inside a full-width scroll view, keeping the gutters
/// available for wheel scrolling.
class SettingsContentWidth extends StatelessWidget {
  const SettingsContentWidth({super.key, required this.child, this.maxWidth = 880});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}
