import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          tr('sidebar_info'),
          style: TextStyle(color: colorScheme.onSurface, fontSize: 18),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icon/mikazuki/mikazuki_512.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              cacheWidth: 200,
            ),
            const SizedBox(height: 24),

            Text(
              'Mikazuki AI',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            Text(
              '${tr('app_info_version')} $_version',
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 48),

            Text(
              '© ${DateTime.now().year} R8K Studio',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                showLicensePage(
                  context: context,
                  applicationName: 'Mikazuki AI',
                  applicationVersion: _version,
                  applicationIcon: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Image.asset(
                      'assets/icon/mikazuki/mikazuki_512.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      cacheWidth: 128,
                    ),
                  ),
                );
              },
              child: Text(
                tr('app_info_license'),
                style: TextStyle(color: colorScheme.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
