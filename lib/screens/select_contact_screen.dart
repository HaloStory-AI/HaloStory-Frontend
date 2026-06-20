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
  final bool isPanel;
  final void Function(List<Map<String, dynamic>> result)? onPanelDone;

  const SelectContactScreen({
    super.key,
    required this.onContactSelected,
    required this.onCancel,
    this.mode = SelectContactMode.newChat,
    this.existingMemberIds = const {},
    this.isPanel = false,
    this.onPanelDone,
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

  // Category state (singleChat mode only)
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategorySlug;
  bool _isLoadingCategories = false;

  int _categoryTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadAvailableBots();
  }

  Future<void> _loadAvailableBots() async {
    if (widget.mode == SelectContactMode.singleChat) {
      await _loadCategories();
      return;
    }
    setState(() => _isLoadingBots = true);
    final bots = widget.mode == SelectContactMode.newChat
        ? await _botService.getBots(forceRefresh: true)
        : await _botService.getRecruitedBots();
    if (mounted) {
      setState(() {
        _availableBots = bots;
        _isLoadingBots = false;
      });
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCategories = true);
    final raw = await _botService.getCategories();
    if (mounted) {
      setState(() {
        final List<Map<String, dynamic>> all = [];
        for (final key in ['pinned', 'featured', 'default']) {
          final items = raw[key];
          if (items is List) {
            for (final item in items) {
              if (item is Map) {
                final cat = Map<String, dynamic>.from(item);
                cat['_section'] = key;
                all.add(cat);
              }
            }
          }
        }
        _categories = all;
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _loadCategoryBots(String slug) async {
    setState(() => _isLoadingBots = true);
    final bots = await _botService.getBotsByCategory(slug);
    if (mounted) {
      setState(() {
        _availableBots = bots;
        _isLoadingBots = false;
      });
    }
  }

  void _selectCategory(String slug) {
    setState(() => _selectedCategorySlug = slug);
    _loadCategoryBots(slug);
  }

  void _backToCategories() {
    setState(() {
      _selectedCategorySlug = null;
      _availableBots = [];
      _searchQuery = '';
    });
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
      if (widget.onPanelDone != null) {
        widget.onPanelDone!(selectedBots);
        return;
      }
      if (mounted) Navigator.pop(context, selectedBots);
      return;
    }

    if (_selectedBotIds.length == 1) {
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

  Widget _buildCategoryView() {
    if (_isLoadingCategories) return const ChatListSkeleton();

    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_rounded,
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

    final cs = Theme.of(context).colorScheme;

    Widget buildTabSelector() {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(
          children: [
            ChoiceChip(
              label: Text(tr('select_category')),
              selected: _categoryTabIndex == 0,
              onSelected: (_) => setState(() => _categoryTabIndex = 0),
            ),
            const SizedBox(width: 12),
            ChoiceChip(
              label: Text(tr('category_custom')),
              selected: _categoryTabIndex == 1,
              onSelected: (_) => setState(() => _categoryTabIndex = 1),
            ),
          ],
        ),
      );
    }

    if (_categoryTabIndex == 1) {
      return Column(
        children: [
          buildTabSelector(),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_fix_high_rounded, size: 64, color: Theme.of(context).dividerColor),
                  const SizedBox(height: 16),
                  Text(
                    'Custom Character\nComing soon',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    Widget buildSection(String title, List<Map<String, dynamic>> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
          ...items.map((cat) => _buildCategoryTile(cat, cs)),
        ],
      );
    }

    final pinned = _categories.where((c) => c['_section'] == 'pinned').toList();
    final featured = _categories.where((c) => c['_section'] == 'featured').toList();
    final defaults = _categories.where((c) => c['_section'] == 'default').toList();

    return ListView(
      children: [
        buildTabSelector(),
        buildSection(tr('category_pinned'), pinned),
        buildSection(tr('category_featured'), featured),
        buildSection(tr('category_default'), defaults),
      ],
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> cat, ColorScheme cs) {
    final name = cat['name'] ?? 'Unknown';
    final logoUrl = cat['logo_url'];
    final slug = cat['slug'] ?? '';

    return ListTile(
      onTap: () => _selectCategory(slug),
      leading: CircleAvatar(
        backgroundColor: cs.surfaceContainerHighest,
        backgroundImage: logoUrl != null && logoUrl.toString().isNotEmpty
            ? NetworkImage(logoUrl.toString())
            : null,
        child: logoUrl == null || logoUrl.toString().isEmpty
            ? Text(
                name.toString().isNotEmpty
                    ? name.toString()[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        name,
        style: TextStyle(color: cs.onSurface),
      ),
      trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bool isCategoryView =
        widget.mode == SelectContactMode.singleChat &&
        _selectedCategorySlug == null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.isPanel
          ? null
          : AppBar(
              title: Text(
                isCategoryView
                    ? tr('select_category')
                    : _selectedBotIds.isEmpty
                        ? (widget.mode == SelectContactMode.newChat
                            ? tr('tab_chat_new_chat')
                            : widget.mode == SelectContactMode.addToGroup
                                ? tr('tab_chat_group_chat')
                                : tr('tab_chat_single_chat'))
                        : 'Selected (${_selectedBotIds.length})',
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: isCategoryView
                    ? widget.onCancel
                    : _selectedCategorySlug != null
                        ? _backToCategories
                        : widget.onCancel,
              ),
            ),
      body: Column(
        children: [
          if (!isCategoryView &&
              widget.mode != SelectContactMode.addToGroup)
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
                  if (widget.mode != SelectContactMode.newChat) ...[
                    const SizedBox(height: 12),
                    _buildSuggestStudentRow(),
                  ],
                ],
              ),
            ),
          Expanded(
            child: isCategoryView
                ? _buildCategoryView()
                : _buildBotList(
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
      floatingActionButton: _selectedBotIds.isNotEmpty &&
              widget.mode != SelectContactMode.singleChat &&
              (widget.mode == SelectContactMode.addToGroup ||
                  _selectedBotIds.length >= 2)
          ? FloatingActionButton(
              onPressed: _handleProceed,
              child: const Icon(Icons.arrow_forward),
            )
          : null,
    );
  }
}
