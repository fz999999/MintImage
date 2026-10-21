import '../../design/tokens.dart';

/// Windows popup sizing; spacing and radii reuse the application scale.
abstract final class DesktopPopupTokens {
  static const double menuWidth = 280;
  static const double popoverWidth = 360;
  static const double popoverMaxHeight = 420;
  static const double confirmWidth = 440;
  static const double formWidth = 560;
  static const double sizePickerWidth = 820;
  static const double viewportMargin = AppSpace.xs;
  static const double anchorGap = AppSpace.xxs;
  static const double dialogMargin = AppSpace.lg;
  static const double rowHeight = 36;
  static const double detailRowHeight = 48;
  static const int searchThreshold = 8;
}
