import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:n8n_application_2/views/widgets/draggable_connection_point.dart';
import 'package:n8n_application_2/views/widgets/n8n_block_widget.dart';
import '../../controllers/pipeline_controller.dart';

class ConnectionDot extends StatefulWidget {
  final String nodeId;
  final bool isOutput;
  final Color color;
  final GlobalKey canvasKey;
  final Function(String, bool, Offset)? onDragStart;
  final Function(Offset)? onDragUpdate;
  final Function()? onDragEnd;

  const ConnectionDot({
    Key? key,
    required this.nodeId,
    required this.isOutput,
    required this.color,
    required this.canvasKey,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  }) : super(key: key);

  @override
  State<ConnectionDot> createState() => _ConnectionDotState();
}

class _ConnectionDotState extends State<ConnectionDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovering = true);
        _pulseController.repeat(reverse: true);
      },
      onExit: (_) {
        setState(() => _isHovering = false);
        _pulseController.stop();
        _pulseController.reset();
      },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isHovering ? _pulseAnimation.value : 1.0,
            child: Draggable<ConnectionData>(
              data: ConnectionData(
                nodeId: widget.nodeId,
                isOutput: widget.isOutput,
              ),
              feedback: _buildDragFeedback(),
              childWhenDragging: _buildDot(isDragging: true),
              child: DragTarget<ConnectionData>(
                onWillAccept: (data) {
                  return data != null &&
                         data.nodeId != widget.nodeId &&
                         data.isOutput != widget.isOutput;
                },
                onAcceptWithDetails: (details) {
                  final sourceData = details.data;
                  final controller = Get.find<PipelineController>();
                  
                  if (widget.isOutput) {
                    controller.addConnection(widget.nodeId, sourceData.nodeId);
                  } else {
                    controller.addConnection(sourceData.nodeId, widget.nodeId);
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  final isHighlighted = candidateData.isNotEmpty;
                  return _buildDot(isHighlighted: isHighlighted);
                },
              ),
              onDragStarted: () {
                final renderBox = context.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  final offset = renderBox.localToGlobal(Offset.zero);
                  final canvasRenderBox = widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
                  if (canvasRenderBox != null) {
                    final localOffset = canvasRenderBox.globalToLocal(offset);
                    widget.onDragStart?.call(widget.nodeId, widget.isOutput, localOffset);
                  }
                }
              },
              onDragUpdate: (details) {
                final canvasRenderBox = widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
                if (canvasRenderBox != null) {
                  final localOffset = canvasRenderBox.globalToLocal(details.globalPosition);
                  widget.onDragUpdate?.call(localOffset);
                }
              },
              onDragEnd: (details) {
                widget.onDragEnd?.call();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildDot({bool isDragging = false, bool isHighlighted = false}) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: isHighlighted ? widget.color : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.color,
          width: isHighlighted ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(isHighlighted ? 0.5 : 0.3),
            blurRadius: isDragging ? 10 : (isHighlighted ? 6 : 4),
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }

  Widget _buildDragFeedback() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}