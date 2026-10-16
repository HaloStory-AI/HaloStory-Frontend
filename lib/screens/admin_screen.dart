import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import 'admin/bot_editor.dart';
import '../services/localization_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;

  List<dynamic> _users = [];
  List<dynamic> _bots = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      _adminService.getUsers(),
      _adminService.getBots(),
    ]);

    setState(() {
      _users = results[0];
      _bots = results[1];
      _isLoading = false;
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('admin_panel_title')),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAllData,
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.people), text: tr('admin_tab_users')),
              Tab(
                icon: const Icon(Icons.smart_toy),
                text: tr('admin_tab_bots'),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildUsersTab(),
                  _buildBotsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildUsersTab() {
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final bool isAdmin = user['role'] == 'admin';

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isAdmin ? Colors.amber : Colors.blue,
            child: Icon(
              isAdmin ? Icons.admin_panel_settings : Icons.person,
              color: Colors.white,
            ),
          ),
          title: Text(user['name']),
          subtitle: Text('${user['email']}\nRole: ${user['role']}'),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            onSelected: (String result) async {
              if (result == 'make_admin' || result == 'make_sensei') {
                final newRole = result == 'make_admin' ? 'admin' : 'Sensei';
                final success = await _adminService.changeUserRole(
                  user['id'],
                  newRole,
                );
                if (success) {
                  _showSnackBar('${tr('admin_role_updated')}$newRole');
                  _loadAllData();
                } else {
                  _showSnackBar(tr('admin_role_failed'));
                }
              } else if (result == 'delete') {
                final confirm = await _showConfirmDialog(
                  tr('admin_delete_confirm_title'),
                  '${tr('admin_delete_user_confirm')}${user['name']}?',
                );
                if (confirm == true) {
                  final success = await _adminService.deleteUser(user['id']);
                  if (success) {
                    _showSnackBar(tr('admin_user_deleted'));
                    _loadAllData();
                  } else {
                    _showSnackBar(tr('admin_user_delete_failed'));
                  }
                }
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              if (!isAdmin)
                const PopupMenuItem<String>(
                  value: 'make_admin',
                  child: Text('Make Admin'),
                ),
              if (isAdmin)
                const PopupMenuItem<String>(
                  value: 'make_sensei',
                  child: Text('Revoke Admin'),
                ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete User', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBotsTab() {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(tr('admin_add_bot')),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            onPressed: () => _showBotEditor(null),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _bots.length,
            itemBuilder: (context, index) {
              final bot = _bots[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: bot['avatar'] != null
                      ? NetworkImage(bot['avatar'])
                      : null,
                  child: bot['avatar'] == null
                      ? const Icon(Icons.smart_toy)
                      : null,
                ),
                title: Text(bot['name']),
                subtitle: Text(
                  'SBR: ${bot['sbr'] ?? 'N/A'}\nID: ${bot['bot_id']}',
                ),
                isThreeLine: true,
                onTap: () => _showBotEditor(bot),
                trailing: IconButton(
                  icon: Icon(
                    Icons.delete,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: () async {
                    final confirm = await _showConfirmDialog(
                      tr('admin_delete_confirm_title'),
                      '${tr('admin_delete_bot_confirm')}${bot['name']}?',
                    );
                    if (confirm == true) {
                      final success = await _adminService.deleteBot(bot['id']);
                      if (success) {
                        _showSnackBar(tr('admin_bot_deleted'));
                        _loadAllData();
                      } else {
                        _showSnackBar(tr('admin_bot_delete_failed'));
                      }
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showBotEditor(Map<String, dynamic>? botData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          BotEditorModal(botData: botData, onSaved: _loadAllData),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
