import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../main.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('BlueTalk'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthWrapper()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline,
              size: 100,
              color: Color(0xFF135ACF),
            ),
            const SizedBox(height: 24),
            const Text(
              'Welcome to BlueTalk!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You are successfully logged in.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
