import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class DonationScreen extends StatefulWidget {
  final bool isDesktopMiddlePanel;
  const DonationScreen({super.key, this.isDesktopMiddlePanel = false});

  @override
  State<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends State<DonationScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _authService.getUserProfile(forceRefresh: true);
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    }
  }

  bool get _isVip {
    if (_userProfile == null) return false;
    final role = _userProfile!['role'];
    if (role == 'admin' || role == 'sensei') return true;
    if (role == 'vip') {
      final expiresAt = _userProfile!['vip_expires_at'];
      if (expiresAt == null) return false;
      final expiryDate = DateTime.parse(expiresAt);
      return expiryDate.isAfter(DateTime.now());
    }
    return false;
  }

  String _getVipStatusText() {
    if (_userProfile == null) return tr('vip_status_inactive');
    final role = _userProfile!['role'];
    if (role == 'admin' || role == 'sensei') return tr('vip_status_admin');
    if (_isVip) return tr('vip_status_active');
    return tr('vip_status_inactive');
  }

  String? _getExpiryDate() {
    if (_userProfile == null) return null;
    final role = _userProfile!['role'];
    if (role == 'admin' || role == 'sensei') return null;
    final expiresAt = _userProfile!['vip_expires_at'];
    if (expiresAt == null) return null;
    final expiryDate = DateTime.parse(expiresAt);
    return DateFormat.yMMMMd(tr('settings_language_code')).format(expiryDate);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Colors.pinkAccent),
        ),
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final content = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Colors.blueGrey.shade900,
                  const Color(0xFF1A1A2E),
                ]
              : [
                  const Color(0xFFF0F4FF),
                  const Color(0xFFFFF0F5),
                ],
        ),
      ),
      child: SafeArea(
        top: !widget.isDesktopMiddlePanel,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.isDesktopMiddlePanel) ...[
                Text(
                  tr('sidebar_donation'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // VIP Status Information Card
              _buildVipStatusCard(context),
              
              const SizedBox(height: 30),
              
              Hero(
                tag: 'donation_icon',
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.pinkAccent.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.pinkAccent,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                tr('donation_title'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.blueGrey.shade800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tr('donation_content'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade600,
                ),
              ),
              const SizedBox(height: 40),
              
              // VIP Benefits Card
              _buildModernCard(
                context,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BenefitItem(
                      icon: Icons.bolt_rounded,
                      color: Colors.amber,
                      title: tr('vip_benefit_priority'),
                      subtitle: "Akses eksklusif ke model Gemini tercepat & terstabil.",
                    ),
                    const SizedBox(height: 20),
                    _BenefitItem(
                      icon: Icons.key_rounded,
                      color: Colors.blueAccent,
                      title: tr('vip_benefit_fallback'),
                      subtitle: "Minim limitasi & kendala 'API Busy'.",
                    ),
                    const SizedBox(height: 20),
                    _BenefitItem(
                      icon: Icons.workspace_premium_rounded,
                      color: Colors.purpleAccent,
                      title: tr('vip_benefit_badge'),
                      subtitle: "Tunjukkan dukunganmu sebagai VIP Sensei.",
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              
              Text(
                "Rp 10.000 / Bulan",
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.pinkAccent,
                ),
              ),
              const SizedBox(height: 20),
              
              // Donation Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: () => launchUrl(Uri.parse('https://trakteer.id/r8kstudio')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: Colors.pinkAccent.withValues(alpha: 0.4),
                  ),
                  child: Text(
                    tr('donation_button'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Discord Confirm Button
              SizedBox(
                width: double.infinity,
                height: 60,
                child: OutlinedButton(
                  onPressed: () => launchUrl(Uri.parse('https://s.my-bini.my.id/discord')),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF5865F2), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.discord, color: Color(0xFF5865F2)),
                      const SizedBox(width: 10),
                      Text(
                        tr('donation_confirm_discord'),
                        style: const TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5865F2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  "*Setelah donasi, harap kirim bukti transfer ke Discord agar VIP dapat diaktifkan manual oleh Admin.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: isDark ? Colors.grey.shade500 : Colors.blueGrey.shade400,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );

    if (widget.isDesktopMiddlePanel) {
      return content;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          tr('sidebar_donation'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: content,
    );
  }

  Widget _buildVipStatusCard(BuildContext context) {
    final isVip = _isVip;
    final statusText = _getVipStatusText();
    final expiryDate = _getExpiryDate();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isVip 
            ? [const Color(0xFFFFD700), const Color(0xFFFFA500)]
            : [Colors.grey.shade400, Colors.grey.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isVip ? Colors.orangeAccent : Colors.grey).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            tr('vip_status_title'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isVip ? Icons.stars_rounded : Icons.info_outline_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (expiryDate != null) ...[
            const SizedBox(height: 8),
            Text(
              tr('vip_status_expires').replaceAll('{date}', expiryDate),
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernCard(BuildContext context, {required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark 
          ? Colors.white.withValues(alpha: 0.05) 
          : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _BenefitItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
