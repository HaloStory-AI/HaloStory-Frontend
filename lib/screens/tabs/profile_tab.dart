import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/skeleton_loader.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final AuthService _authService = AuthService();
  late Future<Map<String, dynamic>?> _userProfile;

  @override
  void initState() {
    super.initState();
    _userProfile = _authService.getUserProfile();
  }

  Future<void> _refreshProfile() async {
    setState(() {
      _userProfile = _authService.getUserProfile(forceRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: FutureBuilder<Map<String, dynamic>?>(
      future: _userProfile,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const ProfileSkeleton();
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(tr('profile_load_error')),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _refreshProfile,
                  child: Text(tr('btn_retry')),
                ),
              ],
            ),
          );
        }

        final user = snapshot.data!;
        final String name = user['name'] ?? 'User Name';
        final String email = user['email'] ?? 'email@example.com';
        final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

        return RefreshIndicator(
          onRefresh: _refreshProfile,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF135ACF),
                      child: Text(
                        initial,
                        style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF212121)),
                    ),
                    Text(
                      email,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Account Info Section
              Text(
                tr('profile_account_info'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF135ACF)),
              ),
              const SizedBox(height: 15),
              _buildInfoTile(Icons.person_outline, tr('profile_full_name'), name),
              _buildInfoTile(Icons.email_outlined, tr('profile_email_address'), email),
              _buildInfoTile(Icons.calendar_today_outlined, tr('profile_joined'), user['created_at_human'] ?? tr('recently')),

              const SizedBox(height: 30),

              // Security Section
              Text(
                tr('profile_security'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF135ACF)),
              ),
              const SizedBox(height: 15),
              ListTile(
                leading: const Icon(Icons.lock_outline, color: Color(0xFF135ACF)),
                title: Text(tr('profile_change_password')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.verified_user_outlined, color: Color(0xFF135ACF)),
                title: Text(tr('profile_account_verification')),
                subtitle: Text(tr('profile_verified')),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
                onTap: () {},
              ),
            ],
          ),
        );
      },
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF135ACF), size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
