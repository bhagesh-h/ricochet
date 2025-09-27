import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/pipeline_controller.dart';

class DraggableConnectionPoint extends StatefulWidget {
  final String nodeId;
  final bool isOutput;
  final Color color;
  final GlobalKey canvasKey;

  const DraggableConnectionPoint({
    Key? key,
    required this.nodeId,
    required this.isOutput,
    required this.color,
    required this.canvasKey,
  }) : super(key: key);

  @override
  State<DraggableConnectionPoint> createState() => _DraggableConnectionPointState();
}

class _DraggableConnectionPointState extends State<DraggableConnectionPoint>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Draggable<ConnectionData>(
            data: ConnectionData(
              nodeId: widget.nodeId,
              isOutput: widget.isOutput,
            ),
            feedback: _buildConnectionFeedback(),
            childWhenDragging: _buildConnectionPoint(isDragging: true),
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
                  // This is output, source should be input
                  controller.addConnection(widget.nodeId, sourceData.nodeId);
                } else {
                  // This is input, source should be output
                  controller.addConnection(sourceData.nodeId, widget.nodeId);
                }
              },
              builder: (context, candidateData, rejectedData) {
                final isHighlighted = candidateData.isNotEmpty;
                return _buildConnectionPoint(isHighlighted: isHighlighted);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionPoint({bool isDragging = false, bool isHighlighted = false}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isHighlighted ? widget.color : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.color,
          width: isDragging ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.color.withOpacity(0.3),
            blurRadius: isDragging ? 8 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        widget.isOutput ? Icons.arrow_forward : Icons.arrow_back,
        color: isHighlighted ? Colors.white : widget.color,
        size: 14,
      ),
    );
  }

  Widget _buildConnectionFeedback() {
    return Material(
      elevation: 8,
      shape: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          widget.isOutput ? Icons.arrow_forward : Icons.arrow_back,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }
}

class ConnectionData {
  final String nodeId;
  final bool isOutput;

  ConnectionData({
    required this.nodeId,
    required this.isOutput,
  });
}