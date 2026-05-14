import 'package:flutter/material.dart';
import '../../utils/chat_theme_helpers.dart';

class DesktopOverlay extends StatelessWidget {
  final String overlayType; // 'bio' or 'bond'
  final Widget child;
  final VoidCallback onClose;

  const DesktopOverlay({
    super.key,
    required this.overlayType,
    required this.child,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 650),
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: surfaceBackground(context),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  child,
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      onPressed: onClose,
                      icon: Icon(Icons.close, color: subtitleColor(context)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
