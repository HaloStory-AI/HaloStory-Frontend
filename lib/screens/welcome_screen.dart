import 'package:flutter/material.dart';
import '../widgets/welcome/night_sky_background.dart';
import '../widgets/welcome/welcome_headline_card.dart';

/// Welcome ala Welcome.vue Mikazuki web: langit malam + bintang jatuh
/// sebagai background, fore.png sebagai foreground, kartu headline glass
/// berisi tombol Login/Register. Tanpa login Google, tanpa navbar.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const double _desktopBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.of(context).size.width >= _desktopBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFF030014),
      body: isDesktop ? _buildDesktop() : _buildMobile(),
    );
  }

  /// Mobile: Stack — background + foreground cover full-bleed di belakang,
  /// kartu headline di tengah (seperti web).
  Widget _buildMobile() {
    return const Stack(
      fit: StackFit.expand,
      children: [
        NightSkyBackground(),
        _ForegroundCover(),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
              child: WelcomeHeadlineCard(maxWidth: 380),
            ),
          ),
        ),
      ],
    );
  }

  /// Desktop: kiri kartu headline overlay setengah-lebar, kanan
  /// fore.png contain full-height (pola web md:w-1/2).
  Widget _buildDesktop() {
    return const Stack(
      fit: StackFit.expand,
      children: [
        NightSkyBackground(),
        Row(
          children: [
            Expanded(
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding:
                        EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                    child: WelcomeHeadlineCard(maxWidth: 420),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _ForegroundContain(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Foreground mobile: object-cover full-bleed di belakang kartu.
class _ForegroundCover extends StatelessWidget {
  const _ForegroundCover();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/image/fore.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      excludeFromSemantics: true,
    );
  }
}

/// Foreground desktop: object-contain, full-height di setengah kanan.
class _ForegroundContain extends StatelessWidget {
  const _ForegroundContain();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/image/fore.png',
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.centerRight,
      excludeFromSemantics: true,
    );
  }
}
