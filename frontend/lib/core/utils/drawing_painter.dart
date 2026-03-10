import 'package:doodle_dash/features/game/models/drawn_path.dart';
import 'package:flutter/material.dart';

/// Renders all committed [DrawnPath] strokes and the in-progress stroke.
///
/// Points are stored normalised (0.0–1.0) and scaled to [size] at paint time.
class DrawingPainter extends CustomPainter {
  final List<DrawnPath> paths;
  final DrawnPath? currentPath;

  DrawingPainter({required this.paths, required this.currentPath});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );
    void drawPath(DrawnPath dp) {
      if (dp.points.isEmpty) return;
      final paint = Paint()
        ..color = dp.color
        ..strokeWidth = dp.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (dp.points.length == 1) {
        // Draw as a dot
        paint.style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset(dp.points[0].dx * size.width, dp.points[0].dy * size.height),
          dp.strokeWidth / 2,
          paint,
        );
      } else {
        final path = Path()
          ..moveTo(dp.points[0].dx * size.width, dp.points[0].dy * size.height);
        for (int i = 1; i < dp.points.length; i++) {
          path.lineTo(
            dp.points[i].dx * size.width,
            dp.points[i].dy * size.height,
          );
        }
        canvas.drawPath(path, paint);
      }
    }

    for (var path in paths) {
      drawPath(path);
    }
    if (currentPath != null) {
      drawPath(currentPath!);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
