import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/local_chat_service.dart';
import '../../services/bot_service.dart';
import '../../services/localization_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../widgets/skeleton_loader.dart';
import '../select_contact_screen.dart';
import '../chat_screen.dart';

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
  ChatSortType _sortBy = ChatSortType.newest;
  bool _sortAscending = false;
  bool _showSyncNotice = true;
  StreamSubscription<String>? _chatUpdateSubscription;

  static const String _chatSortByKey = 'chat_sort_by';
  static const String _chatSortAscKey = 'chat_sort_ascending';
  static const String _syncNoticeDismissedKey = 'chat_sync_notice_dismissed';
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

  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

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
    final isDark = _isDark(context);
    final colorScheme = Theme.of(context).colorScheme;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white;

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

  Future<void> _loadSyncNoticePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_syncNoticeDismissedKey) ?? false;
    if (mounted) {
      setState(() {
        _showSyncNotice = !dismissed;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSyncNoticePreference();
    _loadSortPreferencesAndInit();

    // Listen to real-time chat updates (new messages, deleted chats)
    _chatUpdateSubscription = LocalChatService.onChatUpdated.listen((chatId) {
      if (mounted) {
        initData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _chatUpdateSubscription?.cancel();
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
    final bots = await _botService.getBots(forceRefresh: force);
    if (mounted) {
      setState(() {
        _availableBots = bots;
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
      bool isGroup = id.startsWith('group_');

      if (isGroup && history.isNotEmpty) {
        // Try to get group name from system message metadata
        final systemMsg = history.firstWhere(
          (m) => m['role'] == 'system' && m['metadata'] != null,
          orElse: () => <String, dynamic>{},
        );
        if (systemMsg.isNotEmpty && systemMsg['metadata'] != null) {
          final metadata = systemMsg['metadata'];
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

      if (bot == null) {
        try {
          bot = _availableBots.firstWhere((b) => b['id'].toString() == id);
        } catch (_) {
          bot = await _botService.getBotById(id);
        }
      }

      bot ??= {'id': id, 'name': id, 'avatar': null, 'color': '0xFF607D8B'};

      if (history.isNotEmpty) {
        loadedChats.add({
          ...bot,
          'lastMessage': history.last['content'] ?? '...',
          'time': _formatDateTime(meta['lastModified']),
          'provider': isGroup ? 'Group' : 'Global Config',
          'lastModified': meta['lastModified'],
          'isPinned': _pinnedChatIds.contains(id),
        });
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

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Sort',
      barrierColor: Colors.black.withValues(alpha: 0.05),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (overlayContext, animation, secondaryAnimation) {
        final media = MediaQuery.of(overlayContext);
        final double topOffset = media.padding.top + kToolbarHeight + 44;

        return StatefulBuilder(
          builder: (dialogContext, setSheetState) {
            const compactControlHeight = 34.0;
            final colorScheme = Theme.of(dialogContext).colorScheme;
            final selectedColor = colorScheme.primary;
            final titleTextColor = _primaryTextColor(dialogContext);
            final solidModalShadow = [
              BoxShadow(
                color: _isDark(dialogContext)
                    ? Colors.black.withValues(alpha: 0.58)
                    : Colors.black.withValues(alpha: 0.2),
                offset: const Offset(0, 3),
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ];

            Widget buildSortChoice(ChatSortType value) {
              final bool isSelected = draftSort == value;

              return InkWell(
                onTap: () => setSheetState(() => draftSort = value),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: compactControlHeight,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? selectedColor
                        : _surfaceAltColor(dialogContext),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? selectedColor
                          : _borderColor(dialogContext),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isDark(dialogContext)
                            ? Colors.black.withValues(alpha: 0.42)
                            : Colors.black.withValues(alpha: 0.12),
                        offset: const Offset(0, 2),
                        blurRadius: 0,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    _sortLabel(value),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      fontFamily: _chatHeaderPopupFont,
                      color: isSelected
                          ? colorScheme.onPrimary
                          : _secondaryTextColor(dialogContext),
                    ),
                  ),
                ),
              );
            }

            Widget buildOptionsRow(List<ChatSortType> options) {
              return Row(
                children: [
                  for (int i = 0; i < options.length; i++) ...[
                    Expanded(child: buildSortChoice(options[i])),
                    if (i != options.length - 1) const SizedBox(width: 10),
                  ],
                  if (options.length == 1) ...[
                    const SizedBox(width: 10),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ],
              );
            }

            return Material(
              type: MaterialType.transparency,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox.expand(),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    top: topOffset,
                    child: SafeArea(
                      bottom: false,
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          decoration: BoxDecoration(
                            color: _surfaceColor(dialogContext),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: solidModalShadow,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  10,
                                  8,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _trOr('sort_title', 'Sort'),
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: _chatHeaderPopupFont,
                                        color: titleTextColor,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: _secondaryTextColor(
                                          dialogContext,
                                        ),
                                        size: 28,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: Theme.of(dialogContext).dividerColor,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  10,
                                ),
                                child: Column(
                                  children: [
                                    buildOptionsRow(
                                      _sortOptions.take(2).toList(),
                                    ),
                                    const SizedBox(height: 8),
                                    buildOptionsRow(
                                      _sortOptions.skip(2).take(2).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: Theme.of(dialogContext).dividerColor,
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  10,
                                  12,
                                  12,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      setState(() {
                                        _sortBy = draftSort;
                                      });
                                      await _saveSortPreferences();
                                      await _loadActiveChats();
                                      if (!mounted) return;
                                      Navigator.of(context).pop();
                                    },
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: _surfaceAltColor(
                                        dialogContext,
                                      ),
                                      foregroundColor: _primaryTextColor(
                                        dialogContext,
                                      ),
                                      side: BorderSide(
                                        color: _borderColor(dialogContext),
                                      ),
                                      minimumSize: const Size(
                                        double.infinity,
                                        compactControlHeight,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      _trOr('sort_confirm', 'Confirm'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: _chatHeaderPopupFont,
                                      ),
                                    ),
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
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
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
      floatingActionButton: _buildExpandableFab(),
    );
  }

  Widget _buildExpandableFab() {
    final colorScheme = Theme.of(context).colorScheme;
    const slant = 0.174533;

    return SizedBox(
      width: 50,
      height: 46,
      child: Transform(
        transform: Matrix4.skewX(-slant),
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: _isDark(context)
                      ? Colors.black.withValues(alpha: 0.6)
                      : Colors.black.withValues(alpha: 0.24),
                  blurRadius: 0,
                  spreadRadius: 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () {
                if (widget.onAddContact != null) {
                  widget.onAddContact!();
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SelectContactScreen(
                        onContactSelected: (chatData) {
                          widget.onChatSelected(chatData);
                          initData(); // Refresh list
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(
                                bot: chatData,
                                provider: 'gemini',
                              ),
                            ),
                          );
                        },
                        onCancel: () => Navigator.pop(context),
                      ),
                    ),
                  );
                }
              },
              child: Transform(
                transform: Matrix4.skewX(slant),
                alignment: Alignment.center,
                child: Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: colorScheme.onPrimary,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParallelogramControl({
    required BuildContext context,
    required VoidCallback onTap,
    required Widget child,
    double? width,
    double height = 34,
    bool accent = false,
    bool showCornerArrow = false,
    AlignmentGeometry contentAlignment = Alignment.center,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 6,
    ),
  }) {
    final isDark = _isDark(context);
    final colorScheme = Theme.of(context).colorScheme;
    const lightControlColor = Color(0xFF424242);
    const slant = 0.174533;

    final fillColor = isDark
        ? colorScheme.onSurface.withValues(alpha: accent ? 0.12 : 0.09)
        : Colors.white;

    final cornerArrowColor = isDark
        ? colorScheme.onSurfaceVariant
        : lightControlColor;

    final boxShadows = isDark
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: accent ? 0.6 : 0.54),
              offset: const Offset(0, 3),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: accent ? 0.24 : 0.2),
              offset: const Offset(0, 3),
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ];

    return SizedBox(
      width: width,
      height: height,
      child: Transform(
        transform: Matrix4.skewX(-slant),
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(4),
            boxShadow: boxShadows,
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    child: Transform(
                      transform: Matrix4.skewX(slant),
                      alignment: Alignment.center,
                      child: Padding(
                        padding: padding,
                        child: Align(alignment: contentAlignment, child: child),
                      ),
                    ),
                  ),
                ),
              ),
              if (showCornerArrow)
                Positioned(
                  right: 3,
                  top: 2,
                  child: Transform(
                    transform: Matrix4.skewX(slant),
                    alignment: Alignment.center,
                    child: CustomPaint(
                      size: const Size(11, 9),
                      painter: _CornerArrowPainter(color: cornerArrowColor),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = _isDark(context);
    const lightControlColor = Color(0xFF424242);
    final controlTextColor = isDark ? colorScheme.onSurface : lightControlColor;
    final orderListColor = isDark
        ? colorScheme.onSurfaceVariant
        : lightControlColor;
    final orderArrowColor = isDark ? colorScheme.onSurface : lightControlColor;
    final actionIconColor = isDark ? colorScheme.primary : lightControlColor;

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
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool(_syncNoticeDismissedKey, true);
                    if (mounted) {
                      setState(() {
                        _showSyncNotice = false;
                      });
                    }
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
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _clearSelection,
                              borderRadius: BorderRadius.circular(8),
                              child: Icon(
                                Icons.close_rounded,
                                size: 24,
                                color: _secondaryTextColor(context),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Spacer(),
                        _buildParallelogramControl(
                          context: context,
                          onTap: _togglePinSelectedChats,
                          width: 44,
                          height: 34,
                          accent: true,
                          padding: EdgeInsets.zero,
                          child: Icon(
                            Icons.push_pin,
                            size: 18,
                            color: actionIconColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildParallelogramControl(
                          context: context,
                          onTap: _resummarySelectedChats,
                          width: 126,
                          height: 34,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 16,
                                color: actionIconColor,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Re-Summary',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: _chatHeaderPopupFont,
                                  color: controlTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildParallelogramControl(
                          context: context,
                          onTap: _deleteSelectedChats,
                          width: 44,
                          height: 34,
                          accent: true,
                          padding: EdgeInsets.zero,
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: actionIconColor,
                          ),
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
                        _buildParallelogramControl(
                          context: context,
                          onTap: _showSortSheet,
                          width: 118,
                          height: 34,
                          showCornerArrow: true,
                          contentAlignment: Alignment.center,
                          padding: const EdgeInsets.only(
                            left: 10,
                            right: 10,
                            top: 6,
                            bottom: 6,
                          ),
                          child: Text(
                            _sortLabel(_sortBy),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isDark
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              fontFamily: _chatHeaderPopupFont,
                              color: controlTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildParallelogramControl(
                          context: context,
                          onTap: () async {
                            setState(() {
                              _sortAscending = !_sortAscending;
                            });
                            await _saveSortPreferences();
                            await _loadActiveChats();
                          },
                          width: 58,
                          height: 34,
                          accent: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.92,
                                    end: 1,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: CustomPaint(
                              key: ValueKey<bool>(_sortAscending),
                              size: const Size(24, 14),
                              painter: _OrderGlyphPainter(
                                ascending: _sortAscending,
                                lineColor: orderListColor,
                                arrowColor: orderArrowColor,
                              ),
                            ),
                          ),
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
          child: Container(
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
            .withValues(alpha: _isDark(context) ? 0.52 : 0.95);
        final bondLevel = (chat['bond_hearts'] ?? 0).toString();

        final bool isGroupChat = chatId.startsWith('group_');

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          color: isSelected ? selectedChatBgColor : Colors.transparent,
          child: ListTile(
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
                  chat['name'],
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
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                chat['lastMessage'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 15,
                ),
              ),
            ),
            trailing: isGroupChat
                ? const SizedBox(width: 45)
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
                            Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
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
                                );
                              },
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
      selectedIds.map((chatId) => _localChatService.saveSummaries(chatId, {})),
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
    const compactControlHeight = 34.0;

    return StatefulBuilder(
      builder: (context, setSheetState) {
        final colorScheme = Theme.of(context).colorScheme;
        final selectedColor = colorScheme.primary;
        final titleTextColor = _primaryTextColor(context);

        Widget buildSortChoice(ChatSortType value) {
          final bool isSelected = draftSort == value;
          return InkWell(
            onTap: () => setSheetState(() => draftSort = value),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: compactControlHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? selectedColor : _surfaceAltColor(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? selectedColor : _borderColor(context),
                ),
              ),
              child: Text(
                _sortLabel(value),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : _secondaryTextColor(context),
                ),
              ),
            ),
          );
        }

        Widget buildOptionsRow(List<ChatSortType> options) {
          return Row(
            children: [
              for (int i = 0; i < options.length; i++) ...[
                Expanded(child: buildSortChoice(options[i])),
                if (i != options.length - 1) const SizedBox(width: 10),
              ],
            ],
          );
        }

        return Container(
          color: Colors.black.withValues(alpha: 0.3),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surfaceColor(context),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Text(
                          _trOr('sort_title', 'Sort'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: titleTextColor,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            if (widget.onShowSort != null) {
                              widget.onShowSort!(const SizedBox.shrink());
                            }
                            if (Navigator.of(context).canPop()) {
                              Navigator.pop(context);
                            }
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        buildOptionsRow(_sortOptions.take(2).toList()),
                        const SizedBox(height: 8),
                        buildOptionsRow(_sortOptions.skip(2).toList()),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _sortBy = draftSort;
                        });
                        await _saveSortPreferences();
                        await _loadActiveChats();
                        if (widget.onShowSort != null) {
                          widget.onShowSort!(const SizedBox.shrink());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(_trOr('sort_confirm', 'Confirm')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CornerArrowPainter extends CustomPainter {
  final Color color;

  const _CornerArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerArrowPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _OrderGlyphPainter extends CustomPainter {
  final bool ascending;
  final Color lineColor;
  final Color arrowColor;

  const _OrderGlyphPainter({
    required this.ascending,
    required this.lineColor,
    required this.arrowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final arrowPaint = Paint()
      ..color = arrowColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    const left = 1.0;
    canvas.drawLine(Offset(left, 2.4), Offset(left + 10.8, 2.4), linePaint);
    canvas.drawLine(Offset(left, 7), Offset(left + 12.5, 7), linePaint);
    canvas.drawLine(Offset(left, 11.6), Offset(left + 8.8, 11.6), linePaint);

    final x = size.width - 4.8;
    const yTop = 2.4;
    const yBottom = 11.6;
    const head = 3.1;

    canvas.drawLine(Offset(x, yTop), Offset(x, yBottom), arrowPaint);

    if (ascending) {
      canvas.drawLine(
        Offset(x, yTop),
        Offset(x - head, yTop + head),
        arrowPaint,
      );
      canvas.drawLine(
        Offset(x, yTop),
        Offset(x + head, yTop + head),
        arrowPaint,
      );
    } else {
      canvas.drawLine(
        Offset(x, yBottom),
        Offset(x - head, yBottom - head),
        arrowPaint,
      );
      canvas.drawLine(
        Offset(x, yBottom),
        Offset(x + head, yBottom - head),
        arrowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrderGlyphPainter oldDelegate) {
    return oldDelegate.ascending != ascending ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.arrowColor != arrowColor;
  }
}
