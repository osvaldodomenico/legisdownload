import 'package:flutter/material.dart';
import '../theme/mech_theme.dart';

class MechButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const MechButton({super.key, required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: CustomPaint(
        painter: _AngularBorderPainter(MechColors.accentYellow),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [MechColors.accentYellow, Color(0xFFE8850A)],
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    fontSize: 13,
                  )),
        ),
      ),
    );
  }
}

class _AngularBorderPainter extends CustomPainter {
  final Color color;
  _AngularBorderPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(6, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 6, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(_) => false;
}
