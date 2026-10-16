import 'dart:async';
import 'dart:io' show Platform, HttpClient, HttpOverrides, SecurityContext, X509Certificate;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:bluetalk_frontend/screens/splash_screen.dart';
import 'package:bluetalk_frontend/services/localization_service.dart';
import 'package:bluetalk_frontend/services/theme_service.dart';
import 'package:bluetalk_frontend/services/wallpaper_service.dart';
import 'package:bluetalk_frontend/theme/app_theme.dart';
import 'package:bluetalk_frontend/services/config_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void initSqlite() {
  if (kIsWeb) return;
  if (!Platform.isAndroid && !Platform.isIOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

void main() async {
  if (!kIsWeb) {
    HttpOverrides.global = _ImageHostHttpOverrides();
  }
  WidgetsFlutterBinding.ensureInitialized();
  initSqlite();
  await LocalizationService().init();
  await ThemeService().init();
  await WallpaperService().init();

  // Background server ping every 2 minutes
  Timer.periodic(const Duration(minutes: 2), (timer) async {
    await ConfigService.checkServerUp();
    if (ConfigService.isAutoDetectedMaintenance) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
      return;
    }
  });

  Connectivity().onConnectivityChanged.listen((
    List<ConnectivityResult> result,
  ) {
    if (result.contains(ConnectivityResult.none)) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(tr('internet_lost')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(tr('internet_restored')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  });

  runApp(const HaloStoryApp());
}

class HaloStoryApp extends StatelessWidget {
  const HaloStoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([LocalizationService(), ThemeService(), WallpaperService()]),
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          title: 'HaloStory',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme(),
          darkTheme: AppTheme.amoledTheme(),
          themeMode: ThemeService().themeMode,
          home: const SplashScreen(),
        );
      },
    );
  }
}

class _ImageHostHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      return host.endsWith('coudinray.com') || host.endsWith('cloudinary.com');
    };
    return client;
  }
}
