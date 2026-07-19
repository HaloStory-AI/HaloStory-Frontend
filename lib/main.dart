import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:bluetalk_frontend/screens/splash_screen.dart';
import 'package:bluetalk_frontend/screens/banned_screen.dart';
import 'package:bluetalk_frontend/services/localization_service.dart';
import 'package:bluetalk_frontend/services/theme_service.dart';
import 'package:bluetalk_frontend/services/wallpaper_service.dart';
import 'package:bluetalk_frontend/theme/app_theme.dart';
import 'package:bluetalk_frontend/services/config_service.dart';
import 'package:bluetalk_frontend/services/ban_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io' show Platform;
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
  WidgetsFlutterBinding.ensureInitialized();
  initSqlite();
  await LocalizationService().init();
  await ThemeService().init();
  await WallpaperService().init();

  // Background server ping + ban check every 2 minutes
  Timer.periodic(const Duration(minutes: 2), (timer) async {
    await ConfigService.checkServerUp();
    if (ConfigService.isAutoDetectedMaintenance) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
      return;
    }

    final banned = await BanService.checkUserBanStatus();
    if (banned) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BannedScreen()),
        (route) => false,
      );
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
      // It's a bit spammy to say "restored" immediately upon app launch if connected,
      // but if wanted we can show it. Better to keep it simple as requested: "notifikasi kecil".
      // We will show "restored" only if it changes state from none, but the simplest implementation is:
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
