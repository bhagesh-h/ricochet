import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:Ricochet/models/pipeline_node.dart';
import 'widgets/connection_painter.dart';
import 'package:Ricochet/views/widgets/parameter_sidebar.dart';
import '../controllers/pipeline_controller.dart';
import 'widgets/pipeline_block_widget.dart';

class PipelineCanvas extends StatefulWidget {
  const PipelineCanvas({Key? key}) : super(key: key);

  @override
  State<PipelineCanvas> createState() => _PipelineCanvasState();
}

class _PipelineCanvasState extends State<PipelineCanvas>
    with TickerProviderStateMixin {
  final GlobalKey _canvasKey = GlobalKey();
  final FocusNode _focusNode = FocusNode();
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _fitAnimationController;
  Animation<Matrix4>? _fitAnimation;

  double _currentZoom = 1.0;
  static const double _minZoom = 0.1;
  static const double _maxZoom = 5.0;

  // Infinite canvas dimensions - effectively infinite for practical purposes
  static const double _canvasSize = 50000;

  // For drag connection visualization
  Offset? _dragStartPoint;
  Offset? _dragCurrentPoint;
  String? _dragSourceNodeId;


  @override
  void initState() {
    super.initState();
    _fitAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fitAnimationController.addListener(_onFitAnimationTick);
    _transformationController.addListener(_onTransformationChanged);

    // Center the view initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerView();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _fitAnimationController.dispose();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTransformationChanged() {
    setState(() {
      _currentZoom = _transformationController.value.getMaxScaleOnAxis();
    });
  }

  @override
  Widget build(BuildContext context) {
    final PipelineController controller = Get.find();

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(node, event, controller),
      child: GestureDetector(
        // Tap on empty canvas → deselect node & hovered connection
        onTap: () {
          controller.deselectAll();
          _focusNode.requestFocus();
        },
        child: Container(
          color: const Color(0xFFF7F8FA),
          child: Stack(
            children: [
              // Optimized Grid Background - Draws only what's visible
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: N8NGridPainter(
                      transformationController: _transformationController,
                    ),
                  ),
                ),
              ),

              // Main canvas area
              DragTarget<String>(
                onAcceptWithDetails: (details) {
                  _handleDropFromSidebar(details);
                },
                builder: (context, candidateData, rejectedData) {
                  return InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: _minZoom,
                    maxScale: _maxZoom,
                    boundaryMargin: const EdgeInsets.all(double.infinity),
                    constrained: false,
                    panEnabled: true,
                    scaleEnabled: true,
                    child: SizedBox(
                      width: _canvasSize,
                      height: _canvasSize,
                      child: Stack(
                        key: _canvasKey,
                        children: [
                          // Clickable connection lines layer
                          Positioned.fill(
                            child: _buildClickableConnections(controller),
                          ),

                          // Temporary drag connection line
                          if (_dragStartPoint != null && _dragCurrentPoint != null)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _DragConnectionPainter(
                                  startPoint: _dragStartPoint!,
                                  endPoint: _dragCurrentPoint!,
                                  color: _getDragConnectionColor(),
                                ),
                              ),
                            ),

                          // Nodes
                          _buildNodes(controller),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Floating Fit View button
              Positioned(
                right: 20,
                bottom: 280,
                child: _buildFitViewButton(),
              ),

              // Reset Zoom button
              Positioned(
                right: 20,
                bottom: 220,
                child: _buildResetZoomButton(),
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
                  final node = controller.nodes
                      .firstWhereOrNull((n) => n.id == selectedNode);
                  if (node != null) {
                    return Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: ParameterSidebar(
                        key: ValueKey(node.id),
                        node: node,
                      ),
                    );
                  }
                }
                return const SizedBox();
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Keyboard shortcut handler ─────────────────────────────────────────────
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, PipelineController ctrl) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Do not intercept keystrokes if the user is typing in a text field
    if (!node.hasPrimaryFocus) return KeyEventResult.ignored;

    final isCtrl = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;

    // Ctrl+Z → undo
    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyZ &&
        !HardwareKeyboard.instance.isShiftPressed) {
      ctrl.undo();
      return KeyEventResult.handled;
    }

    // Ctrl+Shift+Z or Ctrl+Y → redo
    if (isCtrl && (event.logicalKey == LogicalKeyboardKey.keyY ||
        (event.logicalKey == LogicalKeyboardKey.keyZ &&
            HardwareKeyboard.instance.isShiftPressed))) {
      ctrl.redo();
      return KeyEventResult.handled;
    }

    // Delete / Backspace → delete selected node
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (ctrl.selectedNode.value != null) {
        ctrl.deleteNode(ctrl.selectedNode.value!);
        return KeyEventResult.handled;
      }
      // Delete selected connection (fix #2.2)
      if (ctrl.selectedConnectionId.value != null) {
        ctrl.deleteConnection(ctrl.selectedConnectionId.value!);
        return KeyEventResult.handled;
      }
    }

    // Escape → deselect
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      ctrl.deselectAll();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Builds the connection lines with a GestureDetector overlay for
  /// click-to-select/delete. Uses path hit-testing via sampling points.
  Widget _buildClickableConnections(PipelineController controller) {
    return Obx(() {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTapDown: (details) => _onConnectionLayerTap(details.localPosition, controller),
        child: CustomPaint(
          painter: ConnectionPainter(
            nodes: controller.nodes.toList(),
            connections: controller.connections.toList(),
            selectedConnectionId: controller.selectedConnectionId.value,
            cycleConnectionIds: controller.cycleConnectionIds.toList(),
          ),
        ),
      );
    });
  }

  void _onConnectionLayerTap(Offset tapPos, PipelineController ctrl) {
    const hitRadius = 12.0;
    String? hitId;

    for (final conn in ctrl.connections) {
      final from = ctrl.nodes.firstWhereOrNull((n) => n.id == conn.fromNodeId);
      final to   = ctrl.nodes.firstWhereOrNull((n) => n.id == conn.toNodeId);
      if (from == null || to == null) continue;

      final fromPt = Offset(from.position.dx + 180, from.position.dy + 30);
      final toPt   = Offset(to.position.dx, to.position.dy + 30);
      final cp1    = Offset(fromPt.dx + (toPt.dx - fromPt.dx) * 0.3, fromPt.dy);
      final cp2    = Offset(fromPt.dx + (toPt.dx - fromPt.dx) * 0.7, toPt.dy);

      // Sample 30 points along the cubic bezier and check distance to tap
      for (int i = 0; i <= 30; i++) {
        final t = i / 30;
        final mt = 1 - t;
        final pt = Offset(
          mt*mt*mt*fromPt.dx + 3*mt*mt*t*cp1.dx + 3*mt*t*t*cp2.dx + t*t*t*toPt.dx,
          mt*mt*mt*fromPt.dy + 3*mt*mt*t*cp1.dy + 3*mt*t*t*cp2.dy + t*t*t*toPt.dy,
        );
        if ((pt - tapPos).distance < hitRadius) {
          hitId = conn.id;
          break;
        }
      }
      if (hitId != null) break;
    }

    if (hitId != null) {
      ctrl.selectConnection(hitId);
      // Return keyboard focus to the canvas so Delete/Backspace is captured
      _focusNode.requestFocus();
    } else {
      ctrl.selectConnection(null);
    }
  }

  Widget _buildNodes(PipelineController controller) {
    return Obx(() {
      return Stack(
        children: controller.nodes.map((node) {
          return _buildNodeWidget(node);
        }).toList(),
      );
    });
  }

  Widget _buildNodeWidget(PipelineNode node) {
    return Positioned(
      left: node.position.dx,
      top: node.position.dy,
      child: _DraggableNode(
        key: ValueKey(node
            .id), // CRITICAL: Key ensures state preservation during rebuilds
        node: node,
        canvasKey: _canvasKey,
        transformationController: _transformationController,
        onConnectionDragStart: startConnectionDrag,
        onConnectionDragUpdate: updateConnectionDrag,
        onConnectionDragEnd: endConnectionDrag,
      ),
    );
  }

  Widget _buildFitViewButton() {
    return FloatingActionButton(
      onPressed: _fitToNodes,
      mini: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue,
      child: const Icon(Icons.fit_screen),
      tooltip: 'Fit Workflow',
    );
  }

  Widget _buildResetZoomButton() {
    return FloatingActionButton(
      onPressed: _centerView,
      mini: true,
      backgroundColor: Colors.white,
      foregroundColor: Colors.green,
      child: const Icon(Icons.refresh),
      tooltip: 'Reset View',
    );
  }

  void _centerView() {
    final size = MediaQuery.of(context).size;
    // Center the view on the virtual center (25000, 25000)
    // We want (25000, 25000) to be at (size.width/2, size.height/2)
    const double centerX = _canvasSize / 2;
    const double centerY = _canvasSize / 2;

    final matrix = Matrix4.identity()
      ..translate(
        -centerX + size.width / 2,
        -centerY + size.height / 2,
      )
      ..scale(1.0);

    _animateToMatrix(matrix);
  }

  void _animateToMatrix(Matrix4 targetMatrix) {
    _fitAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _fitAnimationController,
      curve: Curves.easeInOut,
    ));
    _fitAnimationController.forward(from: 0);
  }

  void _fitToNodes() {
    final controller = Get.find<PipelineController>();
    if (controller.nodes.isEmpty) {
      _centerView();
      return;
    }

    final size = MediaQuery.of(context).size;
    Rect nodeBounds = _calculateNodesBoundingBox(controller.nodes);

    // Add some padding
    nodeBounds = nodeBounds.inflate(100);

    final scaleX = size.width / nodeBounds.width;
    final scaleY = size.height / nodeBounds.height;
    final scale = math.min(scaleX, scaleY).clamp(_minZoom, _maxZoom);

    final matrix = Matrix4.identity()
      ..translate(
        size.width / 2 - nodeBounds.center.dx * scale,
        size.height / 2 - nodeBounds.center.dy * scale,
      )
      ..scale(scale);

    _animateToMatrix(matrix);
  }

  Rect _calculateNodesBoundingBox(List<PipelineNode> nodes) {
    if (nodes.isEmpty) return Rect.zero;

    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final node in nodes) {
      minX = math.min(minX, node.position.dx);
      minY = math.min(minY, node.position.dy);
      // Assume node size is roughly 180x60
      maxX = math.max(maxX, node.position.dx + 180);
      maxY = math.max(maxY, node.position.dy + 60);
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _onFitAnimationTick() {
    if (_fitAnimation != null) {
      _transformationController.value = _fitAnimation!.value;
    }
  }

  void startConnectionDrag(String nodeId, bool isOutput, Offset startPoint) {
    setState(() {
      _dragSourceNodeId = nodeId;
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
      final node =
          controller.nodes.firstWhereOrNull((n) => n.id == _dragSourceNodeId);
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
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  '${(_currentZoom * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
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
    final newZoom = (_currentZoom + 0.2).clamp(_minZoom, _maxZoom);
    _animateZoom(newZoom);
  }

  void _zoomOut() {
    final newZoom = (_currentZoom - 0.2).clamp(_minZoom, _maxZoom);
    _animateZoom(newZoom);
  }

  void _animateZoom(double targetZoom) {
    // Zoom towards the center of the viewport
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);

    // Current matrix
    final matrix = _transformationController.value;

    // Calculate translation to keep center fixed
    final translation = matrix.getTranslation();
    final currentTranslation = Offset(translation.x, translation.y);
    final currentScale = matrix.getMaxScaleOnAxis();
    final scaleChange = targetZoom / currentScale;

    final offset = center - (center - currentTranslation) * scaleChange;

    final newMatrix = Matrix4.identity()
      ..translate(offset.dx, offset.dy)
      ..scale(targetZoom);

    _animateToMatrix(newMatrix);
  }

  void _handleDropFromSidebar(DragTargetDetails<String> details) {
    final controller = Get.find<PipelineController>();

    // Convert screen coordinates to canvas coordinates
    final canvasPosition = _screenToCanvasCoordinates(details.offset);

    // Add node at the calculated position
    // Adjust for node center (assuming 180x60 node size)
    final nodePosition = canvasPosition - const Offset(90, 30);

    controller.addNode(details.data, nodePosition);
  }

  Offset _screenToCanvasCoordinates(Offset screenPosition) {
    final RenderBox? renderBox =
        _canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return Offset.zero;

    // 1. Convert global screen position to the InteractiveViewer's local coordinate system
    // The renderBox here is the Stack inside the InteractiveViewer.
    // globalToLocal automatically accounts for the InteractiveViewer's transformation
    // because the RenderBox is transformed by it.
    final localOffset = renderBox.globalToLocal(screenPosition);
    return localOffset;
  }
}

// Draggable Node Wrapper
class _DraggableNode extends StatefulWidget {
  final PipelineNode node;
  final GlobalKey canvasKey;
  final TransformationController transformationController;
  final Function(String, bool, Offset)? onConnectionDragStart;
  final Function(Offset)? onConnectionDragUpdate;
  final Function()? onConnectionDragEnd;

  const _DraggableNode({
    Key? key,
    required this.node,
    required this.canvasKey,
    required this.transformationController,
    this.onConnectionDragStart,
    this.onConnectionDragUpdate,
    this.onConnectionDragEnd,
  }) : super(key: key);

  @override
  State<_DraggableNode> createState() => _DraggableNodeState();
}

class _DraggableNodeState extends State<_DraggableNode> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    // We use a custom GestureDetector for dragging to handle zoom correctly
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _isDragging = true;
        });
      },
      onPanUpdate: (details) {
        // Apply zoom factor to drag delta
        final zoom = widget.transformationController.value.getMaxScaleOnAxis();
        final delta = details.delta / zoom;

        final controller = Get.find<PipelineController>();
        final newPos = widget.node.position + delta;
        controller.updateNodePosition(widget.node.id, newPos);
      },
      onPanEnd: (details) {
        setState(() => _isDragging = false);
        // Write a single undo snapshot on drag-end (fix: was per-pixel before)
        Get.find<PipelineController>().finalizeNodeDrag(widget.node.id);
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.move,
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            color: _isDragging ? Colors.white.withOpacity(0.9) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  widget.node.primaryColor.withOpacity(_isDragging ? 0.7 : 0.3),
              width: _isDragging ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isDragging ? 0.15 : 0.08),
                blurRadius: _isDragging ? 12 : 8,
                offset: Offset(0, _isDragging ? 6 : 2),
              ),
            ],
          ),
          child: PipelineBlockWidget(
            node: widget.node,
            canvasKey: widget.canvasKey,
            zoom: 1.0, // Zoom is handled by InteractiveViewer
            onConnectionDragStart: widget.onConnectionDragStart,
            onConnectionDragUpdate: widget.onConnectionDragUpdate,
            onConnectionDragEnd: widget.onConnectionDragEnd,
          ),
        ),
      ),
    );
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

    canvas.drawLine(startPoint, endPoint, paint);
  }

  @override
  bool shouldRepaint(_DragConnectionPainter oldDelegate) {
    return oldDelegate.startPoint != startPoint ||
        oldDelegate.endPoint != endPoint ||
        oldDelegate.color != color;
  }
}

class N8NGridPainter extends CustomPainter {
  final TransformationController transformationController;

  N8NGridPainter({required this.transformationController})
      : super(repaint: transformationController);

  @override
  void paint(Canvas canvas, Size size) {
    final matrix = transformationController.value;
    final scale = matrix.getMaxScaleOnAxis();
    final translation = matrix.getTranslation();

    final paint = Paint()
      ..color = const Color(0xFFE2E8F0).withOpacity(0.5)
      ..strokeWidth = 1.0;

    const spacing = 20.0;

    // Calculate visible grid area
    // We need to draw grid lines that cover the viewport
    // The viewport size is 'size'
    // The grid moves with translation and scales with scale

    // Effective spacing on screen
    final effectiveSpacing = spacing * scale;

    // Offset of the grid origin on screen
    // This calculates where the first grid line should appear relative to the viewport's top-left corner
    // to align with the transformed grid.
    final offsetX = translation.x % effectiveSpacing;
    final offsetY = translation.y % effectiveSpacing;

    // Draw vertical lines
    for (double x = offsetX; x < size.width; x += effectiveSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = offsetY; y < size.height; y += effectiveSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(N8NGridPainter oldDelegate) => true;
}
