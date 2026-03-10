import 'package:flutter/material.dart';

/// Represents a single continuous stroke drawn on the canvas.
///
/// Points are stored as normalized [Offset] values (0.0–1.0) relative to the
/// canvas dimensions so they render correctly at any screen size or resolution.
class DrawnPath {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  DrawnPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}
