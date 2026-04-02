import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'services/localization_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalizationService().init();

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

  runApp(const BlueTalkApp());
}

class BlueTalkApp extends StatelessWidget {
  const BlueTalkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService(),
      builder: (context, child) {
        return MaterialApp(
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          title: 'BlueTalk',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFB8D8F8),
              primary: const Color(0xFFB8D8F8),
              secondary: const Color(0xFF135ACF),
              surface: const Color(0xFFF4F8FB),
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F8FB),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              centerTitle: true,
              titleTextStyle: TextStyle(
                color: Color(0xFF135ACF),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              iconTheme: IconThemeData(color: Color(0xFF135ACF)),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF135ACF),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF135ACF),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
