import 'package:flutter/material.dart';
import '../../services/bot_service.dart';
import '../../services/local_chat_service.dart';
import '../../services/localization_service.dart';
import '../../widgets/skeleton_loader.dart';
import 'student_request_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectContactScreen extends StatefulWidget {
  final Function(Map<String, dynamic> chatData) onContactSelected;
  final VoidCallback onCancel;

  const SelectContactScreen({
    super.key,
    required this.onContactSelected,
    required this.onCancel,
  });

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  final BotService _botService = BotService();
  final LocalChatService _localChatService = LocalChatService();

  List<Map<String, dynamic>> _availableBots = [];
  List<Map<String, dynamic>> _eventCategories = [];
  List<Map<String, dynamic>> _eventBots = [];

  final Set<String> _selectedBotIds = {};

  String _searchQuery = '';
  String? _selectedCategoryId;

  bool _isLoadingBots = true;
  bool _isLoadingEventBots = false;
  bool _isLoadingEventCategories = false;
  
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    _checkTutorialStatus();
    _loadAvailableBots();
    _loadEventCategories();
  }

  Future<void> _checkTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_chat_tutorial') ?? false;
    if (!hasSeen && mounted) {
      setState(() {
        _showTutorial = true;
      });
    }
  }

  Future<void> _dismissTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_chat_tutorial', true);
    if (mounted) {
      setState(() {
        _showTutorial = false;
      });
    }
  }

  Future<void> _loadAvailableBots() async {
    setState(() => _isLoadingBots = true);
    final bots = await _botService.getBots(forceRefresh: true);
    if (mounted) {
      setState(() {
        _availableBots = bots;
        _isLoadingBots = false;
      });
    }
  }

  Future<void> _loadEventCategories() async {
    if (_eventCategories.isNotEmpty || _isLoadingEventCategories) return;
    setState(() => _isLoadingEventCategories = true);
    final cats = await _botService.getEventCategories();
    if (mounted) {
      setState(() {
        _eventCategories = cats;
        _isLoadingEventCategories = false;
      });
    }
  }

  Future<void> _loadEventBots(String? categoryId) async {
    setState(() {
      _selectedCategoryId = categoryId;
      _isLoadingEventBots = categoryId != null;
    });
    if (categoryId == null) {
      setState(() => _eventBots = []);
      return;
    }
    final bots = await _botService.getBots(type: 'Event', category: categoryId);
    if (mounted) {
      setState(() {
        _eventBots = bots;
        _isLoadingEventBots = false;
      });
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedBotIds.contains(id)) {
        _selectedBotIds.remove(id);
      } else {
        if (_selectedBotIds.length < 10) {
          _selectedBotIds.add(id);
        }
      }
    });
  }

  Future<void> _handleProceed() async {
    if (_selectedBotIds.isEmpty) return;

    if (_selectedBotIds.length == 1) {
      // Single chat
      final id = _selectedBotIds.first;
      final bot = [..._availableBots, ..._eventBots].firstWhere(
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
          final bot = [..._availableBots, ..._eventBots].firstWhere(
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
          trailing: Checkbox(
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

  Widget _buildTutorialBubble() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: cs.onPrimaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('tutorial_chat_title'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tr('tutorial_single_chat'),
            style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            tr('tutorial_group_chat'),
            style: TextStyle(color: cs.onPrimaryContainer, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _dismissTutorial,
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(tr('tutorial_got_it')),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            _selectedBotIds.isEmpty
                ? 'Select Contact'
                : 'Selected (${_selectedBotIds.length})',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onCancel,
          ),
          bottom: TabBar(
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            indicatorColor: cs.primary,
            tabs: const [
              Tab(text: 'Main'),
              Tab(text: 'Event'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (_showTutorial) _buildTutorialBubble(),
            Expanded(
              child: TabBarView(
                children: [
            // Main Tab
            Column(
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
            // Event Tab
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _isLoadingEventCategories
                            ? const SizedBox(
                                height: 48,
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                ),
                              )
                            : DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  hint: const Text('Pilih Kategori'),
                                  value: _selectedCategoryId,
                                  items: _eventCategories.map((cat) {
                                    return DropdownMenuItem<String>(
                                      value: cat['name'],
                                      child: Text(cat['name']),
                                    );
                                  }).toList(),
                                  onChanged: (v) => _loadEventBots(v),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),
                      _buildSuggestStudentRow(),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildBotList(_eventBots, _isLoadingEventBots),
                ),
              ],
            ),
          ],
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
      ),
    );
  }
}
