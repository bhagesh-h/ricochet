import 'dart:math';
import 'package:vector_math/vector_math_64.dart' hide Colors;
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
  
  // Base canvas dimensions
  static const double _baseCanvasWidth = 8000;
  static const double _baseCanvasHeight = 5000;
  
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
        color: Color.fromARGB(255, 0, 0, 0),
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
              minScale: 0.1, // Let InteractiveViewer handle all scaling
              maxScale: 5.0,
              boundaryMargin: const EdgeInsets.all(100),
              constrained: false,
              child: DragTarget<String>(
                onWillAccept: (data) => true,
                onAcceptWithDetails: (details) {
                  // Get the InteractiveViewer's render box for coordinate conversion
                  final RenderBox? viewerRenderBox = context.findRenderObject() as RenderBox?;
                  if (viewerRenderBox != null) {
                    // Convert global position to local InteractiveViewer coordinates
                    final localOffset = viewerRenderBox.globalToLocal(details.offset);
                    
                    // Get current transformation matrix
                    final matrix = _transformationController.value;
                    final scale = matrix.getMaxScaleOnAxis();
                    final translation = matrix.getTranslation();
                    
                    // Convert screen coordinates to canvas logical coordinates
                    // Remove the pan offset and scale to get logical canvas position
                    final canvasX = (localOffset.dx - translation.x) / scale;
                    final canvasY = (localOffset.dy - translation.y) / scale;
                    
                    final dropPosition = Offset(canvasX, canvasY);
                    controller.addNode(details.data, dropPosition);
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  return Obx(() {
                    return Container(
                      key: _canvasKey,
                      width: _baseCanvasWidth,
                      height: _baseCanvasHeight,
                      child: Stack(
                        children: [
                          // Grid background
                          CustomPaint(
                            size: Size(_baseCanvasWidth, _baseCanvasHeight),
                            painter: N8NGridPainter(zoom: _currentZoom),
                          ),
                          // Connection lines
                          CustomPaint(
                            size: Size(_baseCanvasWidth, _baseCanvasHeight),
                            painter: N8NConnectionPainter(
                              nodes: controller.nodes,
                              connections: controller.connections,
                            ),
                          ),
                          // Temporary drag connection line
                          if (_dragStartPoint != null && _dragCurrentPoint != null)
                            CustomPaint(
                              size: Size(_baseCanvasWidth, _baseCanvasHeight),
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
                      ),
                    );
                  });
                },
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
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final Offset localPosition = renderBox.globalToLocal(event.position);
    final double zoomDelta = event.scrollDelta.dy > 0 ? -0.1 : 0.1;
    final double newZoom = (_currentZoom + zoomDelta).clamp(_minZoom, _maxZoom);
    
    if (newZoom != _currentZoom) {
      // Calculate zoom center point
      final Matrix4 matrix = _transformationController.value;
      final Vector3 translation = matrix.getTranslation();
      final double currentScale = matrix.getMaxScaleOnAxis();
      
      // Calculate the point we're zooming towards in canvas coordinates
      final double canvasX = (localPosition.dx - translation.x) / currentScale;
      final double canvasY = (localPosition.dy - translation.y) / currentScale;
      
      setState(() {
        _currentZoom = newZoom;
      });
      
      // Adjust pan to keep zoom center point stable
      final double newTranslationX = localPosition.dx - (canvasX * currentScale);
      final double newTranslationY = localPosition.dy - (canvasY * currentScale);
      
      final Matrix4 newMatrix = Matrix4.identity()
        ..translate(newTranslationX, newTranslationY)
        ..scale(currentScale);
      
      _transformationController.value = newMatrix;
    }
  }

  void startConnectionDrag(String nodeId, bool isOutput, Offset startPoint) {
    // Convert the startPoint to account for current zoom and pan
    final matrix = _transformationController.value;
    final translation = matrix.getTranslation();
    final scale = matrix.getMaxScaleOnAxis();
    
    // Transform the point to canvas coordinates
    final transformedPoint = Offset(
      startPoint.dx * _currentZoom * scale + translation.x,
      startPoint.dy * _currentZoom * scale + translation.y,
    );
    
    setState(() {
      _dragSourceNodeId = nodeId;
      _isOutputDrag = isOutput;
      _dragStartPoint = transformedPoint;
      _dragCurrentPoint = transformedPoint;
    });
  }

  void updateConnectionDrag(Offset currentPoint) {
    // Convert the current point to account for current zoom and pan
    final matrix = _transformationController.value;
    final translation = matrix.getTranslation();
    final scale = matrix.getMaxScaleOnAxis();
    
    final transformedPoint = Offset(
      currentPoint.dx * _currentZoom * scale + translation.x,
      currentPoint.dy * _currentZoom * scale + translation.y,
    );
    
    setState(() {
      _dragCurrentPoint = transformedPoint;
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
      // Maintain current InteractiveViewer transformation during zoom animation
      // Don't reset the transformation matrix during button zoom
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
      ..strokeWidth = 0.5 / zoom; // Adjust stroke width for zoom

    const spacing = 20.0;
    
    // Grid maintains consistent logical spacing
    // Transform.scale handles visual scaling
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(N8NGridPainter oldDelegate) => oldDelegate.zoom != zoom;
}

// Additional helper class for better zoom handling in InteractiveViewer
class ZoomAwareInteractiveViewer extends StatefulWidget {
  final Widget child;
  final double minScale;
  final double maxScale;
  final TransformationController? transformationController;
  final Function(double)? onZoomChanged;

  const ZoomAwareInteractiveViewer({
    Key? key,
    required this.child,
    this.minScale = 0.1,
    this.maxScale = 10.0,
    this.transformationController,
    this.onZoomChanged,
  }) : super(key: key);

  @override
  State<ZoomAwareInteractiveViewer> createState() => _ZoomAwareInteractiveViewerState();
}

class _ZoomAwareInteractiveViewerState extends State<ZoomAwareInteractiveViewer> {
  late TransformationController _controller;
  double _lastScale = 1.0;

  @override
  void initState() {
    super.initState();
    _controller = widget.transformationController ?? TransformationController();
    _controller.addListener(_onTransformationChanged);
  }

  @override
  void dispose() {
    if (widget.transformationController == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTransformationChanged);
    }
    super.dispose();
  }

  void _onTransformationChanged() {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    if (currentScale != _lastScale) {
      _lastScale = currentScale;
      widget.onZoomChanged?.call(currentScale);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      boundaryMargin: const EdgeInsets.all(100),
      constrained: false,
      child: widget.child,
    );
  }
}

// Optional: Enhanced N8NBlockWidget that adapts to zoom levels
class ZoomAdaptiveN8NBlockWidget extends StatelessWidget {
  final dynamic node;
  final GlobalKey canvasKey;
  final double zoom;
  final Function(String, bool, Offset)? onConnectionDragStart;
  final Function(Offset)? onConnectionDragUpdate;
  final Function()? onConnectionDragEnd;

  const ZoomAdaptiveN8NBlockWidget({
    Key? key,
    required this.node,
    required this.canvasKey,
    required this.zoom,
    this.onConnectionDragStart,
    this.onConnectionDragUpdate,
    this.onConnectionDragEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Adapt sizes based on zoom level
    final double adaptedFontSize = (14 / zoom).clamp(10, 18);
    final double adaptedPadding = (12 / zoom).clamp(8, 16);
    final double adaptedBorderRadius = (8 / zoom).clamp(4, 12);
    final double adaptedIconSize = (20 / zoom).clamp(14, 24);

    return Container(
      constraints: BoxConstraints(
        minWidth: 200 / zoom,
        maxWidth: 300 / zoom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(adaptedBorderRadius),
        border: Border.all(
          color: node.isSelected ? Colors.blue : Colors.grey.shade300,
          width: (node.isSelected ? 2 : 1) / zoom,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4 / zoom,
            offset: Offset(0, 2 / zoom),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with adapted styling
          Container(
            padding: EdgeInsets.all(adaptedPadding),
            decoration: BoxDecoration(
              color: node.primaryColor?.withOpacity(0.1) ?? Colors.grey.shade100,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(adaptedBorderRadius),
                topRight: Radius.circular(adaptedBorderRadius),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  node.icon ?? Icons.widgets,
                  size: adaptedIconSize,
                  color: node.primaryColor ?? Colors.grey,
                ),
                SizedBox(width: 8 / zoom),
                Expanded(
                  child: Text(
                    node.title ?? 'Node',
                    style: TextStyle(
                      fontSize: adaptedFontSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Content area with adapted padding
          Container(
            padding: EdgeInsets.all(adaptedPadding),
            child: Text(
              node.description ?? '',
              style: TextStyle(
                fontSize: adaptedFontSize - 2,
                color: Colors.grey.shade600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}