import 'package:flutter/material.dart';
import '../../services/localization_service.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.home_rounded, size: 48, color: cs.primary),
          const SizedBox(height: 12),
          Text(tr('tab_home'),
              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
