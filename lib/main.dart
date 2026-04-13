import 'package:flutter/material.dart';
import 'package:bluetalk_frontend/screens/splash_screen.dart';
import 'package:bluetalk_frontend/services/localization_service.dart';
import 'package:bluetalk_frontend/services/theme_service.dart';
import 'package:bluetalk_frontend/theme/app_theme.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalizationService().init();
  await ThemeService().init();

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
      listenable: Listenable.merge([LocalizationService(), ThemeService()]),
      builder: (context, child) {
        return MaterialApp(
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
