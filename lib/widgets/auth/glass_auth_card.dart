import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/localization_service.dart';

/// Kartu kaca auth — layout header sama dengan WelcomeHeadlineCard:
/// logo bulan sabit + Mikazuki AI + welcome_subtitle, lalu child form.
class GlassAuthCard extends StatelessWidget {
  final Widget child;
  final Widget? leading;

  const GlassAuthCard({super.key, required this.child, this.leading});

  @override
  Widget build(BuildContext context) {
    const kLogo = 'assets/icon/mikazuki/mikazuki_512.png';
    final textTheme = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF030014).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 24, offset: Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (leading != null) ...[
                Align(alignment: Alignment.centerLeft, child: leading!),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Image.asset(kLogo, width: 44, height: 44, filterQuality: FilterQuality.high),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Mikazuki AI',
                          style: textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('welcome_subtitle'),
                          softWrap: true,
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF9CA8BC),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
