import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SafetyBar extends StatelessWidget {
  final VoidCallback onDismiss;

  const SafetyBar({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        border: Border(bottom: BorderSide(color: cs.error.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: cs.onErrorContainer, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("We care about your safety.", style: (tt.titleSmall ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)).copyWith(color: cs.onErrorContainer)),
                Text("If you are going through a difficult time, please know that you are not alone.", style: (tt.bodySmall ?? const TextStyle(fontSize: 12)).copyWith(color: cs.onErrorContainer.withValues(alpha: 0.8))),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => launchUrl(Uri.parse('https://findahelpline.com/')),
                  child: Text("Find a helpline →", style: (tt.labelMedium ?? const TextStyle(fontSize: 13)).copyWith(color: cs.onErrorContainer, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.close, color: cs.onErrorContainer, size: 20), onPressed: onDismiss),
        ],
      ),
    );
  }
}
