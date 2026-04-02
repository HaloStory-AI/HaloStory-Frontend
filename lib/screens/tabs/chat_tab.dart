import 'package:flutter/material.dart';
import '../../services/local_chat_service.dart';
import '../../services/ai_service.dart';
import '../../services/bot_service.dart';
import '../../services/localization_service.dart';
import '../chat_screen.dart';
import '../student_request_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../widgets/skeleton_loader.dart';

class ChatTab extends StatefulWidget {
  final Function(Map<String, dynamic> bot)? onChatSelected;

  const ChatTab({super.key, this.onChatSelected});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final LocalChatService _localChatService = LocalChatService();
  final BotService _botService = BotService();
  List<Map<String, dynamic>> _activeChats = [];
  List<Map<String, dynamic>> _availableBots = [];
  List<String> _pinnedChatIds = [];
  bool _isLoadingBots = true;
  bool _isLoadingChats = true;
  String _sortBy = 'Newest';
  bool _sortAscending = false;
  bool _showSyncNotice = true;

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

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) {
      return DateFormat('HH:mm').format(dt);
    } else if (dt.year == now.year && dt.month == now.month) {
      return DateFormat('d MMM').format(dt);
    } else {
      return DateFormat('d/M/yy').format(dt);
    }
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

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData({bool force = false}) async {
    setState(() {
      _isLoadingBots = true;
      _isLoadingChats = true;
    });

    // 1. Load bots first (Now very fast because of SharedPreferences cache in BotService)
    await _loadAvailableBots(force: force);

    // 2. Then load chats, so we can match them with the bot avatars/colors
    await _loadActiveChats();
  }

  Future<void> _handleRefresh() async {
    await _initData(force: true);
  }

  Future<void> _loadAvailableBots({bool force = false}) async {
    final bots = await _botService.getBots(forceRefresh: force);
    if (mounted) {
      setState(() {
        _availableBots = bots;
        _isLoadingBots = false;
      });
    }
  }

  Future<void> _loadActiveChats() async {
    final chatMetadata = await _localChatService.getAllChatMetadata();
    final pinnedIds = await _localChatService.getPinnedChats();

    if (mounted) {
      setState(() {
        _pinnedChatIds = pinnedIds;
      });
    }

    List<Map<String, dynamic>> loadedChats = [];

    for (var meta in chatMetadata) {
      final id = meta['id'].toString();
      final history = await _localChatService.loadChat(id);

      Map<String, dynamic>? bot;
      try {
        bot = _availableBots.firstWhere((b) => b['id'].toString() == id);
      } catch (_) {
        bot = await _botService.getBotById(id);
      }

      bot ??= {
        'id': id,
        'name': id,
        'avatar': null,
        'color': '0xFF607D8B',
      };

      if (history.isNotEmpty) {
        loadedChats.add({
          ...bot,
          'lastMessage': history.last['content'] ?? '...',
          'time': _formatDateTime(meta['lastModified']),
          'provider': 'Global Config',
          'lastModified': meta['lastModified'],
          'isPinned': _pinnedChatIds.contains(id),
        });
      }
    }

    // Sort the list based on state for non-pinned items
    if (_sortBy == 'Newest') {
      loadedChats.sort(
        (a, b) => (a['lastModified'] as DateTime).compareTo(
          b['lastModified'] as DateTime,
        ),
      );
    } else if (_sortBy == 'Name') {
      loadedChats.sort(
        (a, b) => (a['name'] as String).toLowerCase().compareTo(
          (b['name'] as String).toLowerCase(),
        ),
      );
    } else if (_sortBy == 'Bond') {
      loadedChats.sort(
        (a, b) => (a['bond_hearts'] as int? ?? 0).compareTo(
          b['bond_hearts'] as int? ?? 0,
        ),
      );
    }

    if (!_sortAscending) {
      loadedChats = loadedChats.reversed.toList();
    }

    // Always sort pinned items to the top, maintaining the sorted group order
    loadedChats.sort((a, b) {
      if (a['isPinned'] && !b['isPinned']) return -1;
      if (!a['isPinned'] && b['isPinned']) return 1;
      return 0; // Maintain existing relative order
    });

    if (mounted) {
      setState(() {
        _activeChats = loadedChats;
        _isLoadingChats = false;
      });
    }
  }

  void _showAddChatSheet() {
    _loadAvailableBots(force: true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String searchQuery = '';
        List<Map<String, dynamic>> eventCategories = [];
        String? selectedCategoryId;
        List<Map<String, dynamic>> eventBots = [];
        bool isLoadingEventBots = false;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return DefaultTabController(
              length: 2,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TabBar(
                      labelColor: const Color(0xFF135ACF),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF135ACF),
                      tabs: [
                        const Tab(text: 'Main'),
                        const Tab(text: 'Event'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // TAB 1: MAIN
                          Column(
                            children: [
                              _buildSearchHeader(context, (value) {
                                setModalState(() => searchQuery = value);
                              }),
                              Expanded(
                                child: _buildBotList(
                                  _availableBots.where((bot) {
                                    final name = (bot['name'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    final id = (bot['id'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    final query = searchQuery.toLowerCase();
                                    return name.contains(query) ||
                                        id.contains(query);
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                          // TAB 2: EVENT
                          Column(
                            children: [
                              _buildEventHeader(
                                context,
                                eventCategories,
                                selectedCategoryId,
                                (catId) async {
                                  setModalState(() {
                                    selectedCategoryId = catId;
                                    isLoadingEventBots = true;
                                  });
                                  final bots = await _botService.getBots(
                                    type: 'Event',
                                    category: catId,
                                  );
                                  setModalState(() {
                                    eventBots = bots;
                                    isLoadingEventBots = false;
                                  });
                                },
                                () async {
                                  if (eventCategories.isEmpty) {
                                    final cats = await _botService
                                        .getEventCategories();
                                    setModalState(() => eventCategories = cats);
                                  }
                                },
                              ),
                              Expanded(
                                child: isLoadingEventBots
                                    ? const ChatListSkeleton()
                                    : _buildBotList(eventBots),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchHeader(BuildContext context, Function(String) onSearch) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('new_dialog_title'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF135ACF),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: onSearch,
            decoration: InputDecoration(
              hintText: tr('search_hint'),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF135ACF)),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
          const SizedBox(height: 12),
          _buildSuggestStudentRow(context),
        ],
      ),
    );
  }

  Widget _buildEventHeader(
    BuildContext context,
    List<Map<String, dynamic>> categories,
    String? selectedCategoryId,
    Function(String?) onCategoryChanged,
    Future<void> Function() onInit,
  ) {
    onInit();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Event Characters',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF135ACF),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                hint: const Text('Pilih Kategori'),
                value: selectedCategoryId,
                items: categories.map((cat) {
                  return DropdownMenuItem<String>(
                    value:
                        cat['name'], // Using name as category key per backend logic
                    child: Text(cat['name']),
                  );
                }).toList(),
                onChanged: onCategoryChanged,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildSuggestStudentRow(context),
        ],
      ),
    );
  }

  Widget _buildSuggestStudentRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            tr('suggest_student_desc'),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: () {
            Navigator.pop(context);
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
            foregroundColor: const Color(0xFF135ACF),
            backgroundColor: const Color(0xFFF0F5FF),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBotList(List<Map<String, dynamic>> bots) {
    if (_isLoadingBots) return const ChatListSkeleton();
    if (bots.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              tr('no_bots_found'),
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: bots.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final bot = bots[index];
        return ListTile(
          leading: CircleAvatar(
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
          title: Row(
            children: [
              Text(
                bot['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (_isBirthday(bot['birthday']))
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text('🎂', style: TextStyle(fontSize: 14)),
                ),
            ],
          ),
          subtitle: Text(
            bot['description'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: const Icon(
            Icons.add_circle_outline,
            color: Color(0xFF135ACF),
          ),
          onTap: () async {
            Navigator.pop(context);
            _botService.recruitBot(bot['id']);
            
            if (widget.onChatSelected != null) {
              widget.onChatSelected!(bot);
              _loadActiveChats();
              return;
            }

            final prefs = await SharedPreferences.getInstance();
            final provider = AIService.normalizeProvider(
              prefs.getString('default_provider'),
            );
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ChatDetailScreen(bot: bot, provider: provider),
              ),
            ).then((_) => _loadActiveChats());
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(onRefresh: _handleRefresh, child: _buildBody()),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'chat_fab',
        onPressed: _showAddChatSheet,
        backgroundColor: const Color(0xFF135ACF),
        child: const Icon(Icons.add_comment_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Sync Notice
        if (_showSyncNotice)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.amber.shade100,
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tr('chat_sync_notice'),
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showSyncNotice = false;
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.only(left: 8.0),
                    child: Icon(Icons.close, color: Colors.black54, size: 16),
                  ),
                ),
              ],
            ),
          ),
        
        // Visual Header from Image
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Text(
                'Chats (${_activeChats.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              PopupMenuButton<String>(
                onSelected: (value) {
                  setState(() {
                    _sortBy = value;
                    _loadActiveChats();
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'Newest',
                    child: Text(tr('sort_newest')),
                  ),
                  PopupMenuItem(value: 'Name', child: Text(tr('sort_name'))),
                  const PopupMenuItem(
                    value: 'Bond',
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Color(0xFFFBB6CE),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text('Bond'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sortBy,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Icon(
                        Icons.arrow_drop_down,
                        size: 20,
                        color: Color(0xFF135ACF),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () {
                  setState(() {
                    _sortAscending = !_sortAscending;
                    _loadActiveChats();
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _sortAscending
                        ? Icons.keyboard_double_arrow_up_rounded
                        : Icons.keyboard_double_arrow_down_rounded,
                    size: 20,
                    color: const Color(0xFF135ACF),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoadingChats && _activeChats.isEmpty
              ? const ChatListSkeleton()
              : _activeChats.isEmpty
              ? _buildEmptyState()
              : _buildChatList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      // Wrap in ListView to enable RefreshIndicator
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 100,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 24),
              Text(
                tr('tab_chat_empty_title'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('tab_chat_empty_subtitle'),
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _showAddChatSheet,
                icon: const Icon(Icons.add),
                label: Text(tr('tab_chat_new_chat')),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatList() {
    return ListView.separated(
      itemCount: _activeChats.length,
      padding: const EdgeInsets.symmetric(vertical: 0),
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        indent: 80,
        endIndent: 16,
        color: Color(0xFFE0E0E0),
      ),
      itemBuilder: (context, index) {
        final chat = _activeChats[index];
        final bondLevel = (chat['bond_hearts'] ?? 0).toString();

        return GestureDetector(
          onLongPress: () => _showChatOptions(chat),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: _parseColor(chat['color']),
              backgroundImage: chat['image_url'] != null
                  ? NetworkImage(chat['image_url'])
                  : null,
              child: chat['image_url'] == null
                  ? Text(
                      (chat['name'] as String).isNotEmpty
                          ? (chat['name'] as String)[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            title: Row(
              children: [
                Text(
                  chat['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF2D3748),
                  ),
                ),
                if (_isBirthday(chat['birthday']))
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('🎂', style: TextStyle(fontSize: 14)),
                  ),
                if (chat['isPinned'] == true)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.push_pin_rounded,
                      size: 14,
                      color: Color(0xFF135ACF),
                    ),
                  ),
                const Spacer(),
                Text(
                  chat['time'],
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                chat['lastMessage'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF718096), fontSize: 15),
              ),
            ),
            trailing: Container(
              width: 45,
              height: 45,
              margin: const EdgeInsets.only(left: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Color(0xFFFBB6CE), // Soft pink
                    size: 42,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 2,
                    ), // Adjust number position
                    child: Text(
                      bondLevel,
                      style: const TextStyle(
                        color: Color(
                          0xFF135ACF,
                        ), // Deep Blue/Standard Blue Archive text color
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            onTap: () async {
              if (widget.onChatSelected != null) {
                widget.onChatSelected!(chat);
                _loadActiveChats();
                return;
              }
              final prefs = await SharedPreferences.getInstance();
              final provider = AIService.normalizeProvider(
                prefs.getString('default_provider'),
              );

              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ChatDetailScreen(bot: chat, provider: provider),
                ),
              ).then((_) => _loadActiveChats());
            },
          ),
        );
      },
    );
  }

  void _showChatOptions(Map<String, dynamic> chat) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _parseColor(chat['color']),
                  backgroundImage: chat['image_url'] != null
                      ? NetworkImage(chat['image_url'])
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  chat['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: chat['isPinned'] == true
                    ? const Color(0xFFFFF3E0)
                    : const Color(0xFFF0F5FF),
                child: Icon(
                  chat['isPinned'] == true
                      ? Icons.push_pin_outlined
                      : Icons.push_pin_rounded,
                  color: chat['isPinned'] == true
                      ? const Color(0xFFE65100)
                      : const Color(0xFF135ACF),
                ),
              ),
              title: Text(
                chat['isPinned'] == true ? 'Unpin Chat' : 'Pin Chat',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                chat['isPinned'] == true
                    ? 'Remove from top'
                    : 'Pin to top (Max 5)',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final chatId = chat['id'].toString();
                final bool isPinned = chat['isPinned'] == true;

                if (!isPinned && _pinnedChatIds.length >= 5) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Anda hanya bisa pin maksimal 5 chat.'),
                    ),
                  );
                  return;
                }

                if (isPinned) {
                  _pinnedChatIds.remove(chatId);
                } else {
                  _pinnedChatIds.add(chatId);
                }

                await _localChatService.savePinnedChats(_pinnedChatIds);
                _loadActiveChats();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF2E7D32),
                ),
              ),
              title: const Text(
                'Re-Summary',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Clear summary to regenerate upon next opening',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await _localChatService.saveSummaries(
                  chat['id'].toString(),
                  {},
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Summary reset. Will generate on next open.',
                      ),
                    ),
                  );
                }
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFEBEE),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFD32F2F),
                ),
              ),
              title: const Text(
                'Hapus Chat',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD32F2F),
                ),
              ),
              subtitle: const Text(
                'Permanently delete this chat history',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                final bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Hapus Chat?'),
                    content: const Text('Tindakan ini tidak bisa dibatalkan.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await _localChatService.deleteChat(chat['id'].toString());
                  _initData();
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
