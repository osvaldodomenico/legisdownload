import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../theme/mech_theme.dart';

class VideoPreview extends StatelessWidget {
  final VideoInfo info;

  const VideoPreview({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MechColors.surface,
        border: Border.all(color: MechColors.border),
      ),
      child: Row(
        children: [
          if (info.thumbnail != null)
            CachedNetworkImage(
              imageUrl: info.thumbnail!,
              width: 80,
              height: 52,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(width: 80, height: 52, color: MechColors.surfaceAlt),
              errorWidget: (_, __, ___) => Container(
                  width: 80,
                  height: 52,
                  color: MechColors.surfaceAlt,
                  child: const Icon(Icons.play_circle_outline, color: MechColors.textMuted)),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.title,
                    style: const TextStyle(color: MechColors.textPrimary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(info.platform.toUpperCase(),
                    style: const TextStyle(
                        color: MechColors.accentCyan, fontSize: 10, letterSpacing: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
