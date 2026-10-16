import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../services/local_user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _name = LocalUserService.defaultName;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final n = await LocalUserService.getLocalUserName();
    if (!mounted) return;
    setState(() {
      _name = n;
      _loading = false;
    });
  }

  Color _surfaceColor(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  Color _surfaceAltColor(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  Color _primaryColor(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  Color _primaryTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  Color _secondaryTextColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  void _showChangeNameDialog() {
    final nameController = TextEditingController(text: _name);
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: _surfaceColor(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr('profile_change_name'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor(context),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                maxLength: 50,
                decoration: InputDecoration(
                  labelText: tr('profile_full_name'),
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: _surfaceAltColor(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  errorText: errorText,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final v = LocalUserService.sanitize(nameController.text);
                    if (v.isEmpty) {
                      setDialogState(() => errorText = tr('profile_full_name'));
                      return;
                    }
                    await LocalUserService.setLocalUserName(v);
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    setState(() => _name = v);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr('profile_update_success')),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(tr('profile_update_btn')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('profile_title')),
        backgroundColor: _surfaceColor(context),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 30,
                ),
                children: [
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: _surfaceAltColor(context),
                          backgroundImage: const AssetImage(
                            'assets/icon/avatar.png',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _name,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _primaryTextColor(context),
                          ),
                        ),
                        Text(
                          tr('profile_full_name'),
                          style: TextStyle(
                            fontSize: 14,
                            color: _secondaryTextColor(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    tr('profile_account_info'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildInfoTile(
                    Icons.person_outline,
                    tr('profile_full_name'),
                    _name,
                  ),
                  const SizedBox(height: 30),
                  ListTile(
                    leading: Icon(
                      Icons.person_outline,
                      color: _primaryColor(context),
                    ),
                    title: Text(tr('profile_change_name')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showChangeNameDialog,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor(context), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: _secondaryTextColor(context),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
