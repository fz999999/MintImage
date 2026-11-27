import 'dart:convert';

import 'package:xml/xml.dart';

/// Detect the encoded file, preserving animated GIFs and SVG source verbatim.
String? encodedImageExtension(List<int> bytes) {
  bool matches(List<int> signature, [int offset = 0]) {
    if (bytes.length < signature.length + offset) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (matches([137, 80, 78, 71, 13, 10, 26, 10])) return 'png';
  if (matches([255, 216, 255])) return 'jpeg';
  if (matches([82, 73, 70, 70]) && matches([87, 69, 66, 80], 8)) {
    return 'webp';
  }
  if (matches([71, 73, 70, 56, 55, 97]) || matches([71, 73, 70, 56, 57, 97])) {
    return 'gif';
  }
  try {
    final root = XmlDocument.parse(utf8.decode(bytes)).rootElement;
    if (root.name.local == 'svg' &&
        (root.namespaceUri == null ||
            root.namespaceUri!.isEmpty ||
            root.namespaceUri == 'http://www.w3.org/2000/svg')) {
      return 'svg';
    }
  } on FormatException {
    // Non-UTF8 data is not an SVG document.
  } on XmlException {
    // Reject HTML error pages and malformed XML.
  }
  return null;
}
