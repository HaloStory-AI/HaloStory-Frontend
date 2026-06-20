import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetyBar extends StatelessWidget {
  final VoidCallback onDismiss;

  const SafetyBar({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.redAccent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "We care about your safety.",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "If you are going through a difficult time, please know that you are not alone.",
                  style: TextStyle(
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () =>
                      launchUrl(Uri.parse('https://findahelpline.com/')),
                  child: const Text(
                    "Find a helpline →",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
