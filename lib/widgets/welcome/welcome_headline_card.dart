import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../screens/login_screen.dart';
import '../../screens/register_screen.dart';
import '../../utils/no_animation_route.dart';

/// Kartu headline glass ala Headline.vue: logo bulan sabit + brand
/// + tombol Login/Register. Tanpa login Google, tanpa navbar.
class WelcomeHeadlineCard extends StatelessWidget {
  final double maxWidth;

  const WelcomeHeadlineCard({super.key, this.maxWidth = 380});

  @override
  Widget build(BuildContext context) {
    const kLogo = 'assets/icon/mikazuki/mikazuki_512.png';
    final textTheme = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF030014).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 24,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              SizedBox(
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      noAnimationRoute(const LoginScreen()),
                    );
                  },
                  child: Text(tr('btn_login')),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      noAnimationRoute(const RegisterScreen()),
                    );
                  },
                  child: Text(tr('btn_register')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
