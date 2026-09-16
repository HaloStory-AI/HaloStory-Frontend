import 'package:flutter/material.dart';
import '../welcome/night_sky_background.dart';

/// Scaffold auth dengan background langit malam. Dipakai login/register/forgot.
/// Mobile & desktop sama: centered single card (kaca blur).
class StarryAuthScaffold extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const StarryAuthScaffold({
    super.key,
    required this.child,
    this.maxWidth = 420,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030014),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const Positioned.fill(child: NightSkyBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
