import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/services/attachment_picker_service.dart';
import '../../shared/theme.dart';

const double _thumbnailSize = 44;

class AttachmentPreviewStrip extends StatelessWidget {
  const AttachmentPreviewStrip({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  final List<PickedAttachment> attachments;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppThemeTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SizedBox(
              height: _thumbnailSize,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (
                      int index = 0;
                      index < attachments.length;
                      index += 1
                    ) ...[
                      _AttachmentThumb(
                        attachment: attachments[index],
                        onRemove: () => onRemove(index),
                      ),
                      if (index != attachments.length - 1)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({required this.attachment, required this.onRemove});

  final PickedAttachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _thumbnailSize,
      height: _thumbnailSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image(
              image: _AttachmentImage(
                File(attachment.path),
                pixelSize:
                    (_thumbnailSize * MediaQuery.devicePixelRatioOf(context))
                        .ceil(),
              ),
              width: _thumbnailSize,
              height: _thumbnailSize,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => Container(
                width: _thumbnailSize,
                height: _thumbnailSize,
                color: AppThemeTokens.surfaceSoft,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  size: 18,
                  color: AppThemeTokens.primary,
                ),
              ),
            ),
          ),
          Positioned(
            right: -5,
            top: -5,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentImage extends FileImage {
  const _AttachmentImage(super.file, {required this.pixelSize});

  final int pixelSize;

  @override
  ImageStreamCompleter loadImage(FileImage key, ImageDecoderCallback decode) {
    return super.loadImage(key, (buffer, {getTargetSize}) {
      return decode(
        buffer,
        getTargetSize: (width, height) {
          // BoxFit.cover needs enough pixels on the shorter side so cropping
          // a landscape image into a square never enlarges a tiny decode.
          final scale = math.min(1.0, pixelSize / math.min(width, height));
          return ui.TargetImageSize(
            width: (width * scale).ceil(),
            height: (height * scale).ceil(),
          );
        },
      );
    });
  }

  @override
  bool operator ==(Object other) =>
      other is _AttachmentImage &&
      super == other &&
      pixelSize == other.pixelSize;

  @override
  int get hashCode => Object.hash(super.hashCode, pixelSize);
}
