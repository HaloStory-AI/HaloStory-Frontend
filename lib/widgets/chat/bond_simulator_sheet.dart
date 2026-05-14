import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../constants.dart';
import '../../services/auth_service.dart';
import '../../utils/chat_theme_helpers.dart';

class BondSimulatorSheet extends StatelessWidget {
  final Map<String, dynamic> bot;
  final VoidCallback onBondChanged;

  const BondSimulatorSheet({
    super.key,
    required this.bot,
    required this.onBondChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Bond Simulator (God Mode)",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => _simulateBond(context, xp: 1000),
                child: const Text("+1k XP"),
              ),
              ElevatedButton(
                onPressed: () => _simulateBond(context, level: 25),
                child: const Text("Lv 25"),
              ),
              ElevatedButton(
                onPressed: () => _simulateBond(context, level: 100),
                child: const Text("Lv 100"),
              ),
              ElevatedButton(
                onPressed: () => _simulateBond(context, level: 150),
                child: const Text("Lv 150"),
              ),
              ElevatedButton(
                onPressed: () => _handleBondEvent(context, 'confession_triggered'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Trigger Confession"),
              ),
              ElevatedButton(
                onPressed: () => _handleBondEvent(context, 'marriage_triggered'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Trigger Marriage"),
              ),
              ElevatedButton(
                onPressed: () => _simulateBond(context, reset: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text(
                  "Reset Bond",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            "Note: Changes on server will sync on next message or refresh",
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _simulateBond(BuildContext context, {int? xp, int? level, bool reset = false}) async {
    final token = await AuthService().getToken();
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.baseUrl}/bots/bond/${bot['id']}/debug'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'xp': xp,
          'level': level,
          if (reset) 'reset': true,
        }),
      );

      if (response.statusCode == 200) {
        onBondChanged();
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Simulasi Berhasil!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Simulasi Gagal: ${response.statusCode} - ${errorData['error'] ?? 'Unknown Error'}",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Simulator Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleBondEvent(BuildContext context, String event) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Event triggered: $event. AI will handle dialogue.'),
        backgroundColor: Colors.pink.shade400,
      ),
    );
  }
}
