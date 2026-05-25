import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// Reusable title bar window controls (Minimize, Maximize/Restore, Close)
/// designed to perfectly match the Ricochet light and dark themes.
class WindowButtons extends StatefulWidget {
  const WindowButtons({Key? key}) : super(key: key);

  @override
  State<WindowButtons> createState() => _WindowButtonsState();
}

class _WindowButtonsState extends State<WindowButtons> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximizedState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximizedState() async {
    try {
      final max = await windowManager.isMaximized();
      if (mounted) {
        setState(() {
          _isMaximized = max;
        });
      }
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    // macOS uses its native traffic lights on the top-left, so we hide these custom controls.
    if (Platform.isMacOS) {
      return const SizedBox.shrink();
    }

    final isLight = Theme.of(context).brightness == Brightness.light;
    final iconColor = isLight ? const Color(0xFF64748B) : Colors.white70;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TitleBarButton(
          icon: Icons.minimize_rounded,
          hoverColor: isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.06),
          iconColor: iconColor,
          onPressed: () => windowManager.minimize(),
        ),
        _TitleBarButton(
          icon: _isMaximized ? Icons.filter_none_rounded : Icons.crop_square_rounded,
          hoverColor: isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.06),
          iconColor: iconColor,
          onPressed: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _TitleBarButton(
          icon: Icons.close_rounded,
          hoverColor: const Color(0xFFE81123), // Microsoft Windows standard close hover red
          hoverIconColor: Colors.white,
          iconColor: iconColor,
          onPressed: () => windowManager.close(),
        ),
      ],
    );
  }
}

class _TitleBarButton extends StatefulWidget {
  final IconData icon;
  final Color hoverColor;
  final Color? hoverIconColor;
  final Color iconColor;
  final VoidCallback onPressed;

  const _TitleBarButton({
    required this.icon,
    required this.hoverColor,
    this.hoverIconColor,
    required this.iconColor,
    required this.onPressed,
  });

  @override
  State<_TitleBarButton> createState() => _TitleBarButtonState();
}

class _TitleBarButtonState extends State<_TitleBarButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          alignment: Alignment.center,
          color: _isHovered ? widget.hoverColor : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered && widget.hoverIconColor != null
                ? widget.hoverIconColor
                : widget.iconColor,
          ),
        ),
      ),
    );
  }
}
