import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/pipeline_controller.dart';
import '../../models/pipeline_node.dart';
import 'connection_dot.dart';

class PipelineBlockWidget extends StatefulWidget {
  final PipelineNode node;
  final GlobalKey canvasKey;
  final double zoom;
  final Function(String, bool, Offset)? onConnectionDragStart;
  final Function(Offset)? onConnectionDragUpdate;
  final Function()? onConnectionDragEnd;

  const PipelineBlockWidget({
    Key? key,
    required this.node,
    required this.canvasKey,
    required this.zoom,
    this.onConnectionDragStart,
    this.onConnectionDragUpdate,
    this.onConnectionDragEnd,
  }) : super(key: key);

  @override
  State<PipelineBlockWidget> createState() => _PipelineBlockWidgetState();
}

class _PipelineBlockWidgetState extends State<PipelineBlockWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
    _shadowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PipelineController>();

    return Obx(() {
      final isSelected = controller.selectedNode.value == widget.node.id;

      return AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: MouseRegion(
              onEnter: (_) {
                setState(() => _isHovering = true);
                _hoverController.forward();
              },
              onExit: (_) {
                setState(() => _isHovering = false);
                _hoverController.reverse();
              },
              child: GestureDetector(
                onTap: () {
                  controller.selectNode(isSelected ? null : widget.node.id);
                },
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Main block
                    _buildMainBlock(isSelected),
                    // Connection dots
                    _buildConnectionDots(),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Widget _buildMainBlock(bool isSelected) {
    return Draggable<PipelineNode>(
      data: widget.node,
      feedback: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(12),
        child: _buildBlockContent(isDragging: true),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildBlockContent(),
      ),
      onDragEnd: (details) {
        final renderBox =
            widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox != null) {
          final localOffset = renderBox.globalToLocal(details.offset);
          Get.find<PipelineController>().updateNodePosition(
            widget.node.id,
            localOffset,
          );
        }
      },
      child: _buildBlockContent(isSelected: isSelected),
    );
  }

  Widget _buildBlockContent(
      {bool isDragging = false, bool isSelected = false}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 180,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? widget.node.primaryColor
              : (isDragging
                  ? widget.node.primaryColor.withOpacity(0.5)
                  : const Color(0xFFE2E8F0)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withOpacity(isDragging ? 0.25 : (isSelected ? 0.15 : 0.08)),
            blurRadius: isDragging ? 20 : (isSelected ? 12 : 8),
            offset: Offset(0, isDragging ? 8 : (isSelected ? 4 : 2)),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon section
          Container(
            width: 50,
            height: 60,
            decoration: BoxDecoration(
              color: widget.node.backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
            child: Center(
              child: Icon(
                widget.node.icon,
                color: widget.node.primaryColor,
                size: 24,
              ),
            ),
          ),
          // Content section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.node.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: Text(
                      widget.node.description,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Status indicator or Run button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GetBuilder<PipelineController>(
              id: widget.node.id,
              builder: (_) {
                // Show Stop button if running
                if (widget.node.status == BlockStatus.running) {
                  return InkWell(
                    onTap: () {
                      Get.find<PipelineController>().stopNode(widget.node.id);
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.stop_rounded,
                        color: Colors.red,
                        size: 16,
                      ),
                    ),
                  );
                }

                // Show Run button on hover if ready
                if (_isHovering && widget.node.status == BlockStatus.ready) {
                  return InkWell(
                    onTap: () {
                      Get.find<PipelineController>()
                          .executeNode(widget.node.id);
                    },
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: widget.node.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: widget.node.primaryColor,
                        size: 16,
                      ),
                    ),
                  );
                }
                return _buildStatusIndicator();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionDots() {
    return SizedBox(
      width: 180, // Match main block width
      height: 60, // Match main block height
      child: Stack(
        clipBehavior: Clip.none, // Allow dots to render outside bounds
        children: [
          // Input dot (left side)
          if (widget.node.category != BlockCategory.input)
            Positioned(
              left: -6,
              top: 24,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ConnectionDot(
                  nodeId: widget.node.id,
                  isOutput: false,
                  color: widget.node.primaryColor,
                  canvasKey: widget.canvasKey,
                  onDragStart: widget.onConnectionDragStart,
                  onDragUpdate: widget.onConnectionDragUpdate,
                  onDragEnd: widget.onConnectionDragEnd,
                ),
              ),
            ),
          // Output dot (right side)
          if (widget.node.category != BlockCategory.output)
            Positioned(
              right: -6,
              top: 24,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: ConnectionDot(
                  nodeId: widget.node.id,
                  isOutput: true,
                  color: widget.node.primaryColor,
                  canvasKey: widget.canvasKey,
                  onDragStart: widget.onConnectionDragStart,
                  onDragUpdate: widget.onConnectionDragUpdate,
                  onDragEnd: widget.onConnectionDragEnd,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    switch (widget.node.status) {
      case BlockStatus.idle:
        return Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFFCBD5E1),
            shape: BoxShape.circle,
          ),
        );

      case BlockStatus.checking:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(
                widget.node.primaryColor.withOpacity(0.5)),
          ),
        );

      case BlockStatus.downloading:
        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                value: widget.node.downloadProgress,
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(widget.node.primaryColor),
                backgroundColor: widget.node.primaryColor.withOpacity(0.2),
              ),
            ),
            Text(
              '${(widget.node.downloadProgress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 6,
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        );

      case BlockStatus.ready:
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.check,
            color: Colors.white,
            size: 10,
          ),
        );

      case BlockStatus.pending:
        return Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color(0xFF94A3B8),
            shape: BoxShape.circle,
          ),
        );

      case BlockStatus.running:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(widget.node.primaryColor),
          ),
        );

      case BlockStatus.success:
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFF10B981),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.check,
            color: Colors.white,
            size: 10,
          ),
        );

      case BlockStatus.failed:
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.close,
            color: Colors.white,
            size: 10,
          ),
        );

      case BlockStatus.error:
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.warning,
            color: Colors.white,
            size: 10,
          ),
        );
    }
  }
}
