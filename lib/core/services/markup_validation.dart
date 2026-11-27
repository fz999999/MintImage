import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

typedef MarkupReference = ({int width, int height, Uint8List rgba});

/// Normalize EXIF orientation once so editor coordinates and uploaded markup agree.
/// Returns raw RGBA pixels; re-encoding a phone photo to PNG costs seconds.
Future<MarkupReference> prepareMarkupReference(String path) => Isolate.run(() {
  final bytes = File(path).readAsBytesSync();
  final decoder = image.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null) throw const FormatException('无法读取参考图');
  if (info.width * info.height > 16777216) {
    throw const FormatException('标注引导的参考图不得超过 16,777,216 像素');
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) throw const FormatException('参考图解码失败');
  final oriented = image
      .bakeOrientation(decoded)
      .convert(format: image.Format.uint8, numChannels: 4);
  return (
    width: oriented.width,
    height: oriented.height,
    rgba: oriented.toUint8List(),
  );
});

/// Oriented size without a full decode for JPEG, so the editor can use the
/// fast native decoder and only fall back to [prepareMarkupReference].
Future<(int, int)> readMarkupReferenceSize(String path) => Isolate.run(() {
  final bytes = File(path).readAsBytesSync();
  final decoder = image.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null) throw const FormatException('无法读取参考图');
  if (info.width * info.height > 16777216) {
    throw const FormatException('标注引导的参考图不得超过 16,777,216 像素');
  }
  final size = _orientedSize(bytes, decoder!, info);
  if (size == null) throw const FormatException('参考图解码失败');
  return size;
});

/// Shared by desktop, mobile and the pure Dart CLI, before any paid edit.
Future<String?> validateMarkupAttachment(
  String referencePath,
  String markupPath,
) => Isolate.run(() => _validate(referencePath, markupPath));

String? _validate(String referencePath, String markupPath) {
  const maxPixels = 16777216;
  try {
    final overlayFile = File(markupPath);
    if (overlayFile.lengthSync() > 50 * 1024 * 1024) {
      return '标注 PNG 不得超过 50 MB。';
    }
    final overlayBytes = overlayFile.readAsBytesSync();
    final overlayDecoder = image.PngDecoder();
    final overlayInfo = overlayDecoder.startDecode(overlayBytes);
    if (overlayInfo == null) return '标注图必须是有效的 PNG 文件。';
    if (overlayInfo.width * overlayInfo.height > maxPixels) {
      return '标注图不得超过 16,777,216 像素。';
    }
    final referenceBytes = File(referencePath).readAsBytesSync();
    final referenceDecoder = image.findDecoderForData(referenceBytes);
    final referenceInfo = referenceDecoder?.startDecode(referenceBytes);
    if (referenceInfo == null) return '无法读取第一张参考图。';
    if (referenceInfo.width * referenceInfo.height > maxPixels) {
      return '标注引导的第一张参考图不得超过 16,777,216 像素。';
    }
    final referenceSize = _orientedSize(
      referenceBytes,
      referenceDecoder!,
      referenceInfo,
    );
    final overlay = overlayDecoder.decodeFrame(0);
    if (referenceSize == null || overlay == null) {
      return '图片解码失败，请重新导出 PNG。';
    }
    final (width, height) = referenceSize;
    if (overlay.width != width || overlay.height != height) {
      return '标注图尺寸需与第一张参考图一致（方向校正后为 $width×$height）。';
    }
    if (!overlay.any((pixel) => pixel.aNormalized < 1)) {
      return '标注 PNG 必须含透明像素，请使用透明背景导出标注层。';
    }
    return null;
  } on FileSystemException {
    return '参考图或标注图不存在或无法读取，请重新选择。';
  } catch (_) {
    return '无法解析标注图或参考图，请重新导出后重试。';
  }
}

/// JPEG decoding already applies EXIF orientation, so reading the EXIF block
/// is enough; other formats rarely carry orientation and are decoded fully.
(int, int)? _orientedSize(
  Uint8List bytes,
  image.Decoder decoder,
  image.DecodeInfo info,
) {
  if (decoder is image.JpegDecoder) {
    final orientation = image.decodeJpgExif(bytes)?.imageIfd.orientation ?? 1;
    return orientation >= 5 && orientation <= 8
        ? (info.height, info.width)
        : (info.width, info.height);
  }
  final frame = decoder.decodeFrame(0);
  if (frame == null) return null;
  final oriented = image.bakeOrientation(frame);
  return (oriented.width, oriented.height);
}
