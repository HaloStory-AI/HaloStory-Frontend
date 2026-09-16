import 'package:flutter/material.dart';

class SettingsPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onBack;

  const SettingsPanel({
    super.key,
    required this.title,
    required this.child,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barColor = theme.scaffoldBackgroundColor;

    return Column(
      children: [
        Material(
          color: barColor,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: onBack,
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
