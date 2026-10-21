import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_image/core/services/image_dimension_reader.dart';

/// 造一个 PNG 尺寸头：8 字节签名 + 长度 + "IHDR" + 宽高(大端) + 其余占位。
Uint8List _pngHeader(int width, int height) {
  final bytes = Uint8List(64);
  bytes.setAll(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  bytes.setAll(12, const [0x49, 0x48, 0x44, 0x52]); // IHDR
  final data = ByteData.sublistView(bytes);
  data.setUint32(16, width, Endian.big);
  data.setUint32(20, height, Endian.big);
  return bytes;
}

/// GIF 的宽高是小端、紧跟 6 字节魔数。
Uint8List _gifHeader(int width, int height) {
  final bytes = Uint8List(32);
  bytes.setAll(0, const [0x47, 0x49, 0x46, 0x38, 0x39, 0x61]); // GIF89a
  final data = ByteData.sublistView(bytes);
  data.setUint16(6, width, Endian.little);
  data.setUint16(8, height, Endian.little);
  return bytes;
}

/// BMP 走 BITMAPCOREHEADER 之外常见的 40 字节头：宽高在 18/22，有符号小端。
Uint8List _bmpHeader(int width, int height) {
  final bytes = Uint8List(54);
  bytes.setAll(0, const [0x42, 0x4D]); // BM
  final data = ByteData.sublistView(bytes);
  data.setUint32(14, 40, Endian.little); // DIB header size
  data.setInt32(18, width, Endian.little);
  data.setInt32(22, height, Endian.little);
  return bytes;
}

void main() {
  const reader = ImageDimensionReader();

  group('ImageDimensionReader.parsePixelSize', () {
    test('解析 PNG 宽高', () {
      final size = reader.parsePixelSize(_pngHeader(1024, 1536));
      expect(size, isNotNull);
      expect(size!.width, 1024);
      expect(size.height, 1536);
    });

    test('解析 GIF 小端宽高', () {
      final size = reader.parsePixelSize(_gifHeader(320, 200));
      expect(size, isNotNull);
      expect(size!.width, 320);
      expect(size.height, 200);
    });

    test('解析 BMP 有符号宽高', () {
      final size = reader.parsePixelSize(_bmpHeader(800, 600));
      expect(size, isNotNull);
      expect(size!.width, 800);
      expect(size.height, 600);
    });

    test('认不出的字节返回 null 而不是抛异常', () {
      expect(reader.parsePixelSize(Uint8List.fromList([1, 2, 3, 4])), isNull);
      expect(reader.parsePixelSize(Uint8List(0)), isNull);
    });

    test('头部被截断时返回 null', () {
      final truncated = Uint8List.fromList(
        _pngHeader(1024, 1024).sublist(0, 16),
      );
      expect(reader.parsePixelSize(truncated), isNull);
    });
  });

  group('ImageDimensionReader.readAspectRatio', () {
    test('不存在的文件返回 null', () async {
      expect(await reader.readAspectRatio('definitely/not/here.png'), isNull);
    });
  });
}
