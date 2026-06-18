import 'package:flutter/material.dart';
import '../../services/bot_service.dart';
import '../../services/local_chat_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/skeleton_loader.dart';
import 'student_request_screen.dart';

enum SelectContactMode { newChat, addToGroup, singleChat }

class SelectContactScreen extends StatefulWidget {
  final Function(Map<String, dynamic> chatData) onContactSelected;
  final VoidCallback onCancel;
  final SelectContactMode mode;
  final Set<String> existingMemberIds;

  const SelectContactScreen({
    super.key,
    required this.onContactSelected,
    required this.onCancel,
    this.mode = SelectContactMode.newChat,
    this.existingMemberIds = const {},
  });

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  final BotService _botService = BotService();
  final LocalChatService _localChatService = LocalChatService();

  List<Map<String, dynamic>> _availableBots = [];

  final Set<String> _selectedBotIds = {};

  String _searchQuery = '';

  bool _isLoadingBots = true;
  @override
  void initState() {
    super.initState();
    _loadAvailableBots();
  }

  Future<void> _loadAvailableBots() async {
    setState(() => _isLoadingBots = true);
    final bots = widget.mode == SelectContactMode.singleChat
        ? await _botService.getBots(forceRefresh: true)
        : await _botService.getRecruitedBots();
    if (mounted) {
      setState(() {
        _availableBots = bots;
        _isLoadingBots = false;
      });
    }
  }

  void _toggleSelection(String id) {
    if (widget.mode == SelectContactMode.singleChat) {
      _singleChatSelect(id);
      return;
    }
    setState(() {
      if (_selectedBotIds.contains(id)) {
        _selectedBotIds.remove(id);
      } else {
        if (widget.mode == SelectContactMode.addToGroup ||
            _selectedBotIds.length < 10) {
          _selectedBotIds.add(id);
        }
      }
    });
  }

  Future<void> _singleChatSelect(String id) async {
    final bot = _availableBots.firstWhere(
      (b) => b['id'].toString() == id,
      orElse: () => {
        'id': id,
        'name': id,
        'avatar': null,
        'color': '0xFF607D8B',
      },
    );
    await _botService.recruitBot(id);
    widget.onContactSelected(bot);
  }

  Future<void> _handleProceed() async {
    if (_selectedBotIds.isEmpty) return;

    if (widget.mode == SelectContactMode.addToGroup) {
      final List<Map<String, dynamic>> selectedBots = [];
      for (final id in _selectedBotIds) {
        final bot = _availableBots.firstWhere(
          (b) => b['id'].toString() == id,
          orElse: () => {
            'id': id,
            'name': id,
            'avatar': null,
            'color': '0xFF607D8B',
          },
        );
        selectedBots.add(bot);
      }
      if (mounted) Navigator.pop(context, selectedBots);
      return;
    }

    if (_selectedBotIds.length == 1) {
      // Single chat
      final id = _selectedBotIds.first;
      final bot = _availableBots.firstWhere(
        (b) => b['id'].toString() == id,
        orElse: () => {
          'id': id,
          'name': id,
          'avatar': null,
          'color': '0xFF607D8B',
        },
      );

      await _botService.recruitBot(id);
      widget.onContactSelected(bot);
    } else {
      // Group chat -> prompt for name
      final name = await _showGroupNameDialog();
      if (name != null && mounted) {
        final groupId = 'group_${DateTime.now().millisecondsSinceEpoch}';
        final List<Map<String, dynamic>> members = [];

        for (final id in _selectedBotIds) {
          final bot = _availableBots.firstWhere(
            (b) => b['id'].toString() == id,
            orElse: () => {
              'id': id,
              'name': id,
              'avatar': null,
              'color': '0xFF607D8B',
            },
          );
          members.add(bot);
        }

        final metadata = {
          'id': groupId,
          'name': name.isEmpty ? 'New Group' : name,
          'bio': '',
          'description': '',
          'isGroup': true,
          'members': members,
          'createdAt': DateTime.now().toIso8601String(),
        };

        await _localChatService.saveChat(groupId, [
          {
            'role': 'system',
            'content': 'Group created with ${members.length} members.',
            'metadata': metadata,
          },
        ]);

        final groupBotData = {
          'id': groupId,
          'name': metadata['name'],
          'description': '',
          'avatar': null,
          'color': '0xFF607D8B',
          'isGroup': true,
        };

        widget.onContactSelected(groupBotData);
      }
    }
  }

  Future<String?> _showGroupNameDialog() async {
    final TextEditingController controller = TextEditingController(
      text: 'New Group',
    );
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'New Group',
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: 'Enter group name...',
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Color _parseColor(dynamic color) {
    if (color == null) return Colors.blueGrey;
    if (color is Color) return color;
    if (color is String) {
      try {
        return Color(int.parse(color));
      } catch (_) {
        return Colors.blueGrey;
      }
    }
    return Colors.blueGrey;
  }

  bool _isBirthday(dynamic birthdayStr) {
    if (birthdayStr == null || birthdayStr == '') return false;
    try {
      final birthday = DateTime.parse(birthdayStr.toString());
      final now = DateTime.now();
      return birthday.month == now.month && birthday.day == now.day;
    } catch (_) {
      return false;
    }
  }

  Widget _buildBotList(List<Map<String, dynamic>> bots, bool isLoading) {
    if (isLoading) return const ChatListSkeleton();
    if (bots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 64,
              color: Theme.of(context).dividerColor,
            ),
            const SizedBox(height: 16),
            Text(
              tr('no_bots_found'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: bots.length,
      separatorBuilder: (context, index) =>
          Divider(height: 1, color: Theme.of(context).dividerColor),
      itemBuilder: (context, index) {
        final bot = bots[index];
        final id = bot['id'].toString();
        final isSelected = _selectedBotIds.contains(id);

        return ListTile(
          onTap: () => _toggleSelection(id),
          leading: Stack(
            children: [
              CircleAvatar(
                backgroundColor: _parseColor(bot['color']),
                backgroundImage: bot['image_url'] != null
                    ? NetworkImage(bot['image_url'])
                    : null,
                child: bot['image_url'] == null
                    ? Text(
                        (bot['name'] as String).isNotEmpty
                            ? (bot['name'] as String)[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (isSelected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Text(
                bot['name'] ?? 'Unknown',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              if (_isBirthday(bot['birthday']))
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text('🎂', style: TextStyle(fontSize: 14)),
                ),
            ],
          ),
          subtitle: Text(
            bot['description'] ?? 'No description',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: widget.mode == SelectContactMode.singleChat
              ? null
              : Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(id),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSuggestStudentRow() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            tr('suggest_student_desc'),
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const StudentRequestScreen(),
              ),
            );
          },
          icon: const Icon(Icons.add_task_rounded, size: 16),
          label: Text(
            tr('suggest_student'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary,
            backgroundColor: colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _selectedBotIds.isEmpty
              ? 'Select Contact'
              : 'Selected (${_selectedBotIds.length})',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.mode == SelectContactMode.addToGroup
              ? () => Navigator.pop(context)
              : widget.onCancel,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: tr('search_hint'),
                    prefixIcon: Icon(Icons.search, color: cs.primary),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSuggestStudentRow(),
              ],
            ),
          ),
          Expanded(
            child: _buildBotList(
              _availableBots.where((bot) {
                if (widget.mode == SelectContactMode.addToGroup &&
                    widget.existingMemberIds
                        .contains(bot['id'].toString())) {
                  return false;
                }
                final name = (bot['name'] ?? '').toString().toLowerCase();
                final id = (bot['id'] ?? '').toString().toLowerCase();
                final query = _searchQuery.toLowerCase();
                return name.contains(query) || id.contains(query);
              }).toList(),
              _isLoadingBots,
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedBotIds.isNotEmpty
          ? FloatingActionButton(
              onPressed: _handleProceed,
              child: const Icon(Icons.arrow_forward),
            )
          : null,
    );
  }
}
