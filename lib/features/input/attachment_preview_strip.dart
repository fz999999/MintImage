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
    this.hasMarkup = false,
    this.onEditMarkup,
  });

  final List<PickedAttachment> attachments;
  final ValueChanged<int> onRemove;
  final bool hasMarkup;
  final VoidCallback? onEditMarkup;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft(b),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
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
                        const SizedBox(width: AppSpace.xs),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (onEditMarkup != null) ...[
            const SizedBox(width: AppSpace.xs),
            Tooltip(
              message: hasMarkup ? '编辑标注（已添加）' : '在参考图上标注',
              child: IconButton(
                onPressed: onEditMarkup,
                icon: Icon(
                  Icons.draw_rounded,
                  size: AppIconSize.md,
                  color: hasMarkup
                      ? AppColors.primary(b)
                      : AppColors.textSecondary(b),
                ),
              ),
            ),
          ],
          const SizedBox(width: AppSpace.xxs),
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
    final b = Theme.of(context).brightness;

    return SizedBox(
      width: _thumbnailSize,
      height: _thumbnailSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
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
                color: AppColors.surfaceSoft(b),
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: AppIconSize.sm,
                  color: AppColors.primary(b),
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
                  color: AppColors.scrim(b),
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
