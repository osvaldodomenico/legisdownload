import 'package:flutter/material.dart';
import '../theme/mech_theme.dart';

class MechProgressBar extends StatelessWidget {
  final double progress; // 0..100
  final String? filename;
  final double? filesizeMb;
  final VoidCallback onAbort;

  const MechProgressBar({
    super.key,
    required this.progress,
    this.filename,
    this.filesizeMb,
    required this.onAbort,
  });

  @override
  Widget build(BuildContext context) {
    final pct = progress.clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                filename ?? 'DOWNLOADING...',
                style: const TextStyle(
                    color: MechColors.accentYellow, fontSize: 10, letterSpacing: 1.0),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text('${pct.toStringAsFixed(1)}%',
                style: const TextStyle(color: MechColors.accentYellow, fontSize: 10)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRect(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
                color: MechColors.surface,
                border: Border.all(color: MechColors.border)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct / 100,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MechColors.accentYellow, MechColors.accentCyan],
                  ),
                  boxShadow: [BoxShadow(color: MechColors.accentYellow, blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
        if (filesizeMb != null) ...[
          const SizedBox(height: 4),
          Text(
            '${(filesizeMb! * pct / 100).toStringAsFixed(1)} MB / ${filesizeMb!.toStringAsFixed(1)} MB',
            textAlign: TextAlign.right,
            style: const TextStyle(color: MechColors.textMuted, fontSize: 9),
          ),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onAbort,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: MechColors.surface,
              border: Border.all(color: MechColors.border),
            ),
            child: const Text('✕ ABORT',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: MechColors.textSecondary, fontSize: 11, letterSpacing: 1.5)),
          ),
        ),
      ],
    );
  }
}
