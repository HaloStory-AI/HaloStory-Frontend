import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key});

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  String _version = 'Loading...';

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
        title: const Text('Info Aplikasi', style: TextStyle(color: Colors.black, fontSize: 18)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/icon/icon.jpg', // Using the icon referenced in pubspec
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.chat_bubble, size: 100, color: Color(0xFF135ACF)),
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
              'Versi $_version',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 48),
            
            // Copyright
            Text(
              '© ${DateTime.now().year} R8K Studio',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
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
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset('assets/icon/icon.jpg', width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (ctx, err, st) => const Icon(Icons.chat_bubble, size: 64, color: Color(0xFF135ACF))),
                    ),
                  ),
                );
              },
              child: const Text('Lisensi Perangkat Lunak', style: TextStyle(color: Color(0xFF135ACF))),
            ),
          ],
        ),
      ),
    );
  }
}
