import 'dart:async';
import 'dart:io'
    show Platform, HttpClient, HttpOverrides, SecurityContext, X509Certificate;
import 'package:bluetalk_frontend/notifier/bottomnav_provider.dart';
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
import 'package:bluetalk_frontend/services/auth_service.dart';
import 'package:bluetalk_frontend/screens/login_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
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

  Connectivity().onConnectivityChanged.skip(1).listen((
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

  AuthService.onSessionExpired.listen((_) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    showModalBottomSheet(
      context: ctx,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => PopScope(
        canPop: false,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Icon(
                Icons.timer_off_rounded,
                size: 64,
                color: Theme.of(sheetContext).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                tr('session_expired_title'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(sheetContext).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr('session_expired_message'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    navigatorKey.currentState?.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(sheetContext).colorScheme.primary,
                    foregroundColor: Theme.of(
                      sheetContext,
                    ).colorScheme.onPrimary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(tr('session_expired_btn')),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  });

  runApp(
    ChangeNotifierProvider(
      create: (context) => BottomNavProvider(),
      child: const HaloStoryApp(),
    ),
  );
}

class HaloStoryApp extends StatelessWidget {
  const HaloStoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        LocalizationService(),
        ThemeService(),
        WallpaperService(),
      ]),
      builder: (context, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          title: 'HaloStory',
          debugShowCheckedModeBanner: true,
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
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
          return host.endsWith('coudinray.com') ||
              host.endsWith('cloudinary.com');
        };
    return client;
  }
}
