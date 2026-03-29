import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/localization_service.dart';

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  String _version = '...';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = packageInfo.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          tr('sidebar_info'),
          style: const TextStyle(color: Colors.black, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            SvgPicture.asset(
              'assets/icon/momo_logo.svg',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(
                Color(0xFF135ACF),
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 24),

            // App Name
            const Text(
              'BlueTalk',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),

            // Version
            Text(
              '${tr('app_info_version')} $_version',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 48),

            // Copyright
            Text(
              '© ${DateTime.now().year} R8K Studio',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),

            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                showLicensePage(
                  context: context,
                  applicationName: 'BlueTalk',
                  applicationVersion: _version,
                  applicationIcon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SvgPicture.asset(
                      'assets/icon/momo_logo.svg',
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF135ACF),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                );
              },
              child: Text(
                tr('app_info_license'),
                style: const TextStyle(color: Color(0xFF135ACF)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
