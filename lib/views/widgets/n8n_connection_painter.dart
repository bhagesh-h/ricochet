// views/widgets/n8n_connection_painter.dart
import 'dart:math';

import 'package:flutter/material.dart';
import '../../models/pipeline_node.dart';

class N8NConnectionPainter extends CustomPainter {
  final List<PipelineNode> nodes;
  final List<Connection> connections;

  N8NConnectionPainter({
    required this.nodes,
    required this.connections,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final connection in connections) {
      final fromNode = nodes.firstWhereOrNull((n) => n.id == connection.fromNodeId);
      final toNode = nodes.firstWhereOrNull((n) => n.id == connection.toNodeId);

      if (fromNode == null || toNode == null) continue;

      // Calculate connection points (center of left/right edges)
      final fromPoint = Offset(
        fromNode.position.dx + 180, // Right edge of block (180px width)
        fromNode.position.dy + 30,  // Vertical center of block (60px height)
      );
      final toPoint = Offset(
        toNode.position.dx,         // Left edge of block
        toNode.position.dy + 30,    // Vertical center of block
      );

      // Create gradient from source to target color
      final gradient = LinearGradient(
        colors: [
          fromNode.primaryColor.withOpacity(0.8),
          toNode.primaryColor.withOpacity(0.8),
        ],
        stops: const [0, 1],
      );

      // Draw connection line
      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromPoints(fromPoint, toPoint),
        )
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Draw smooth bezier curve
      final path = Path();
      path.moveTo(fromPoint.dx, fromPoint.dy);
      
      // Calculate control points for smooth curve
      final controlPoint1 = Offset(
        fromPoint.dx + (toPoint.dx - fromPoint.dx) * 0.3,
        fromPoint.dy,
      );
      final controlPoint2 = Offset(
        fromPoint.dx + (toPoint.dx - fromPoint.dx) * 0.7,
        toPoint.dy,
      );
      
      path.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        toPoint.dx, toPoint.dy,
      );

      canvas.drawPath(path, paint);

      // Draw arrowhead at end point
      _drawArrowhead(canvas, toPoint, controlPoint2, toNode.primaryColor);
    }
  }

  void _drawArrowhead(Canvas canvas, Offset tip, Offset controlPoint, Color color) {
    // Calculate angle of the line at the tip
    final angle = (tip - controlPoint).direction;

    // Arrowhead properties
    const arrowLength = 12.0;
    const arrowWidth = 8.0;

    // Calculate points for the arrowhead triangle
    final point1 = Offset(
      tip.dx - arrowLength * cos(angle - pi / 6),
      tip.dy - arrowLength * sin(angle - pi / 6),
    );
    final point2 = Offset(
      tip.dx - arrowLength * cos(angle + pi / 6),
      tip.dy - arrowLength * sin(angle + pi / 6),
    );

    // Create arrowhead path
    final arrowPath = Path();
    arrowPath.moveTo(tip.dx, tip.dy);
    arrowPath.lineTo(point1.dx, point1.dy);
    arrowPath.lineTo(point2.dx, point2.dy);
    arrowPath.close();

    // Draw arrowhead
    final arrowPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(N8NConnectionPainter oldDelegate) {
    return oldDelegate.nodes != nodes || oldDelegate.connections != connections;
  }
}

// Extension to safely find node in list
extension FindNode on List<PipelineNode> {
  PipelineNode? firstWhereOrNull(bool Function(PipelineNode) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}