import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:get/get.dart';
import 'package:n8n_application_2/views/widgets/n8n_connection_painter.dart';
import 'package:n8n_application_2/views/widgets/parameter_sidebar.dart';
import '../controllers/pipeline_controller.dart';
import 'widgets/n8n_block_widget.dart';

class ModernCanvas extends StatefulWidget {
  const ModernCanvas({Key? key}) : super(key: key);

  @override
  State<ModernCanvas> createState() => _ModernCanvasState();
}

class _ModernCanvasState extends State<ModernCanvas> with TickerProviderStateMixin {
  final GlobalKey _canvasKey = GlobalKey();
  final TransformationController _transformationController = TransformationController();
  late AnimationController _zoomAnimationController;
  
  double _currentZoom = 1.0;
  static const double _minZoom = 0.3;
  static const double _maxZoom = 3.0;
  
  // For drag connection visualization
  Offset? _dragStartPoint;
  Offset? _dragCurrentPoint;
  String? _dragSourceNodeId;
  bool _isOutputDrag = false;

  @override
  void initState() {
    super.initState();
    _zoomAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _zoomAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PipelineController controller = Get.find();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FA),
      ),
      child: Stack(
        children: [
          // Main canvas with zoom
          Listener(
            onPointerSignal: (pointerSignal) {
              if (pointerSignal is PointerScrollEvent) {
                _handleZoom(pointerSignal);
              }
            },
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: _minZoom,
              maxScale: _maxZoom,
              boundaryMargin: const EdgeInsets.all(100),
              child: Container(
                key: _canvasKey,
                width: 5000,
                height: 3000,
                child: DragTarget<String>(
                  onWillAccept: (data) => true,
                  onAcceptWithDetails: (details) {
                    final renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                    if (renderBox != null) {
                      final localOffset = renderBox.globalToLocal(details.offset);
                      controller.addNode(details.data, localOffset);
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    return Obx(() {
                      return Stack(
                        children: [
                          // Grid background
                          CustomPaint(
                            size: const Size(5000, 3000),
                            painter: N8NGridPainter(zoom: _currentZoom),
                          ),
                          // Connection lines
                          CustomPaint(
                            size: const Size(5000, 3000),
                            painter: N8NConnectionPainter(
                              nodes: controller.nodes,
                              connections: controller.connections,
                            ),
                          ),
                          // Temporary drag connection line
                          if (_dragStartPoint != null && _dragCurrentPoint != null)
                            CustomPaint(
                              size: const Size(5000, 3000),
                              painter: _DragConnectionPainter(
                                startPoint: _dragStartPoint!,
                                endPoint: _dragCurrentPoint!,
                                color: _getDragConnectionColor(),
                              ),
                            ),
                          // Nodes
                          ...controller.nodes.map((node) {
                            return Positioned(
                              left: node.position.dx,
                              top: node.position.dy,
                              child: N8NBlockWidget(
                                node: node,
                                canvasKey: _canvasKey,
                                zoom: _currentZoom,
                                onConnectionDragStart: startConnectionDrag,
                                onConnectionDragUpdate: updateConnectionDrag,
                                onConnectionDragEnd: endConnectionDrag,
                              ),
                            );
                          }),
                        ],
                      );
                    });
                  },
                ),
              ),
            ),
          ),
          // Zoom controls
          Positioned(
            right: 20,
            bottom: 80,
            child: _buildZoomControls(),
          ),
          // Parameter sidebar
          Obx(() {
            final selectedNode = controller.selectedNode.value;
            if (selectedNode != null) {
              final node = controller.nodes.firstWhereOrNull((n) => n.id == selectedNode);
              if (node != null) {
                return ParameterSidebar(node: node);
              }
            }
            return const SizedBox();
          }),
        ],
      ),
    );
  }

  void _handleZoom(PointerScrollEvent event) {
    final double zoomDelta = event.scrollDelta.dy > 0 ? -0.1 : 0.1;
    final double newZoom = (_currentZoom + zoomDelta).clamp(_minZoom, _maxZoom);
    
    if (newZoom != _currentZoom) {
      setState(() {
        _currentZoom = newZoom;
      });
      
      final Matrix4 matrix = Matrix4.identity()..scale(newZoom);
      _transformationController.value = matrix;
    }
  }

  void startConnectionDrag(String nodeId, bool isOutput, Offset startPoint) {
    setState(() {
      _dragSourceNodeId = nodeId;
      _isOutputDrag = isOutput;
      _dragStartPoint = startPoint;
      _dragCurrentPoint = startPoint;
    });
  }

  void updateConnectionDrag(Offset currentPoint) {
    setState(() {
      _dragCurrentPoint = currentPoint;
    });
  }

  void endConnectionDrag() {
    setState(() {
      _dragStartPoint = null;
      _dragCurrentPoint = null;
      _dragSourceNodeId = null;
    });
  }

  Color _getDragConnectionColor() {
    if (_dragSourceNodeId != null) {
      final controller = Get.find<PipelineController>();
      final node = controller.nodes.firstWhereOrNull((n) => n.id == _dragSourceNodeId);
      if (node != null) {
        return node.primaryColor;
      }
    }
    return Colors.blue;
  }

  Widget _buildZoomControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildZoomButton(Icons.add, () => _zoomIn()),
          Container(
            width: 48,
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${(_currentZoom * 100).round()}%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
          Container(
            width: 48,
            height: 1,
            color: const Color(0xFFE2E8F0),
          ),
          _buildZoomButton(Icons.remove, () => _zoomOut()),
        ],
      ),
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: const Color(0xFF475569)),
        hoverColor: const Color(0xFFF1F5F9),
      ),
    );
  }

  void _zoomIn() {
    final double newZoom = (_currentZoom + 0.2).clamp(_minZoom, _maxZoom);
    _animateZoom(newZoom);
  }

  void _zoomOut() {
    final double newZoom = (_currentZoom - 0.2).clamp(_minZoom, _maxZoom);
    _animateZoom(newZoom);
  }

  void _animateZoom(double targetZoom) {
    final double startZoom = _currentZoom;
    final Animation<double> animation = Tween<double>(
      begin: startZoom,
      end: targetZoom,
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.easeInOut,
    ));

    animation.addListener(() {
      setState(() {
        _currentZoom = animation.value;
      });
      final Matrix4 matrix = Matrix4.identity()..scale(_currentZoom);
      _transformationController.value = matrix;
    });

    _zoomAnimationController.reset();
    _zoomAnimationController.forward();
  }
}

class _DragConnectionPainter extends CustomPainter {
  final Offset startPoint;
  final Offset endPoint;
  final Color color;

  _DragConnectionPainter({
    required this.startPoint,
    required this.endPoint,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw straight line for drag connection
    canvas.drawLine(startPoint, endPoint, paint);

    // Draw arrowhead
    final angle = (endPoint - startPoint).direction;
    const arrowLength = 12.0;
    const arrowWidth = 8.0;

    final point1 = Offset(
      endPoint.dx - arrowLength * cos(angle - pi / 6),
      endPoint.dy - arrowLength * sin(angle - pi / 6),
    );
    final point2 = Offset(
      endPoint.dx - arrowLength * cos(angle + pi / 6),
      endPoint.dy - arrowLength * sin(angle + pi / 6),
    );

    final arrowPath = Path();
    arrowPath.moveTo(endPoint.dx, endPoint.dy);
    arrowPath.lineTo(point1.dx, point1.dy);
    arrowPath.lineTo(point2.dx, point2.dy);
    arrowPath.close();

    final arrowPaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(_DragConnectionPainter oldDelegate) {
    return oldDelegate.startPoint != startPoint ||
           oldDelegate.endPoint != endPoint ||
           oldDelegate.color != color;
  }
}

class N8NGridPainter extends CustomPainter {
  final double zoom;

  N8NGridPainter({required this.zoom});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0).withOpacity(0.4)
      ..strokeWidth = 0.5;

    const spacing = 20.0;
    final adjustedSpacing = spacing * zoom;

    if (adjustedSpacing > 5) {
      for (double x = 0; x < size.width; x += adjustedSpacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }

      for (double y = 0; y < size.height; y += adjustedSpacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(N8NGridPainter oldDelegate) => oldDelegate.zoom != zoom;
}