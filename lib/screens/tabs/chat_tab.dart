import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/local_chat_service.dart';
import '../../services/bot_service.dart';
import '../../services/localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../widgets/skeleton_loader.dart';
import '../select_contact_screen.dart';

enum ChatSortType { newest, name, bond }

class ChatTab extends StatefulWidget {
  final Function(Map<String, dynamic>) onChatSelected;
  final Function(Widget)? onShowSort;
  final VoidCallback? onAddContact;

  const ChatTab({
    super.key,
    required this.onChatSelected,
    this.onShowSort,
    this.onAddContact,
  });

  @override
  State<ChatTab> createState() => ChatTabState();
}

class ChatTabState extends State<ChatTab> with AutomaticKeepAliveClientMixin {
  final LocalChatService _localChatService = LocalChatService();
  final BotService _botService = BotService();
  List<Map<String, dynamic>> _activeChats = [];
  List<Map<String, dynamic>> _availableBots = [];
  List<String> _pinnedChatIds = [];
  final Set<String> _selectedChatIds = <String>{};
  //Jangan ilangin _isLoadingBots
  // entah kenapa saat diremove, langsung dibilang dibutuhkan
  // padahal disini katanya isn't used
  // but it's used here.
  bool _isLoadingChats = true;
  bool _bondDisabled = false;
  ChatSortType _sortBy = ChatSortType.newest;
  bool _sortAscending = false;
  StreamSubscription<String>? _chatUpdateSubscription;
  Timer? _debounceTimer;

  static const String _chatSortByKey = 'chat_sort_by';
  static const String _chatSortAscKey = 'chat_sort_ascending';
  static const String _chatHeaderPopupFont = 'Roboto';
  static const List<ChatSortType> _sortOptions = [
    ChatSortType.newest,
    ChatSortType.name,
    ChatSortType.bond,
  ];

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

  Color _surfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  Color _surfaceAltColor(BuildContext context) {
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }

  Color _borderColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.colorScheme.outlineVariant;
  }

  Color _primaryTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  Color _secondaryTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Color _chatSeparatorColor(BuildContext context) {
    return Theme.of(context).dividerColor.withValues(alpha: 0.55);
  }

  TextStyle _bondCountStyle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shadowColor = Colors.black.withValues(alpha: 0.45);

    return TextStyle(
      color: colorScheme.primary,
      fontWeight: FontWeight.w800,
      fontSize: 14,
      shadows: [
        Shadow(color: shadowColor, offset: const Offset(1, 0)),
        Shadow(color: shadowColor, offset: const Offset(-1, 0)),
        Shadow(color: shadowColor, offset: const Offset(0, 1)),
        Shadow(color: shadowColor, offset: const Offset(0, -1)),
      ],
    );
  }

  String _trOr(String key, String fallback) {
    final translated = tr(key);
    return translated == key ? fallback : translated;
  }

  String _sortTypeKey(ChatSortType value) {
    switch (value) {
      case ChatSortType.newest:
        return 'newest';
      case ChatSortType.name:
        return 'name';
      case ChatSortType.bond:
        return 'bond';
    }
  }

  ChatSortType _sortTypeFromKey(String? key) {
    switch (key) {
      case 'name':
        return ChatSortType.name;
      case 'bond':
        return ChatSortType.bond;
      case 'newest':
      default:
        return ChatSortType.newest;
    }
  }

  String _sortLabel(ChatSortType value) {
    switch (value) {
      case ChatSortType.newest:
        return tr('sort_newest');
      case ChatSortType.name:
        return tr('sort_name');
      case ChatSortType.bond:
        return _trOr('sort_bond', 'Bond');
    }
  }

  Future<void> _loadSortPreferencesAndInit() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSort = _sortTypeFromKey(prefs.getString(_chatSortByKey));
    final savedAscending = prefs.getBool(_chatSortAscKey) ?? false;

    if (!mounted) return;
    setState(() {
      _sortBy = savedSort;
      _sortAscending = savedAscending;
    });

    await initData();
  }

  Future<void> _saveSortPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chatSortByKey, _sortTypeKey(_sortBy));
    await prefs.setBool(_chatSortAscKey, _sortAscending);
  }

  @override
  void initState() {
    super.initState();
    _loadSortPreferencesAndInit();

    // Listen to real-time chat updates (new messages, deleted chats) — debounced
    _chatUpdateSubscription = LocalChatService.onChatUpdated.listen((chatId) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          initData(silent: true);
        }
      });
    });
  }

  @override
  void dispose() {
    _chatUpdateSubscription?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> initData({bool force = false, bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoadingChats = true;
      });
    }

    await _loadAvailableBots(force: force);

    await _loadActiveChats();
  }

  Future<void> _handleRefresh() async {
    await initData(force: true);
  }

  Future<void> _loadAvailableBots({bool force = false}) async {
    final bots = await _botService.getChatTabBots(forceRefresh: force);
    if (mounted) {
      setState(() {
        _availableBots = bots;
      });
    }
  }

  Future<void> _loadActiveChats() async {
    final prefs = await SharedPreferences.getInstance();
    _bondDisabled = prefs.getBool('bond_disabled') ?? false;
    final chatMetadata = await _localChatService.getAllChatMetadata();
    final pinnedIds = await _localChatService.getPinnedChats();

    if (mounted) {
      setState(() {
        _pinnedChatIds = pinnedIds;
      });
    }

    List<Map<String, dynamic>> loadedChats = [];

    for (var meta in chatMetadata) {
      try {
        final id = meta['id'].toString();

        Map<String, dynamic>? bot;
        bool isGroup = id.startsWith('group_');

        if (isGroup) {
          final history = await _localChatService.loadChat(id);
          if (history.isNotEmpty) {
            final systemMsg = history.firstWhere(
              (m) => m['role'] == 'system' && m['metadata'] != null,
              orElse: () => <String, dynamic>{},
            );
            if (systemMsg.isNotEmpty && systemMsg['metadata'] != null) {
              final metadata = systemMsg['metadata'];
              if (kDebugMode) {
                print(
                  'DEBUG: _loadActiveChats group $id -> name="${metadata['name']}" bio="${metadata['bio']}"',
                );
              }
              bot = {
                'id': id,
                'name': metadata['name'] ?? 'New Group',
                'description': metadata['bio'] ?? metadata['description'] ?? '',
                'avatar': null,
                'color': '0xFF607D8B',
                'isGroup': true,
              };
            }
          }
        }

        if (bot == null) {
          try {
            bot = _availableBots.firstWhere((b) => b['id'].toString() == id);
          } catch (_) {
            bot = await _botService.getBotById(id);
          }
        }

        bot ??= {
          'id': id,
          'name': id,
          'avatar': null,
          'color': '0xFF607D8B',
        };

        loadedChats.add({
          ...bot,
          'time': _formatDateTime(meta['lastModified']),
          'provider': isGroup ? 'Group' : 'Global Config',
          'lastModified': meta['lastModified'],
          'isPinned': _pinnedChatIds.contains(id),
        });
      } catch (e) {
        if (kDebugMode) {
          print('DEBUG: Error processing chat entry ${meta['id']}: $e');
        }
      }
    }

    switch (_sortBy) {
      case ChatSortType.newest:
        loadedChats.sort(
          (a, b) => (a['lastModified'] as DateTime).compareTo(
            b['lastModified'] as DateTime,
          ),
        );
        break;
      case ChatSortType.name:
        loadedChats.sort(
          (a, b) => (a['name'] as String).toLowerCase().compareTo(
            (b['name'] as String).toLowerCase(),
          ),
        );
        break;
      case ChatSortType.bond:
        loadedChats.sort(
          (a, b) => (a['bond_hearts'] as int? ?? 0).compareTo(
            b['bond_hearts'] as int? ?? 0,
          ),
        );
        break;
    }

    if (!_sortAscending) {
      loadedChats = loadedChats.reversed.toList();
    }

    loadedChats.sort((a, b) {
      if (a['isPinned'] && !b['isPinned']) return -1;
      if (!a['isPinned'] && b['isPinned']) return 1;
      return 0;
    });

    final loadedChatIds = loadedChats
        .map((chat) => chat['id'].toString())
        .toSet();

    if (mounted) {
      setState(() {
        _activeChats = loadedChats;
        _selectedChatIds.removeWhere((id) => !loadedChatIds.contains(id));
        _isLoadingChats = false;
      });
    }
  }

  void _showSortSheet() {
    ChatSortType draftSort = _sortBy;

    if (widget.onShowSort != null) {
      widget.onShowSort!(_buildSortOverlayContent(draftSort));
      return;
    }

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final cs = Theme.of(ctx).colorScheme;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text(_trOr('sort_title', 'Sort'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cs.onSurface)),
                        const Spacer(),
                        IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RadioGroup<ChatSortType>(
                      groupValue: draftSort,
                      onChanged: (nv) => setSheetState(() => draftSort = nv!),
                      child: Column(
                        children: _sortOptions.map((v) => RadioListTile<ChatSortType>(
                          value: v,
                          title: Text(_sortLabel(v)),
                          activeColor: cs.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          setState(() => _sortBy = draftSort);
                          await _saveSortPreferences();
                          await _loadActiveChats();
                          if (!mounted) return;
                          Navigator.pop(ctx);
                        },
                        child: Text(_trOr('sort_confirm', 'Confirm')),
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

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: RefreshIndicator(onRefresh: _handleRefresh, child: _buildBody()),
      ),
    );
  }

  void _openSelectContact({SelectContactMode mode = SelectContactMode.newChat}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectContactScreen(
          mode: mode,
          onContactSelected: (chatData) {
            widget.onChatSelected(chatData);
            initData();
            Navigator.pop(context);
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }



  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;
    final controlTextColor = colorScheme.onSurface;
    final orderArrowColor = colorScheme.onSurface;
    final actionIconColor = colorScheme.primary;

    final Widget chatContent;
    final String chatContentKey;
    if (_isLoadingChats && _activeChats.isEmpty) {
      chatContent = const ChatListSkeleton();
      chatContentKey = 'loading';
    } else if (_activeChats.isEmpty) {
      chatContent = _buildEmptyState();
      chatContentKey = 'empty';
    } else {
      chatContent = _buildChatList();
      chatContentKey = 'list';
    }

    return Column(
      children: [

        // Visual Header from Image
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SizedBox(
            height: 34,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [...previousChildren, ?currentChild],
                );
              },
              transitionBuilder: (child, animation) {
                final curved = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInCubic,
                );

                return FadeTransition(
                  opacity: curved,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(curved),
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.985,
                        end: 1,
                      ).animate(curved),
                      child: child,
                    ),
                  ),
                );
              },
              child: _selectedChatIds.isNotEmpty
                  ? Row(
                      key: const ValueKey('selected_header_mode'),
                      children: [
                        IconButton(
                          onPressed: _clearSelection,
                          icon: Icon(Icons.close_rounded, color: _secondaryTextColor(context)),
                          style: IconButton.styleFrom(minimumSize: const Size(34, 34)),
                        ),
                        const SizedBox(width: 8),
                        const Spacer(),
                        IconButton.filledTonal(
                          onPressed: _togglePinSelectedChats,
                          icon: Icon(Icons.push_pin, size: 18, color: actionIconColor),
                          style: IconButton.styleFrom(minimumSize: const Size(44, 34), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _resummarySelectedChats,
                          icon: Icon(Icons.auto_awesome_rounded, size: 16, color: actionIconColor),
                          label: Text('Re-Summary', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: controlTextColor)),
                          style: FilledButton.styleFrom(minimumSize: const Size(126, 34), padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _deleteSelectedChats,
                          icon: Icon(Icons.delete_outline_rounded, size: 20, color: actionIconColor),
                          style: IconButton.styleFrom(minimumSize: const Size(44, 34), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ],
                    )
                  : Row(
                      key: const ValueKey('filter_header_mode'),
                      children: [
                        Text(
                          'Chats (${_activeChats.length})',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: _chatHeaderPopupFont,
                            color: _primaryTextColor(context),
                          ),
                        ),
                        const Spacer(),
                        FilledButton.tonalIcon(
                          onPressed: _showSortSheet,
                          icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                          label: Text(_sortLabel(_sortBy), overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          style: FilledButton.styleFrom(minimumSize: const Size(118, 34), padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filledTonal(
                          onPressed: () async {
                            setState(() => _sortAscending = !_sortAscending);
                            await _saveSortPreferences();
                            await _loadActiveChats();
                          },
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                              key: ValueKey<bool>(_sortAscending),
                              size: 18,
                              color: orderArrowColor,
                            ),
                          ),
                          style: IconButton.styleFrom(minimumSize: const Size(44, 34), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        Divider(
          height: 0.5,
          thickness: 0.7,
          indent: 12,
          endIndent: 12,
          color: _chatSeparatorColor(context),
        ),
        Expanded(
          child: Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(
                key: ValueKey(chatContentKey),
                child: chatContent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 100,
                color: Theme.of(context).dividerColor,
              ),
              const SizedBox(height: 24),
              Text(
                tr('tab_chat_empty_title'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _secondaryTextColor(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr('tab_chat_empty_subtitle'),
                style: TextStyle(color: _secondaryTextColor(context)),
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
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 0.7,
        indent: 12,
        endIndent: 12,
        color: _chatSeparatorColor(context),
      ),
      itemBuilder: (context, index) {
        final colorScheme = Theme.of(context).colorScheme;
        final chat = _activeChats[index];
        final chatId = chat['id'].toString();
        final isSelected = _selectedChatIds.contains(chatId);
        final selectedChatBgColor = colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.52);
        final bondLevel = (chat['bond_hearts'] ?? 0).toString();

        final bool isGroupChat = chatId.startsWith('group_');

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: ListTile(
            selected: isSelected,
            tileColor: Colors.transparent,
            selectedTileColor: selectedChatBgColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_selectedChatIds.isNotEmpty) {
                  _toggleChatSelection(chatId);
                  return;
                }
                _showProfilePreview(chat);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: _parseColor(chat['color']),
                    backgroundImage: chat['image_url'] != null
                        ? CachedNetworkImageProvider((chat['thumb_url'] ?? chat['image_url']).toString())
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
                  if (chat['isPinned'] == true)
                    Positioned(
                      top: -6,
                      left: -8,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8EDF2).withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Transform.rotate(
                          angle: -0.18,
                          child: const Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.push_pin,
                                size: 13.8,
                                color: Color(0xFFAA8B7C),
                              ),
                              Icon(
                                Icons.push_pin,
                                size: 11.8,
                                color: Color(0xFFFFE955),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (chat['child'] == true && !isGroupChat)
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: IgnorePointer(
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 2.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.child_care,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: -3,
                    bottom: -2,
                    child: IgnorePointer(
                      child: AnimatedScale(
                        scale: isSelected ? 1 : 0.6,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: isSelected ? 1 : 0,
                          duration: const Duration(milliseconds: 170),
                          curve: Curves.easeOutCubic,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedChatBgColor,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            title: Row(
              children: [
                Text(
                  (chat['name'] as String).length > 15
                      ? '${(chat['name'] as String).substring(0, 15)}...'
                      : chat['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _primaryTextColor(context),
                  ),
                ),
                if (_isBirthday(chat['birthday']))
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('🎂', style: TextStyle(fontSize: 14)),
                  ),
                const Spacer(),
                Text(
                  chat['time'],
                  style: TextStyle(
                    fontSize: 12,
                    color: _secondaryTextColor(context),
                  ),
                ),
              ],
            ),

            trailing: isGroupChat
                ? const SizedBox.shrink()
                : _bondDisabled
                    ? const SizedBox.shrink()
                    : Container(
                        width: 45,
                        height: 45,
                        margin: const EdgeInsets.only(left: 8),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: Color(0xFFE462B5),
                              size: 43,
                            ),
                            const Icon(
                              Icons.favorite,
                              color: Color(0xFFF3B7D1),
                              size: 39,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                bondLevel,
                                style: _bondCountStyle(context),
                              ),
                            ),
                          ],
                        ),
                      ),
            onTap: () async {
              if (_selectedChatIds.isNotEmpty) {
                _toggleChatSelection(chatId);
                return;
              }

              widget.onChatSelected(chat);
            },
            onLongPress: () => _toggleChatSelection(chatId, forceSelect: true),
          ),
        );
      },
    );
  }

  void _showProfilePreview(Map<String, dynamic> chat) {
    final String name = (chat['name'] ?? '').toString();
    final String? imageUrl = chat['image_url']?.toString();
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Profile preview',
      barrierColor: Colors.black.withValues(alpha: 0.72),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final size = MediaQuery.of(dialogContext).size;
        final imageWidth = size.width * 0.78;

        return Material(
          type: MaterialType.transparency,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.pop(dialogContext),
                ),
              ),
              Center(
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: imageWidth,
                    constraints: BoxConstraints(
                      maxWidth: 420,
                      maxHeight: size.height * 0.72,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (imageUrl != null && imageUrl.isNotEmpty)
                            CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Container(
                                  color: _parseColor(chat['color']),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 84,
                                    ),
                                  ),
                                ),
                            )
                          else
                            Container(
                              color: _parseColor(chat['color']),
                              alignment: Alignment.center,
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 84,
                                ),
                              ),
                            ),
                          Positioned(
                            left: 14,
                            right: 14,
                            top: 12,
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 6,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  void _toggleChatSelection(String chatId, {bool forceSelect = false}) {
    setState(() {
      if (forceSelect) {
        _selectedChatIds.add(chatId);
        return;
      }

      if (_selectedChatIds.contains(chatId)) {
        _selectedChatIds.remove(chatId);
      } else {
        _selectedChatIds.add(chatId);
      }
    });
  }

  void _clearSelection() {
    if (_selectedChatIds.isEmpty) return;
    setState(() => _selectedChatIds.clear());
  }

  List<Map<String, dynamic>> _getSelectedChats() {
    return _activeChats
        .where((chat) => _selectedChatIds.contains(chat['id'].toString()))
        .toList();
  }

  Future<void> _togglePinSelectedChats() async {
    final selectedChats = _getSelectedChats();
    if (selectedChats.isEmpty) return;

    final allPinned = selectedChats.every((chat) => chat['isPinned'] == true);
    final selectedIds = selectedChats
        .map((chat) => chat['id'].toString())
        .toList();

    if (allPinned) {
      _pinnedChatIds.removeWhere((id) => selectedIds.contains(id));
      await _localChatService.savePinnedChats(_pinnedChatIds);
      _clearSelection();
      await _loadActiveChats();
      return;
    }

    final idsToPin = selectedChats
        .where((chat) => chat['isPinned'] != true)
        .map((chat) => chat['id'].toString())
        .toList();

    final availableSlots = 5 - _pinnedChatIds.length;
    if (availableSlots <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anda hanya bisa pin maksimal 5 chat.')),
        );
      }
      return;
    }

    final idsPinnedNow = idsToPin.take(availableSlots).toList();
    for (final id in idsPinnedNow) {
      if (!_pinnedChatIds.contains(id)) {
        _pinnedChatIds.add(id);
      }
    }

    await _localChatService.savePinnedChats(_pinnedChatIds);

    if (mounted && idsPinnedNow.length < idsToPin.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sebagian chat tidak dipin karena batas 5.'),
        ),
      );
    }

    _clearSelection();
    await _loadActiveChats();
  }

  Future<void> _resummarySelectedChats() async {
    final selectedIds = _selectedChatIds.toList();
    if (selectedIds.isEmpty) return;

    await Future.wait(
      selectedIds.map((chatId) async {
        await _localChatService.saveSummaries(chatId, {});
        await _localChatService.saveMemories(chatId, []);
      }),
    );

    _clearSelection();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          selectedIds.length == 1
              ? 'Summary reset. Will generate on next open.'
              : 'Summary ${selectedIds.length} chat di-reset.',
        ),
      ),
    );
  }

  Future<void> _deleteSelectedChats() async {
    final selectedIds = _selectedChatIds.toList();
    if (selectedIds.isEmpty) return;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          selectedIds.length == 1
              ? 'Hapus chat ini?'
              : 'Hapus ${selectedIds.length} chat?',
        ),
        content: const Text('Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    for (final chatId in selectedIds) {
      await _localChatService.deleteChat(chatId);
    }

    _clearSelection();
    await initData();
  }

  Widget _buildSortOverlayContent(ChatSortType initialSort) {
    ChatSortType draftSort = initialSort;
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surfaceColor(context),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(_trOr('sort_title', 'Sort'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryTextColor(context))),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            if (widget.onShowSort != null) widget.onShowSort!(const SizedBox.shrink());
                            if (Navigator.of(context).canPop()) Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    RadioGroup<ChatSortType>(
                      groupValue: draftSort,
                      onChanged: (nv) => setSheetState(() => draftSort = nv!),
                      child: Column(
                        children: _sortOptions.map((v) => RadioListTile<ChatSortType>(
                          value: v,
                          title: Text(_sortLabel(v)),
                          activeColor: Theme.of(context).colorScheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          setState(() => _sortBy = draftSort);
                          await _saveSortPreferences();
                          await _loadActiveChats();
                          if (widget.onShowSort != null) widget.onShowSort!(const SizedBox.shrink());
                        },
                        child: Text(_trOr('sort_confirm', 'Confirm')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
