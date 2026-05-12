import 'package:flutter/material.dart';
import '../services/history_service.dart';
import '../theme/mech_theme.dart';

class HistoryList extends StatelessWidget {
  final List<HistoryEntry> entries;

  const HistoryList({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: MechColors.border),
        const Text('RECENTES //',
            style: TextStyle(
                color: MechColors.textMuted, fontSize: 10, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        ...entries.take(5).map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                          color: MechColors.accentCyan, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(e.title,
                          style: const TextStyle(
                              color: MechColors.textSecondary, fontSize: 11),
                          overflow: TextOverflow.ellipsis)),
                  Text(e.format,
                      style:
                          const TextStyle(color: MechColors.border, fontSize: 9)),
                ],
              ),
            )),
      ],
    );
  }
}
