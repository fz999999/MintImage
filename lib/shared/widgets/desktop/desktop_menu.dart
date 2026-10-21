import 'package:flutter/material.dart';

import 'desktop_choice_list.dart';
import 'desktop_popover.dart';

export 'desktop_choice_list.dart' show DesktopMenuItem;

Future<T?> showDesktopMenu<T>({
  required BuildContext context,
  required List<DesktopMenuItem<T>> items,
  String? title,
  double width = 280,
  Rect? anchorRect,
  bool searchable = false,
  bool preferAbove = true,
}) {
  var committed = false;
  return showDesktopPopover<T>(
  context: context,
  width: width,
  anchorRect: anchorRect,
  preferAbove: preferAbove,
  builder: (popupContext) => DesktopChoiceList<T>(
    items: items,
    title: title,
    searchable: searchable,
    onSelected: (value) {
      if (committed || ModalRoute.of(popupContext)?.isCurrent != true) return;
      committed = true;
      Navigator.of(popupContext).pop<T>(value);
    },
  ),
  );
}
