import 'package:flutter/material.dart';

class OverlayPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onClose;

  const OverlayPanel({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = theme.scaffoldBackgroundColor;

    return Material(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Material(
            color: barColor,
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onClose,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
