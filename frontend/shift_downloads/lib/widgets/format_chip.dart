import 'package:flutter/material.dart';
import '../theme/mech_theme.dart';

class FormatChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const FormatChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? MechColors.surface : Colors.transparent,
          border: Border.all(
            color: selected ? MechColors.accentYellow : MechColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? MechColors.accentYellow : MechColors.textMuted,
            fontSize: 11,
            letterSpacing: 1.0,
            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
