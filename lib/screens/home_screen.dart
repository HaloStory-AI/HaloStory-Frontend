import 'package:flutter/material.dart';
import '../responsive/responsive_layout.dart';
import 'mobile_home_screen.dart';
import 'desktop_home_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveLayout(
      mobile: MobileHomeScreen(),
      desktop: DesktopHomeScreen(),
    );
  }
}
