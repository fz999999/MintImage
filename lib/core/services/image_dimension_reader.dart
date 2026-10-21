import 'dart:io';
import 'dart:typed_data';

/// 图片文件头里读出来的真实像素尺寸。
typedef ImagePixelSize = ({int width, int height});

/// 从本地图片文件的头部字节读出真实像素尺寸。
///
/// 图墙要按图片自己的宽高比排版，就不能等 Flutter 把 1~2 MB 的生成图整张解码
/// 完再问尺寸 —— 那会让首屏多等几百毫秒，滚动时还会反复触发解码。
/// PNG / JPEG / GIF / WebP / BMP 的尺寸都写在文件头，读前 64 KB 足够，
/// 一次文件头解析是几十微秒级别。
class ImageDimensionReader {
  const ImageDimensionReader();

  /// 超过这个长度的文件没必要整份读进来，尺寸一定在前 64 KB 里。
  static const int headerByteCount = 64 * 1024;

  Future<double?> readAspectRatio(String path) async {
    final size = await readPixelSize(path);
    if (size == null || size.width <= 0 || size.height <= 0) {
      return null;
    }
    return size.width / size.height;
  }

  Future<ImagePixelSize?> readPixelSize(String path) async {
    final bytes = await _readHeader(path);
    if (bytes == null) {
      return null;
    }
    return parsePixelSize(bytes);
  }

  /// 纯字节解析，便于单测直接喂构造好的文件头。
  ImagePixelSize? parsePixelSize(Uint8List bytes) {
    if (_matches(bytes, 0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return _pngSize(bytes);
    }
    if (_matches(bytes, 0, const [0xFF, 0xD8])) {
      return _jpegSize(bytes);
    }
    if (_matches(bytes, 0, const [0x47, 0x49, 0x46, 0x38])) {
      return _gifSize(bytes);
    }
    if (_matches(bytes, 0, const [0x52, 0x49, 0x46, 0x46]) &&
        _matches(bytes, 8, const [0x57, 0x45, 0x42, 0x50])) {
      return _webpSize(bytes);
    }
    if (_matches(bytes, 0, const [0x42, 0x4D])) {
      return _bmpSize(bytes);
    }
    return null;
  }

  Future<Uint8List?> _readHeader(String path) async {
    RandomAccessFile? file;
    try {
      final target = File(path);
      if (!target.existsSync()) {
        return null;
      }
      file = await target.open();
      final length = await file.length();
      if (length <= 0) {
        return null;
      }
      final count = length < headerByteCount ? length : headerByteCount;
      return await file.read(count);
    } catch (_) {
      // 读不到就当作「比例未知」，图墙退回占位比例，不影响生成主流程。
      return null;
    } finally {
      await file?.close();
    }
  }

  /// IHDR 紧跟 8 字节 PNG 签名：长度(4) + 'IHDR'(4) + 宽(4) + 高(4)。
  ImagePixelSize? _pngSize(Uint8List bytes) {
    if (bytes.length < 24) {
      return null;
    }
    if (!_matches(bytes, 12, const [0x49, 0x48, 0x44, 0x52])) {
      return null;
    }
    return (width: _uint32be(bytes, 16), height: _uint32be(bytes, 20));
  }

  /// GIF 的宽高是小端 16 位，紧跟在 6 字节签名后面。
  ImagePixelSize? _gifSize(Uint8List bytes) {
    if (bytes.length < 10) {
      return null;
    }
    return (width: _uint16le(bytes, 6), height: _uint16le(bytes, 8));
  }

  /// JPEG 要扫段找 SOFn（C0~CF，排除 C4/C8/CC）。
  ImagePixelSize? _jpegSize(Uint8List bytes) {
    var offset = 2;
    while (offset + 3 < bytes.length) {
      if (bytes[offset] != 0xFF) {
        offset += 1;
        continue;
      }
      final marker = bytes[offset + 1];
      // 填充字节、SOI、RSTn、TEM 没有长度字段。
      if (marker == 0xFF) {
        offset += 1;
        continue;
      }
      if (marker == 0xD8 || marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
        offset += 2;
        continue;
      }
      if (marker == 0xD9 || marker == 0xDA) {
        // EOI 或到达扫描数据，还没遇到 SOF 就没有尺寸了。
        return null;
      }
      if (offset + 4 > bytes.length) {
        return null;
      }
      final segmentLength = _uint16be(bytes, offset + 2);
      if (segmentLength < 2) {
        return null;
      }
      final isStartOfFrame = marker >= 0xC0 &&
          marker <= 0xCF &&
          marker != 0xC4 &&
          marker != 0xC8 &&
          marker != 0xCC;
      if (isStartOfFrame) {
        if (offset + 9 > bytes.length) {
          return null;
        }
        return (
          width: _uint16be(bytes, offset + 7),
          height: _uint16be(bytes, offset + 5),
        );
      }
      offset += 2 + segmentLength;
    }
    return null;
  }

  /// WebP 有三种头：VP8X（扩展）、VP8 （有损）、VP8L（无损）。
  ImagePixelSize? _webpSize(Uint8List bytes) {
    if (bytes.length < 30) {
      return null;
    }
    final fourCc = String.fromCharCodes(bytes.sublist(12, 16));
    switch (fourCc) {
      case 'VP8X':
        // 24 位小端，存的都是「实际值 - 1」。
        return (
          width: _uint24le(bytes, 24) + 1,
          height: _uint24le(bytes, 27) + 1,
        );
      case 'VP8 ':
        return (
          width: _uint16le(bytes, 26) & 0x3FFF,
          height: _uint16le(bytes, 28) & 0x3FFF,
        );
      case 'VP8L':
        if (bytes[20] != 0x2F) {
          return null;
        }
        final bits = _uint32le(bytes, 21);
        return (
          width: (bits & 0x3FFF) + 1,
          height: ((bits >> 14) & 0x3FFF) + 1,
        );
      default:
        return null;
    }
  }

  /// BMP 的宽高是 32 位小端有符号数，高度可能是负数（自上而下存储）。
  ImagePixelSize? _bmpSize(Uint8List bytes) {
    if (bytes.length < 26) {
      return null;
    }
    return (
      width: _int32le(bytes, 18).abs(),
      height: _int32le(bytes, 22).abs(),
    );
  }

  bool _matches(Uint8List bytes, int offset, List<int> signature) {
    if (offset + signature.length > bytes.length) {
      return false;
    }
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) {
        return false;
      }
    }
    return true;
  }

  int _uint16be(Uint8List bytes, int offset) {
    return (bytes[offset] << 8) | bytes[offset + 1];
  }

  int _uint16le(Uint8List bytes, int offset) {
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  int _uint24le(Uint8List bytes, int offset) {
    return bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);
  }

  int _uint32be(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  int _uint32le(Uint8List bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  int _int32le(Uint8List bytes, int offset) {
    final value = _uint32le(bytes, offset);
    return value >= 0x80000000 ? value - 0x100000000 : value;
  }
}
