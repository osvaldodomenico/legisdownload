import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/mech_theme.dart';
import 'format_chip.dart';

class FormatSelector extends StatelessWidget {
  final List<FormatOption> formats;
  final bool showNoWatermark;
  final String? selectedId;
  final bool noWatermark;
  final void Function(String id) onSelect;
  final void Function(bool value) onNoWatermarkToggle;

  const FormatSelector({
    super.key,
    required this.formats,
    required this.showNoWatermark,
    required this.selectedId,
    required this.noWatermark,
    required this.onSelect,
    required this.onNoWatermarkToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('FORMATO:',
            style: TextStyle(
                color: MechColors.textMuted, fontSize: 10, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: formats
              .map((f) => FormatChip(
                    label: f.label,
                    selected: selectedId == f.id,
                    onTap: () => onSelect(f.id),
                  ))
              .toList(),
        ),
        if (showNoWatermark) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: noWatermark,
                onChanged: onNoWatermarkToggle,
                activeThumbColor: MechColors.accentCyan,
              ),
              const Text("SEM MARCA D'ÁGUA",
                  style: TextStyle(
                      color: MechColors.textSecondary,
                      fontSize: 10,
                      letterSpacing: 1.0)),
            ],
          ),
        ],
      ],
    );
  }
}
