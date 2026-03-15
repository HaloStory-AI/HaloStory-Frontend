import 'package:flutter/material.dart';
import '../services/admin_service.dart';
import 'package:intl/intl.dart';
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
  List<dynamic> _requests = [];

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
      _adminService.getStudentRequests(),
    ]);

    setState(() {
      _users = results[0];
      _bots = results[1];
      _requests = results[2];
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
      length: 3,
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
              Tab(
                icon: const Icon(Icons.inbox),
                text: tr('admin_tab_requests'),
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
                  _buildRequestsTab(),
                ],
              ),
      ),
    );
  }

  // --- USERS TAB ---
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

  // --- BOTS TAB ---
  Widget _buildBotsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(tr('admin_add_bot')),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: const Color(0xFF135ACF),
              foregroundColor: Colors.white,
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
                  icon: const Icon(Icons.delete, color: Colors.red),
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

  // --- REQUESTS TAB ---
  Widget _buildRequestsTab() {
    return ListView.builder(
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final req = _requests[index];
        Color statusColor = Colors.orange;
        if (req['status'] == 'approved') statusColor = Colors.green;
        if (req['status'] == 'rejected') statusColor = Colors.red;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Murid: ${req['student_name']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Chip(
                      label: Text(
                        req['status'].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                      backgroundColor: statusColor,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Requested by: ${req['user']?['name'] ?? 'Unknown'}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                Text(
                  'Date: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(req['created_at']))}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                if (req['status'] == 'pending') ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 18,
                        ),
                        label: const Text(
                          'Reject',
                          style: TextStyle(color: Colors.red),
                        ),
                        onPressed: () =>
                            _updateRequestStatus(req['id'], 'rejected'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onPressed: () =>
                            _updateRequestStatus(req['id'], 'approved'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateRequestStatus(int id, String status) async {
    final success = await _adminService.updateRequestStatus(id, status);
    if (success) {
      _showSnackBar(
        status == 'approved'
            ? tr('admin_request_approved')
            : tr('admin_request_rejected'),
      );
      _loadAllData();
    } else {
      _showSnackBar(tr('admin_request_failed'));
    }
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
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
