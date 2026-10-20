import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/attachment_picker_service.dart';
import '../../shared/theme.dart';

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
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.file(
              File(attachment.path),
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 44,
                height: 44,
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
