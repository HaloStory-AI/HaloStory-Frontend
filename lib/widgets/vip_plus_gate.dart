import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../constants.dart';

class VipPlusGate extends StatefulWidget {
  final Widget child;

  const VipPlusGate({super.key, required this.child});

  @override
  State<VipPlusGate> createState() => _VipPlusGateState();
}

class _VipPlusGateState extends State<VipPlusGate> {
  bool _isLoading = true;
  bool _needsSelection = false;
  List<Map<String, dynamic>> _models = [];
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final profile = await AuthService().getUserProfile();
    final role = profile?['role']?.toString();

    if (role != 'vip_plus') {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (profile?['vip_plus_model'] != null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final token = await AuthService().getToken();
      if (token == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/v1/vip-plus/models'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (mounted) {
          data.sort((a, b) => (a['urutan'] ?? 0).compareTo(b['urutan'] ?? 0));
          setState(() {
            _models = data.cast<Map<String, dynamic>>();
            _needsSelection = true;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectModel(int id) async {
    setState(() => _isSelecting = true);
    try {
      final token = await AuthService().getToken();
      if (token == null) return;
      final response = await http.put(
        Uri.parse('${AppConstants.baseUrl}/v1/vip-plus/model/$id'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        await AuthService().getUserProfile(forceRefresh: true);
        if (mounted) {
          setState(() => _needsSelection = false);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memilih model, coba lagi')),
          );
          setState(() => _isSelecting = false);
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan jaringan')),
        );
        setState(() => _isSelecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_needsSelection) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pilih Model VIP+')),
        body: _models.isEmpty
            ? const Center(child: Text('Tidak ada model tersedia'))
            : _buildGrid(),
      );
    }

    return widget.child;
  }

  Widget _buildGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _models.length,
      itemBuilder: (context, index) {
        final model = _models[index];
        final iconUrl = (isDark ? model['icon_dark'] : model['icon_light']) as String?;

        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _isSelecting ? null : () => _selectModel(model['id']),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (iconUrl != null && iconUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            iconUrl,
                            height: 48,
                            width: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              height: 48,
                              width: 48,
                              child: Icon(Icons.auto_awesome, size: 32),
                            ),
                          ),
                        )
                      else
                        const SizedBox(
                          height: 48,
                          width: 48,
                          child: Icon(Icons.auto_awesome, size: 32),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        model['nama_model'] ?? '',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Text(
                          model['deskripsi_model'] ?? '',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isSelecting)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
