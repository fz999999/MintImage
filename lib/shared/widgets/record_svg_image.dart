import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/models/image_record.dart';

BytesLoader? svgLoaderForRecord(ImageRecord record) {
  final path = record.resultImagePath;
  if (path != null && File(path).existsSync()) {
    return SvgFileLoader(File(path));
  }
  final url = record.resultImageUrl;
  if (url != null && url.isNotEmpty) return SvgNetworkLoader(url);
  final b64 = record.resultB64;
  if (b64 != null && b64.isNotEmpty) {
    try {
      final bytes = b64.startsWith('data:')
          ? UriData.parse(b64).contentAsBytes()
          : base64Decode(b64);
      return SvgBytesLoader(bytes);
    } on FormatException {
      return null;
    }
  }
  return null;
}

Future<Size?> svgSizeForRecord(ImageRecord record) async {
  final loader = svgLoaderForRecord(record);
  if (loader == null) return null;
  final info = await vg.loadPicture(loader, null);
  final size = info.size;
  info.picture.dispose();
  return size;
}

class RecordSvgImage extends StatelessWidget {
  const RecordSvgImage({
    super.key,
    required this.record,
    this.fit = BoxFit.contain,
  });

  final ImageRecord record;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final loader = svgLoaderForRecord(record);
    if (loader == null) return const Icon(Icons.broken_image_rounded);
    return SvgPicture(
      loader,
      width: double.infinity,
      height: double.infinity,
      fit: fit,
      semanticsLabel: 'SVG 矢量图',
      placeholderBuilder: (_) =>
          const Center(child: CircularProgressIndicator()),
      errorBuilder: (_, _, _) =>
          const Center(child: Icon(Icons.image_not_supported_rounded)),
    );
  }
}
