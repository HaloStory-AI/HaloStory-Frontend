import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/local_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../constants.dart';

import '../services/localization_service.dart';
import '../utils/chat_theme_helpers.dart';
import '../utils/chat_resolver.dart';
import '../widgets/chat/user_bubble.dart';
import '../widgets/chat/bot_bubble.dart';
import '../widgets/chat/typing_indicator.dart';
import '../widgets/chat/safety_bar.dart';
import '../widgets/chat/system_note_area.dart';
import '../widgets/chat/character_menu.dart';
import '../widgets/chat/chat_input_area.dart';
import '../widgets/chat/bond_stats_sheet.dart';
import '../widgets/chat/student_bio_sheet.dart';
import '../widgets/chat/message_options_sheet.dart';
import '../widgets/chat/bond_simulator_sheet.dart';
import '../widgets/chat/debug_overlay.dart';
import '../widgets/chat/desktop_overlay.dart';
import 'select_contact_screen.dart';

@Preview(name: 'Chat Detail Screen', size: Size(390, 844))
Widget chatDetailScreenPreview() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ChatDetailScreen(
      bot: <String, dynamic>{
        'id': 'preview-bot-1',
        'name': 'Airi',
        'description': 'Preview bot for chat screen layout',
        'personality':
            'Nickname: Airi\nAge: 19\nNationality: Japanese\nHeight: 160 cm\nWeight: 48 kg\nLike: Music\nDislike: Silence',
        'image_url': null,
        'color': null,
        'bond_hearts': 7,
        'birthday': null,
      },
      provider: 'Preview',
    ),
  );
}

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> bot;
  final String provider;
  final String? initialMessage;
  final bool isDesktopMode;

  const ChatDetailScreen({
    super.key,
    required this.bot,
    required this.provider,
    this.initialMessage,
    this.isDesktopMode = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();
  final LocalChatService _localChatService = LocalChatService();

  static bool _hasShownSystemAiWarning = false;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  Map<int, String> _summaries = {};
  bool _isSummarizing = false;
  double _summaryProgress = 0.0;
  bool _isTypingEffectActive = false;
  bool _isLockedForSummary = false;
  bool _isDisposed = false;
  bool _showScrollButton = false;
  Timer? _pollingTimer;
  bool _isPollingCompleted = false;
  List<Map<String, dynamic>> _allMessages = [];
  static const int _pageSize = 20;
  bool _isLoadingMore = false;

  // Debug overlay state
  bool _showDebugOverlay = false;
  OverlayEntry? _debugOverlayEntry;
  final List<String> _debugLogs = [];
  final ScrollController _debugScrollController = ScrollController();

  final TextEditingController _systemNoteController = TextEditingController();
  bool _isSystemNoteOpen = false;
  bool _isCharacterMenuOpen = false;
  String? _activeOverlay;

  // Bond state
  String _bondStatus = 'normal';
  String _bondRelationship = 'Orang Asing';
  late int _bondLevel;
  String? _pendingBondEvent;

  static const String _chatHeaderFont = 'Roboto';
  bool _showExplosion = false;
  bool _showSafetyBar = false;

  bool _isGroup = false;
  List<Map<String, dynamic>> _groupMembers = [];
  String? _selectedBotId;
  String _groupName = '';
  String _groupBio = '';
  String? _activeBotId;
  bool _hideItalics = false;

  @override
  void initState() {
    super.initState();
    _isGroup =
        widget.bot['id'].toString().startsWith('group_') ||
        (widget.bot['isGroup'] == true);
    _groupName = (widget.bot['name'] ?? '').toString();
    _groupBio = (widget.bot['description'] ?? widget.bot['bio'] ?? '')
        .toString();
    _bondLevel = widget.bot['bond_hearts'] ?? 0;
    _scrollController.addListener(_scrollListener);
    _loadHistory();
    _syncBondStats();
    _loadSystemNote();
    _showBugNoticeIfNeeded();
    _loadSelectedBot();
    _loadItalicsSetting();
    if (widget.provider == 'System' && !_hasShownSystemAiWarning) {
      _showSystemAiWarning();
      _hasShownSystemAiWarning = true;
    }
  }

  Future<void> _loadSelectedBot() async {
    if (!_isGroup) return;
    final prefs = await SharedPreferences.getInstance();
    final savedBotId = prefs.getString('selected_bot_${widget.bot['id']}');
    if (mounted) {
      setState(() {
        _selectedBotId = savedBotId;
      });
    }
  }

  Future<void> _saveSelectedBot(String botId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_bot_${widget.bot['id']}', botId);
    if (mounted) {
      setState(() {
        _selectedBotId = botId;
      });
    }
  }

  Future<void> _loadItalicsSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final hide = prefs.getBool('hide_italics_${widget.bot['id']}') ?? false;
    _safeSetState(() {
      _hideItalics = hide;
    });
  }

  Future<void> _saveItalicsSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_italics_${widget.bot['id']}', value);
    _safeSetState(() {
      _hideItalics = value;
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _pollingTimer?.cancel();
    _debugOverlayEntry?.remove();
    _debugScrollController.dispose();
    _scrollController.removeListener(_scrollListener);
    _messageController.dispose();
    _scrollController.dispose();
    _systemNoteController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted || _isDisposed) return;
    setState(fn);
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final shouldShow = (maxScroll - currentScroll) > 300;
    if (_showScrollButton != shouldShow) {
      _safeSetState(() {
        _showScrollButton = shouldShow;
      });
    }

    if (currentScroll <= 0 &&
        !_isLoadingMore &&
        _allMessages.length > _messages.length) {
      _loadMoreMessages();
    }
  }

  void _loadMoreMessages() {
    _isLoadingMore = true;
    final currentOldest = _allMessages.length - _messages.length;
    final newStart = currentOldest - _pageSize > 0
        ? currentOldest - _pageSize
        : 0;
    final olderMessages = _allMessages.sublist(newStart, currentOldest);

    _messages.insertAll(0, olderMessages);
    _safeSetState(() {});
    _isLoadingMore = false;
  }

  Future<void> _loadSystemNote() async {
    final prefs = await SharedPreferences.getInstance();
    final note = prefs.getString('system_note_${widget.bot['id']}') ?? '';
    if (!mounted || _isDisposed) return;
    _systemNoteController.text = note;
  }

  Future<void> _saveSystemNote() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'system_note_${widget.bot['id']}',
      _systemNoteController.text,
    );
  }

  void _showSystemAiWarning() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surfaceBackground(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/image/notice_image.png',
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                tr('system_notice_title'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('system_notice_content'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: subtitleColor(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: surfaceAltBackground(context),
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(tr('system_notice_btn')),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _showBugNoticeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenNotice = prefs.getBool('has_seen_chat_bug_notice') ?? false;

    if (!hasSeenNotice) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _isDisposed) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: surfaceBackground(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/image/info.png',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  tr('chat_bug_notice_title'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('chat_bug_notice_body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: subtitleColor(context),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await prefs.setBool('has_seen_chat_bug_notice', true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: surfaceAltBackground(context),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(tr('system_notice_btn')),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      });
    }
  }

  void _toggleDebugOverlay() {
    if (!kDebugMode) return;

    _safeSetState(() {
      _showDebugOverlay = !_showDebugOverlay;
    });

    if (_showDebugOverlay) {
      _debugOverlayEntry = OverlayEntry(
        builder: (context) => DebugOverlay(
          logs: _debugLogs,
          scrollController: _debugScrollController,
          onClose: () {
            _safeSetState(() {
              _showDebugOverlay = false;
            });
            _debugOverlayEntry?.remove();
            _debugOverlayEntry = null;
          },
          onClear: () {
            _safeSetState(() {
              _debugLogs.clear();
            });
          },
          onTestLog: () {
            _addDebugLog('Debug log test at ${DateTime.now()}');
          },
        ),
      );
      Overlay.of(context).insert(_debugOverlayEntry!);
    } else {
      _debugOverlayEntry?.remove();
      _debugOverlayEntry = null;
    }
  }

  void _addDebugLog(String message) {
    if (!kDebugMode) return;
    final timestamp = DateTime.now().toIso8601String();
    _safeSetState(() {
      _debugLogs.add('[$timestamp] $message');
      if (_debugLogs.length > 1000) {
        _debugLogs.removeRange(0, _debugLogs.length - 1000);
      }
    });

    if (_debugScrollController.hasClients) {
      _debugScrollController.animateTo(
        _debugScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
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

  Future<void> _loadHistory() async {
    final history = await _localChatService.loadChat(widget.bot['id']);
    for (var msg in history) {
      msg.remove('visible_parts');
      msg.remove('is_typing_next');
    }

    if (_isGroup && history.isNotEmpty) {
      final systemMsg = history.firstWhere(
        (m) => m['role'] == 'system' && m['metadata'] != null,
        orElse: () => <String, dynamic>{},
      );
      if (systemMsg.isNotEmpty && systemMsg['metadata'] != null) {
        final metadata = systemMsg['metadata'];
        _safeSetState(() {
          final resolvedName = (metadata['name'] ?? '').toString().trim();
          final resolvedBio = (metadata['bio'] ?? metadata['description'] ?? '')
              .toString()
              .trim();

          if (resolvedName.isNotEmpty) {
            _groupName = resolvedName;
            widget.bot['name'] = resolvedName;
          }

          _groupBio = resolvedBio;
          widget.bot['description'] = resolvedBio;

          if (metadata['members'] != null) {
            _groupMembers = List<Map<String, dynamic>>.from(
              metadata['members'],
            );
            if (_selectedBotId == null && _groupMembers.isNotEmpty) {
              _selectedBotId =
                  _groupMembers.first['bot_id']?.toString() ??
                  _groupMembers.first['id']?.toString();
            }
          }
        });
      }
    }

    final summaries = await _localChatService.loadSummaries(widget.bot['id']);
    if (!mounted || _isDisposed) return;
    _safeSetState(() {
      _allMessages = history;
      final start = history.length > _pageSize ? history.length - _pageSize : 0;
      _messages = history.sublist(start);
      _summaries = summaries;
    });
    _scrollToBottom();

    _generateSummaries();
    _checkAndStartForcedSummary();

    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _messageController.text = widget.initialMessage!;
      _sendMessage();
    }
  }

  Future<bool> _summarizeSingleBatch(
    List<Map<String, dynamic>> realMessages,
    int start,
    int batchSize,
  ) async {
    if (_summaries.containsKey(start)) return false;
    if (!mounted || _isDisposed) return false;

    try {
      final List<Map<String, String>> batch = realMessages
          .sublist(start, start + batchSize)
          .map(
            (m) => {
              'role': m['role'] as String,
              'content': m['content'] as String,
            },
          )
          .toList();

      final result = await _aiService.summarizeChat(
        messages: batch,
        botId: widget.bot['id'],
        provider: widget.provider,
      );

      if (result != null &&
          result['status'] == 'queued' &&
          result['uuid'] != null) {
        String uuid = result['uuid'];
        bool summaryCompleted = false;
        int timeoutChecks = 60;

        while (mounted &&
            !_isDisposed &&
            !summaryCompleted &&
            timeoutChecks > 0) {
          await Future.delayed(const Duration(seconds: 2));
          final statusCheck = await _aiService.checkChatStatus(uuid);
          if (statusCheck != null) {
            if (statusCheck['status'] == 'queued' ||
                statusCheck['status'] == 'processing') {
            } else if (statusCheck['status'] == 'not_found' ||
                statusCheck['status'] == 'failed' ||
                statusCheck['error'] != null) {
              summaryCompleted = true;
            } else {
              final summaryText =
                  statusCheck['summary'] ?? statusCheck['response']?['summary'];
              if (summaryText != null) {
                _summaries[start] = summaryText;
                await _localChatService.saveSummaries(
                  widget.bot['id'], _summaries,
                );
              }
              summaryCompleted = true;
            }
          }
          timeoutChecks--;
        }
      } else if (result != null && result['summary'] != null) {
        _summaries[start] = result['summary'];
        await _localChatService.saveSummaries(
          widget.bot['id'], _summaries,
        );
      }

      return _summaries.containsKey(start);
    } catch (_) {
      return false;
    }
  }

  Future<void> _generateSummaries() async {
    if (_isSummarizing) return;
    if (!mounted || _isDisposed) return;

    _addDebugLog('Starting summary generation for bot ${widget.bot['id']}');

    const int batchSize = 20;

    final List<Map<String, dynamic>> realMessages = _messages
        .where(
          (m) =>
              m['content'] != null &&
              m['role'] != 'system' &&
              m['isTempSummary'] != true,
        )
        .toList();

    int totalBatchesToSummarize = 0;
    for (int i = 0; i <= realMessages.length - batchSize; i += batchSize) {
      if (!_summaries.containsKey(i)) {
        totalBatchesToSummarize++;
      }
    }

    if (totalBatchesToSummarize == 0) return;

    _safeSetState(() {
      _isSummarizing = true;
      _summaryProgress = 0.0;
    });

    int processedBatches = 0;

    for (int i = 0; i <= realMessages.length - batchSize; i += batchSize) {
      await _summarizeSingleBatch(realMessages, i, batchSize);
      processedBatches++;
      _safeSetState(() {
        _summaryProgress = processedBatches / totalBatchesToSummarize;
      });
    }

    _safeSetState(() {
      _isSummarizing = false;
      _summaryProgress = 0.0;
    });
  }

  Future<void> _checkAndStartForcedSummary() async {
    if (_isDisposed || !mounted || _isLockedForSummary) return;

    final realMessages = _allMessages
        .where((m) => m['content'] != null && m['role'] != 'system')
        .toList();
    final totalReal = realMessages.length;
    final summarizedCount = _summaries.length * 20;
    final remaining = totalReal - summarizedCount;

    if (remaining > 150 && totalReal > 150) {
      await _startForcedSummary(realMessages, totalReal);
    }
  }

  Future<void> _startForcedSummary(
    List<Map<String, dynamic>> realMessages,
    int totalReal,
  ) async {
    if (!mounted || _isDisposed) return;

    const int batchSize = 20;

    _safeSetState(() {
      _isLockedForSummary = true;
    });

    final progressNotifier = ValueNotifier<Map<String, int>>({
      'total': totalReal,
      'done': _summaries.length * 20,
      'remaining': totalReal - (_summaries.length * 20),
    });

    if (!mounted || _isDisposed) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _SummaryProgressDialog(notifier: progressNotifier),
    );

    for (int i = 0; i <= realMessages.length - batchSize; i += batchSize) {
      if (!mounted || _isDisposed) break;

      final currentDone = _summaries.length * 20;
      final currentRemaining = totalReal - currentDone;
      if (currentRemaining <= 150) break;

      await _summarizeSingleBatch(realMessages, i, batchSize);

      progressNotifier.value = {
        'total': totalReal,
        'done': _summaries.length * 20,
        'remaining': totalReal - (_summaries.length * 20),
      };
    }

    if (mounted && !_isDisposed) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    _safeSetState(() {
      _isLockedForSummary = false;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    Future.delayed(const Duration(milliseconds: 200), () {
      if (!mounted || _isDisposed || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    if (_isLoading || _isTypingEffectActive) return;

    if (_isGroup && _selectedBotId == null) {
      if (_groupMembers.isNotEmpty) {
        _selectedBotId =
            _groupMembers.first['bot_id']?.toString() ??
            _groupMembers.first['id']?.toString();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih karakter terlebih dahulu!')),
        );
        return;
      }
    }

    final userMessage = _messageController.text.trim();

    if (userMessage.isEmpty) {
      if (_messages.isNotEmpty && _messages.last['role'] == 'system') {
        _safeSetState(() {
          _messages.removeLast();
        });
      }
      await _getAIResponse();
      return;
    }

    _messageController.clear();
    final timestamp = DateTime.now().toIso8601String();
    final userMsg = {
      'role': 'user',
      'content': userMessage,
      'timestamp': timestamp,
      'status': 'sending',
      'uuid': null,
    };
    _safeSetState(() {
      _messages.add(userMsg);
      _allMessages.add(userMsg);
    });
    _scrollToBottom();

    await _getAIResponse();
  }

  Future<void> _regenerateResponse() async {
    if (_isLoading || _messages.isEmpty) return;

    if (_messages.last['role'] == 'assistant' ||
        _messages.last['role'] == 'system') {
      final originalBotId = _messages.last['bot_id'] as String?;
      _safeSetState(() {
        _messages.removeLast();
      });
      await _generateSummaries();
      await _getAIResponse(overrideBotId: originalBotId);
    }
  }

  Future<void> _getAIResponse({String? overrideBotId}) async {
    if (_isGroup && _selectedBotId == null) {
      if (_groupMembers.isNotEmpty) {
        _selectedBotId =
            _groupMembers.first['bot_id']?.toString() ??
            _groupMembers.first['id']?.toString();
      } else {
        _safeSetState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih karakter terlebih dahulu!')),
        );
        return;
      }
    }

    String? botIdForRequest =
        overrideBotId ?? (_isGroup ? _selectedBotId : widget.bot['id']);

    if (_isGroup && botIdForRequest == 'random' && _groupMembers.isNotEmpty) {
      final lastUserMessage = _messages.lastWhere(
        (m) => m['role'] == 'user',
        orElse: () => <String, dynamic>{},
      );

      if (lastUserMessage.isNotEmpty) {
        final content = (lastUserMessage['content'] as String).toLowerCase();
        String? mentionedId;

        for (final member in _groupMembers) {
          final fullName = (member['name'] as String).toLowerCase();
          final nameParts = fullName.split(' ');

          bool isMentioned = content.contains(fullName);
          if (!isMentioned) {
            for (final part in nameParts) {
              if (part.length >= 3 && content.contains(part)) {
                isMentioned = true;
                break;
              }
            }
          }

          if (isMentioned) {
            mentionedId =
                member['bot_id']?.toString() ?? member['id']?.toString();
            break;
          }
        }

        if (mentionedId != null) {
          botIdForRequest = mentionedId;
        } else {
          final rIndex = math.Random().nextInt(_groupMembers.length);
          botIdForRequest =
              _groupMembers[rIndex]['bot_id']?.toString() ??
              _groupMembers[rIndex]['id']?.toString();
        }
      }
    }

    _safeSetState(() {
      _isLoading = true;
      _activeBotId = botIdForRequest;
    });
    _scrollToBottom();

    String? summaryPrompt;
    if (_summaries.isNotEmpty) {
      summaryPrompt = "[CONVERSATION RECAP]\n";
      final sortedKeys = _summaries.keys.toList()..sort();
      for (var key in sortedKeys) {
        summaryPrompt =
            "${summaryPrompt!}- Messages ${key + 1}-${key + 20}: ${_summaries[key]}\n";
      }
    }

    List<Map<String, String>> fullHistory = _messages
        .where((m) => m['content'] != null && m['role'] != 'system')
        .map(
          (m) => {
            'role': m['role'] as String,
            'content': m['content'] as String,
          },
        )
        .toList();

    int summarizedCount = _summaries.length * 20;
    List<Map<String, String>> aiMessages;

    if (summarizedCount > 0) {
      int sliceIndex = (summarizedCount >= 4) ? summarizedCount - 4 : 0;
      if (sliceIndex < fullHistory.length) {
        aiMessages = fullHistory.sublist(sliceIndex);
      } else {
        aiMessages = fullHistory.isNotEmpty ? [fullHistory.last] : [];
      }
    } else {
      aiMessages = fullHistory;
    }

    if (_systemNoteController.text.trim().isNotEmpty) {
      aiMessages.insert(0, {
        'role': 'system',
        'content': _systemNoteController.text.trim(),
      });
    }

    if (aiMessages.isNotEmpty && aiMessages.last['role'] == 'assistant') {
      aiMessages.add({'role': 'user', 'content': '[Continue]'});
    }

    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _isDisposed) return;
    String language = prefs.getString('app_language') ?? 'Indonesian';

    if (kDebugMode) {
      print('DEBUG: --- SENDING TO AI ---');
      print('DEBUG: Bot ID: $botIdForRequest');
      print('DEBUG: Language: $language');
      if (summaryPrompt != null) {
        print('DEBUG: Summary Prompt: $summaryPrompt');
      }
      print('DEBUG: Messages Payload: ${jsonEncode(aiMessages)}');
      print('DEBUG: ---------------------');
    }

    try {
      final response = await _aiService.sendMessage(
        provider: widget.provider,
        messages: aiMessages,
        botId: botIdForRequest,
        botIds: _isGroup
            ? _groupMembers
                  .map((m) => m['bot_id']?.toString() ?? m['id']?.toString())
                  .whereType<String>()
                  .toList()
            : null,
        language: language,
        summary: summaryPrompt,
      );

      if (!mounted || _isDisposed) return;

      _safeSetState(() {
        final aiTimestamp = DateTime.now().toIso8601String();

        if (response != null && response['status'] == 'queued') {
          if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
            _messages.last['status'] = 'sent';
            _messages.last['uuid'] = response['uuid'];
          }
          _startPolling(response['uuid'], botIdForRequest, aiTimestamp);
          return;
        }

        _handleAIResponseData(response, botIdForRequest, aiTimestamp);
      });
    } catch (e) {
      if (!mounted || _isDisposed) return;
      _safeSetState(() {
        _isLoading = false;
        _activeBotId = null;
        _addSystemError(DateTime.now().toIso8601String());
      });
    }
  }

  void _startPolling(String uuid, String? botIdForRequest, String aiTimestamp) {
    _pollingTimer?.cancel();
    _isPollingCompleted = false;
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted || _isDisposed || _isPollingCompleted) {
        timer.cancel();
        return;
      }
      final response = await _aiService.checkChatStatus(uuid);
      if (!mounted || _isDisposed || _isPollingCompleted) {
        timer.cancel();
        return;
      }
      if (response == null || response['status'] == 'not_found') {
        timer.cancel();
        _safeSetState(() {
          _isLoading = false;
          _activeBotId = null;
          _addSystemError(aiTimestamp);
        });
        return;
      }

      if (response['status'] == 'processing') {
        _safeSetState(() {
          if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
            _messages.last['status'] = 'processing';
          }
        });
        return;
      }

      if (response['status'] == 'completed' ||
          response['choices'] != null ||
          response['error'] != null) {
        _isPollingCompleted = true;
        timer.cancel();
        _safeSetState(() {
          if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
            _messages.last['status'] = 'completed';
          }
        });
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted || _isDisposed) return;
        _handleAIResponseData(response, botIdForRequest, aiTimestamp);
      }
    });
  }

  void _handleAIResponseData(
    Map<String, dynamic>? response,
    String? botIdForRequest,
    String aiTimestamp,
  ) {
    bool shouldStartTyping = false;
    int partsLength = 0;

    _safeSetState(() {
      _isLoading = false;
      _activeBotId = null;

      if (response != null &&
          response['error'] != true &&
          response['choices'] != null) {
        String aiContent = response['choices'][0]['message']['content'] ?? '';

        if (aiContent.contains('[Need Help]')) {
          _showSafetyBar = true;
          aiContent = aiContent.replaceAll('[Need Help]', '').trim();
        }

        if (aiContent.isNotEmpty) {
          final parts = aiContent
              .split('\n\n')
              .where((s) => s.trim().isNotEmpty)
              .toList();

          final assMsg = <String, dynamic>{
            'role': 'assistant',
            'content': aiContent,
            'timestamp': aiTimestamp,
            'bot_id': botIdForRequest,
            'bot_name': resolveBotName(botIdForRequest, _groupMembers, widget.bot),
            'bot_avatar': resolveBotAvatar(botIdForRequest, _groupMembers, widget.bot),
            if (parts.length > 1) 'visible_parts': 1,
            if (parts.length > 1) 'is_typing_next': true,
          };

          _messages.add(assMsg);
          _allMessages.add(assMsg);

          if (parts.length > 1) {
            shouldStartTyping = true;
            partsLength = parts.length;
          }
        } else {
          _addSystemError(aiTimestamp);
        }
      } else {
        final int? statusCode = response != null
            ? response['status_code'] as int?
            : null;
        final dynamic rawError = response != null
            ? response['raw_error']
            : null;
        _addSystemError(
          aiTimestamp,
          statusCode: statusCode,
          rawError: rawError,
        );
      }

      if (response != null) {
        _bondStatus = response['bond_status'] ?? _bondStatus;
        _bondRelationship = response['relationship_label'] ?? _bondRelationship;
        _bondLevel = (response['bond_level'] as int?) ?? _bondLevel;
        _pendingBondEvent = response['bond_event'] as String?;
      }
    });

    if (shouldStartTyping) {
      _startTypingEffect(partsLength);
    }

    if (!_isTypingEffectActive) {
      _localChatService.saveChat(widget.bot['id'], _messages).then((_) {
        _generateSummaries();
      });
    }
    _scrollToBottom();

    if (_pendingBondEvent != null) {
      final evt = _pendingBondEvent!;
      _pendingBondEvent = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) _handleBondEvent(evt);
      });
    }
  }

  Future<void> _startTypingEffect(int totalParts) async {
    _safeSetState(() {
      _isTypingEffectActive = true;
    });

    for (int i = 1; i < totalParts; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      _scrollToBottom();

      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted || _isDisposed) return;

      _safeSetState(() {
        _messages.last['visible_parts'] = i + 1;
        if (i == totalParts - 1) {
          _messages.last.remove('is_typing_next');
          _isTypingEffectActive = false;
        }
      });

      await _localChatService.saveChat(widget.bot['id'], _messages);
      _scrollToBottom();
    }

    _generateSummaries();
  }

  void _showBondSimulator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BondSimulatorSheet(
        bot: widget.bot,
        onBondChanged: _syncBondStats,
      ),
    );
  }

  void _handleBondEvent(String event) {
    if (!mounted || _isDisposed) return;

    switch (event) {
      case 'relationship_damaged':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.heart_broken, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Hubungan kalian memburuk...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        break;

      case 'xp_lost':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.mood_bad, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  'Bond XP berkurang...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 2),
          ),
        );
        break;

      case 'relationship_upgraded':
        _triggerBondExplosion();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Hubungan kalian naik ke: $_bondRelationship! ✨',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.pink.shade400,
            duration: const Duration(seconds: 4),
          ),
        );
        break;

      case 'level_up':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.favorite, color: Colors.pinkAccent, size: 18),
                const SizedBox(width: 8),
                Text('Bond naik! Lv. $_bondLevel — $_bondRelationship'),
              ],
            ),
            backgroundColor: const Color(0xFF2D2D2D),
            duration: const Duration(seconds: 3),
          ),
        );
        break;

      case 'confession_triggered':
      case 'marriage_triggered':
        break;

      case 'relationship_stuck':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Keputusan telah dibuat. Status hubungan tidak berubah.',
            ),
            backgroundColor: Colors.blueGrey,
            duration: Duration(seconds: 3),
          ),
        );
        break;
    }
  }

  Future<void> _syncBondStats() async {
    try {
      final data = await _fetchBondStats();
      if (data != null && mounted && !_isDisposed) {
        _safeSetState(() {
          _bondStatus = data['bond_status'] ?? _bondStatus;
          _bondRelationship = data['relationship_label'] ?? _bondRelationship;
          _bondLevel = (data['bond_level'] as int?) ?? _bondLevel;
        });
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _fetchBondStats() async {
    final authService = AuthService();
    final token = await authService.getToken();
    if (token == null || !mounted || _isDisposed) {
      return null;
    }

    final botId = widget.bot['id'];
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/bots/bond/$botId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}

    return null;
  }

  Future<Map<String, dynamic>?> _fetchBondStatsFor(String botId) async {
    final authService = AuthService();
    final token = await authService.getToken();
    if (token == null || !mounted || _isDisposed) {
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/bots/bond/$botId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}

    return null;
  }

  Future<List<Map<String, dynamic>>?> _fetchAllGroupBondStats() async {
    if (_groupMembers.isEmpty) return [];
    final List<Map<String, dynamic>> updated = [];
    try {
      for (final member in _groupMembers) {
        final memberId =
            member['bot_id']?.toString() ?? member['id']?.toString();
        if (memberId == null) {
          updated.add(member);
          continue;
        }
        final data = await _fetchBondStatsFor(memberId);
        if (data != null) {
          updated.add({
            ...member,
            'bond_hearts': data['bond_hearts'] ?? member['bond_hearts'],
            'xp': data['xp'] ?? member['xp'],
            'xp_into_level': data['xp_into_level'] ?? member['xp_into_level'],
            'progress_percent':
                data['progress_percent'] ?? member['progress_percent'],
          });
        } else {
          updated.add(member);
        }
      }

      if (mounted && !_isDisposed) {
        _safeSetState(() {
          _groupMembers = List<Map<String, dynamic>>.from(updated);
        });
      }
      return updated;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showBondStats() async {
    if (_isGroup) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) {
          return FutureBuilder<List<Map<String, dynamic>>?>(
            future: _fetchAllGroupBondStats(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const GroupBondSkeleton();
              }
              return GroupBondStats(groupMembers: _groupMembers);
            },
          );
        },
      );
      return;
    }
    if (widget.isDesktopMode) {
      if (await Navigator.maybePop(context)) {}
      setState(() => _activeOverlay = 'bond');
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: _fetchBondStats(),
          builder: (context, snapshot) {
            final bondData = snapshot.data;
            return BondStatsSheet(
              bondData: bondData,
              bot: widget.bot,
              bondStatus: _bondStatus,
              bondRelationship: _bondRelationship,
            );
          },
        );
      },
    );
  }

  void _addSystemError(String timestamp, {int? statusCode, dynamic rawError}) {
    String errorMsg =
        'Error: Failed to get response from ${widget.provider}. please check your API Key, Your Provider, or your BYOM';

    if (statusCode == 503) {
      errorMsg = 'Server is under maintenance, try again later';
      rawError = null;
    } else if (statusCode == 429) {
      errorMsg = tr('error_rate_limit');
    } else if (statusCode == 400 || statusCode == 401) {
      errorMsg = tr('error_api_key');
    } else if (widget.provider == 'System') {
      errorMsg = tr('error_busy');
    }

    if (rawError != null) {
      errorMsg = _formatErrorPayload(statusCode, rawError);
    } else if (statusCode != null) {
      errorMsg = '[$statusCode] $errorMsg';
    }

    final errMsg = <String, dynamic>{
      'role': 'system',
      'content': errorMsg,
      'timestamp': timestamp,
    };

    _messages.add(errMsg);
    _allMessages.add(errMsg);
  }

  String _formatErrorPayload(int? statusCode, dynamic rawError) {
    if (rawError is! Map<String, dynamic>) {
      if (rawError != null && rawError.toString().trim().isNotEmpty) {
        String errStr = rawError.toString();
        if (errStr.trim().toLowerCase().startsWith('<!doctype html') ||
            errStr.toLowerCase().contains('<html')) {
          return '${statusCode != null ? '[$statusCode] ' : ''}Server returned an HTML error page. you can press the send message to resend it';
        }
        return '${statusCode != null ? '[$statusCode] ' : ''}$errStr';
      }
      return 'Unknown Error';
    }

    String? errType;
    String? errMessage;
    String? errCode;

    if (rawError.containsKey('message') && rawError['message'] is String) {
      errMessage = rawError['message'];
    }

    if (rawError.containsKey('detail') && rawError['detail'] is String) {
      errMessage ??= rawError['detail'];
    }

    if (rawError.containsKey('error') && rawError['error'] is String) {
      errMessage ??= rawError['error'];
    }

    if (rawError.containsKey('error') &&
        rawError['error'] is Map<String, dynamic>) {
      final eObj = rawError['error'] as Map<String, dynamic>;
      if (eObj.containsKey('message') && eObj['message'] is String) {
        errMessage ??= eObj['message'];
      }
      if (eObj.containsKey('type') && eObj['type'] is String) {
        errType ??= eObj['type'];
      }
      if (eObj.containsKey('code')) {
        errCode ??= eObj['code'].toString();
      }
    }

    if (rawError.containsKey('response') &&
        rawError['response'] is Map<String, dynamic>) {
      final resObj = rawError['response'] as Map<String, dynamic>;
      if (resObj.containsKey('error') &&
          resObj['error'] is Map<String, dynamic>) {
        final eObj = resObj['error'] as Map<String, dynamic>;
        if (eObj.containsKey('message') && eObj['message'] is String) {
          errMessage ??= eObj['message'];
        }
        if (eObj.containsKey('code')) {
          errCode ??= eObj['code'].toString();
        }
      }
    }

    if (rawError.containsKey('error_type') &&
        rawError['error_type'] is String) {
      errType ??= rawError['error_type'];
    }
    if (rawError.containsKey('type') &&
        rawError['type'] is String &&
        rawError['type'] != 'error') {
      errType ??= rawError['type'];
    }
    if (rawError.containsKey('code') && rawError['code'] is String) {
      errCode ??= rawError['code'];
    }
    if (rawError.containsKey('rc') && rawError['rc'] is String) {
      errCode ??= rawError['rc'];
    }

    if (errMessage != null) {
      String result = '';
      if (statusCode != null) result += '[$statusCode] ';
      if (errType != null) {
        result += '($errType) ';
      } else if (errCode != null) {
        result += '($errCode) ';
      }

      result += errMessage;
      return result;
    }

    try {
      final encoder = const JsonEncoder.withIndent('  ');
      return '${statusCode != null ? '[$statusCode]\\n' : ''}```json\\n${encoder.convert(rawError)}\\n```';
    } catch (_) {
      return '${statusCode != null ? '[$statusCode]\\n' : ''}$rawError';
    }
  }

  Future<void> _showStudentBio() async {
    if (widget.isDesktopMode) {
      if (await Navigator.maybePop(context)) {}
      setState(() => _activeOverlay = 'bio');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StudentBioSheet(
        bot: widget.bot,
        isGroup: _isGroup,
        groupMembers: _groupMembers,
        onAddMember: () {
          Navigator.pop(context);
          _handleAddMember();
        },
        onKickMember: (botId) {
          Navigator.pop(context);
          _handleKickMember(botId);
        },
      ),
    );
  }

  Future<void> _handleAddMember() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectContactScreen(
          excludeIds: _groupMembers.map((m) => m['bot_id']?.toString() ?? m['id']?.toString() ?? '').toSet(),
          onContactSelected: (newBot) async {
            Navigator.pop(context, newBot);
          },
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );

    if (result == null || !mounted) return;

    _safeSetState(() {
      _groupMembers.add(result);
    });
    await _localChatService.updateGroupMembers(widget.bot['id'], _groupMembers);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('group_add_done').replaceFirst('{name}', result['name'] ?? '')),
      ),
    );
  }

  Future<void> _handleKickMember(String botId) async {
    final member = _groupMembers.firstWhere(
      (m) => (m['bot_id']?.toString() ?? m['id']?.toString()) == botId,
      orElse: () => <String, dynamic>{},
    );
    final name = member['name']?.toString() ?? botId;

    if (_selectedBotId == botId) {
      _selectedBotId = null;
    }

    _safeSetState(() {
      _groupMembers.removeWhere(
        (m) => (m['bot_id']?.toString() ?? m['id']?.toString()) == botId,
      );
    });
    await _localChatService.updateGroupMembers(widget.bot['id'], _groupMembers);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('group_kick_done').replaceFirst('{name}', name)),
      ),
    );
  }

  Future<void> _exportChat(String format) async {
    if (_messages.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('chat_export_empty'))));
      return;
    }

    try {
      String content = '';
      if (format == 'json') {
        content = jsonEncode(_messages);
      } else {
        final sb = StringBuffer();
        sb.writeln('=== Chat dengan ${widget.bot['name']} ===');
        sb.writeln('Provider: ${widget.provider}');
        sb.writeln(
          'Diexport pada: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
        );
        sb.writeln('====================================\n');

        for (var msg in _messages) {
          final role = msg['role'] == 'user' ? 'Sensei' : widget.bot['name'];
          final time = msg['timestamp'] != null
              ? DateFormat('HH:mm').format(DateTime.parse(msg['timestamp']))
              : '';
          sb.writeln('[$time] $role:');
          sb.writeln('${msg['content']}\n');
        }
        content = sb.toString();
      }

      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final safeName = widget.bot['name'].toString().replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '_',
      );
      final fileName = 'HaloStory_Chat_${safeName}_$dateStr.$format';

      if (kIsWeb) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('chat_export_web_error'))));
        return;
      } else {
        final downloadDir = await _getDownloadDir();
        final file = File('${downloadDir.path}/$fileName');
        await file.writeAsString(content);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${tr('chat_export_success')}\n$fileName'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('chat_export_failed')} $e')),
        );
      }
    }
  }

  Future<void> _showEditGroupInfoDialog() async {
    if (!_isGroup) return;

    final nameController = TextEditingController(
      text: _groupName.isNotEmpty ? _groupName : widget.bot['name'] ?? '',
    );
    final bioController = TextEditingController(text: _groupBio);

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Group Info'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Group name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Group bio',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) return;

    final newName = nameController.text.trim();
    final newBio = bioController.text.trim();

    if (newName.isEmpty) {
      if (!mounted || _isDisposed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name cannot be empty.')),
      );
      return;
    }

    await _localChatService.updateGroupMetadata(
      widget.bot['id'].toString(),
      name: newName,
      bio: newBio,
    );

    if (!mounted || _isDisposed) return;

    _safeSetState(() {
      _groupName = newName;
      _groupBio = newBio;
      widget.bot['name'] = newName;
      widget.bot['description'] = newBio;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Group info updated.')));
  }

  Future<Directory> _getDownloadDir() async {
    Directory? baseDir;
    if (Platform.isAndroid) {
      baseDir = Directory('/storage/emulated/0/Download/HaloStory');
    } else {
      baseDir = await getDownloadsDirectory();
      if (baseDir != null) {
        baseDir = Directory('${baseDir.path}/HaloStory');
      }
    }

    if (baseDir != null && !await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    return baseDir ?? await getApplicationDocumentsDirectory();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        LogicalKeySet(LogicalKeyboardKey.f12): () => _toggleDebugOverlay(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: pageBackground(context),
            elevation: 0,
            automaticallyImplyLeading: !widget.isDesktopMode,
            leadingWidth: widget.isDesktopMode ? 16 : 40,
            title: GestureDetector(
              onTap: _showStudentBio,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: parseColor(widget.bot['color']),
                    backgroundImage: widget.bot['image_url'] != null
                        ? NetworkImage(widget.bot['image_url'])
                        : null,
                    child: widget.bot['image_url'] == null
                        ? Text(
                            widget.bot['name'][0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _isGroup
                                  ? (_groupName.isNotEmpty
                                        ? _groupName
                                        : widget.bot['name'])
                                  : widget.bot['name'],
                              style: TextStyle(
                                color: titleColor(context),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: _chatHeaderFont,
                              ),
                            ),
                            if (_isBirthday(widget.bot['birthday']))
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Text(
                                  '🎂',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: _showBondStats,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Color(0xFFE88FAA),
                            size: 40,
                          ),
                          const Icon(
                            Icons.favorite,
                            color: Color(0xFFF9C3D4),
                            size: 36,
                          ),
                          if (!_isGroup)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                '$_bondLevel',
                                style: bondCountHeaderStyle(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: subtitleColor(context)),
                onSelected: (value) async {
                  if (value == 'edit_group_info') {
                    await _showEditGroupInfoDialog();
                  } else if (value == 'export_txt') {
                    await _exportChat('txt');
                  } else if (value == 'export_json') {
                    await _exportChat('json');
                  } else if (value == 'toggle_italics') {
                    await _saveItalicsSetting(!_hideItalics);
                  } else if (value == 're_summary') {
                    _safeSetState(() => _summaries.clear());
                    await _localChatService.saveSummaries(
                      widget.bot['id'],
                      _summaries,
                    );

                    if (!context.mounted) return;

                    final realMessages = _allMessages
                        .where((m) => m['content'] != null && m['role'] != 'system')
                        .toList();
                    final totalReal = realMessages.length;

                    if (totalReal > 150) {
                      await _startForcedSummary(realMessages, totalReal);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr('chat_regenerating_summaries')),
                          ),
                        );
                      }
                    } else {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => Dialog(
                          backgroundColor: surfaceBackground(context),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  tr('chat_resummary_loading'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );

                      await _generateSummaries();

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(tr('chat_regenerating_summaries')),
                          ),
                        );
                      }
                    }
                  } else if (value == 'delete') {
                    await _localChatService.deleteChat(widget.bot['id']);
                    _safeSetState(() {
                      _messages = [];
                      _summaries.clear();
                    });
                  }
                },
                itemBuilder: (BuildContext context) {
                  final scheme = Theme.of(context).colorScheme;
                  return <PopupMenuEntry<String>>[
                    if (_isGroup)
                      PopupMenuItem<String>(
                        value: 'edit_group_info',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              color: scheme.onSurfaceVariant,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text('Edit Group Info'),
                          ],
                        ),
                      ),
                    PopupMenuItem<String>(
                      value: 'export_txt',
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            color: scheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text('Export as TXT'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'export_json',
                      child: Row(
                        children: [
                          Icon(
                            Icons.data_object_outlined,
                            color: scheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text('Export as JSON'),
                        ],
                      ),
                    ),
                    CheckedPopupMenuItem<String>(
                      value: 'toggle_italics',
                      checked: _hideItalics,
                      child: Row(
                        children: [
                          Icon(
                            Icons.format_italic,
                            color: scheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text('Hide Italics (Actions)'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 're_summary',
                      child: Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: scheme.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text('Re-Summary'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            color: scheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tr('chat_delete_confirm'),
                            style: TextStyle(color: scheme.error),
                          ),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              if (_showExplosion)
                Positioned.fill(
                  child: _BondExplosionEffect(
                    onFinished: () {
                      _safeSetState(() => _showExplosion = false);
                    },
                  ),
                ),
              Container(
                color: pageBackground(context),
                child: Column(
                  children: [
                    if (_showSafetyBar)
                      SafetyBar(
                        onClose: () => _safeSetState(() => _showSafetyBar = false),
                      ),
                    if (_isSummarizing && _summaryProgress >= 0.0)
                      LinearProgressIndicator(
                        value: _summaryProgress,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                        minHeight: 2,
                      ),
                    Expanded(
                      child: Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isUser = msg['role'] == 'user';
                              final isSystem = msg['role'] == 'system';

                              if (isSystem) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      msg['content'],
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              final timestamp = msg['timestamp'] != null
                                  ? DateTime.parse(msg['timestamp'])
                                  : null;

                              final content = msg['content']?.toString() ?? '';

                              final bubble = isUser
                                  ? UserBubble(
                                      content: content,
                                      timestamp: timestamp,
                                      status: msg['status']?.toString(),
                                    )
                                  : BotBubble(
                                      msg: msg,
                                      timestamp: timestamp,
                                      visibleParts: (msg['visible_parts'] as int?) ?? 0,
                                      isTypingNext: msg['is_typing_next'] == true,
                                      groupMembers: _groupMembers,
                                      bot: widget.bot,
                                    );

                              return GestureDetector(
                                onLongPress: () =>
                                    _showMessageOptions(index, content),
                                child: bubble,
                              );
                            },
                          ),
                          if (_showScrollButton)
                            Positioned(
                              bottom: 16,
                              right: 16,
                              child: FloatingActionButton(
                                mini: true,
                                elevation: 4,
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                onPressed: _scrollToBottom,
                                child: Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  size: 20,
                                ),
                              ),
                            ),
                          if (kDebugMode)
                            Positioned(
                              bottom: 72,
                              right: 16,
                              child: FloatingActionButton(
                                mini: true,
                                heroTag: "bond_simulator",
                                backgroundColor: Colors.orange.shade700,
                                onPressed: _showBondSimulator,
                                child: const Icon(
                                  Icons.bug_report,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (_isCharacterMenuOpen)
                            Positioned.fill(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _isCharacterMenuOpen ? 1.0 : 0.0,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => setState(
                                    () => _isCharacterMenuOpen = false,
                                  ),
                                  child: Container(color: Colors.transparent),
                                ),
                              ),
                            ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutBack,
                            left: 12,
                            bottom: _isCharacterMenuOpen ? 8 : -300,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _isCharacterMenuOpen ? 1.0 : 0.0,
                              child: CharacterMenu(
                                groupMembers: _groupMembers,
                                selectedBotId: _selectedBotId,
                                onSelect: (botId) {
                                  _saveSelectedBot(botId);
                                  _safeSetState(() => _isCharacterMenuOpen = false);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoading && _activeBotId != null)
                      TypingIndicator(
                        messages: _messages,
                        isLoading: _isLoading,
                        activeBotId: _activeBotId,
                        selectedBotId: _selectedBotId,
                        groupMembers: _groupMembers,
                        bot: widget.bot,
                      ),
                    if (_isSystemNoteOpen)
                      SystemNoteArea(
                        controller: _systemNoteController,
                        onClose: () => _safeSetState(() => _isSystemNoteOpen = false),
                        onChanged: _saveSystemNote,
                      ),
                    ChatInputArea(
                      controller: _messageController,
                      isGroup: _isGroup,
                      isTypingEffectActive: _isTypingEffectActive,
                      isCharacterMenuOpen: _isCharacterMenuOpen,
                      selectedBotId: _selectedBotId,
                      groupMembers: _groupMembers,
                      bot: widget.bot,
                      isSystemNoteOpen: _isSystemNoteOpen,
                      isLockedForSummary: _isLockedForSummary,
                      onSend: _sendMessage,
                      onToggleCharacterMenu: () {
                        _safeSetState(() {
                          _isCharacterMenuOpen = !_isCharacterMenuOpen;
                        });
                      },
                      onToggleSystemNote: () {
                        _safeSetState(() {
                          _isSystemNoteOpen = !_isSystemNoteOpen;
                        });
                      },
                    ),
                  ],
                ),
              ),
              if (_activeOverlay != null)
                DesktopOverlay(
                  overlayType: _activeOverlay!,
                  onClose: () => setState(() => _activeOverlay = null),
                  child: _activeOverlay == 'bio'
                      ? StudentBioSheet(bot: widget.bot, isDesktop: true)
                      : FutureBuilder<Map<String, dynamic>?>(
                          future: _fetchBondStats(),
                          builder: (context, snapshot) {
                            return BondStatsSheet(
                              bondData: snapshot.data,
                              bot: widget.bot,
                              bondStatus: _bondStatus,
                              bondRelationship: _bondRelationship,
                              isDesktop: true,
                            );
                          },
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageOptions(int index, String content) {
    final bool isLastMessage = index == _messages.length - 1;
    final String role = _messages[index]['role'] ?? '';
    final bool canRegenerate =
        isLastMessage && (role == 'assistant' || role == 'system');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MessageOptionsSheet(
        canRegenerate: canRegenerate,
        onRegenerate: _regenerateResponse,
        onRewind: () async {
          final trimmed = _messages.sublist(0, index + 1);
          _safeSetState(() {
            _messages = trimmed;
            _summaries.removeWhere(
              (key, value) => key >= trimmed.length,
            );
          });
          await _localChatService.saveChat(widget.bot['id'], _messages);
          await _localChatService.saveSummaries(
            widget.bot['id'],
            _summaries,
          );
          _scrollToBottom();
        },
        onCopy: () {
          Clipboard.setData(ClipboardData(text: content));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(tr('chat_copy_success')),
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onEdit: () => _showEditMessageDialog(index),
      ),
    );
  }

  void _showEditMessageDialog(int index) {
    final TextEditingController editController = TextEditingController(
      text: _messages[index]['content'],
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('chat_edit_message')),
        content: TextField(
          controller: editController,
          maxLines: 10,
          minLines: 1,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr('btn_skip')),
          ),
          ElevatedButton(
            onPressed: () async {
              _safeSetState(() {
                _messages[index]['content'] = editController.text;
              });
              await _localChatService.saveChat(widget.bot['id'], _messages);
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: Text(tr('settings_save_btn')),
          ),
        ],
      ),
    );
  }

  void _triggerBondExplosion() {
    _safeSetState(() {
      _showExplosion = true;
    });
  }
}

class _BondExplosionEffect extends StatefulWidget {
  final VoidCallback onFinished;
  const _BondExplosionEffect({required this.onFinished});

  @override
  State<_BondExplosionEffect> createState() => _BondExplosionEffectState();
}

class _BondExplosionEffectState extends State<_BondExplosionEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];
  final int _count = 50;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    final random = math.Random();
    for (int i = 0; i < _count; i++) {
      _particles.add(_Particle(
        x: random.nextDouble(),
        y: 1.0,
        speed: 0.3 + random.nextDouble() * 0.5,
        angle: (random.nextDouble() * 2 * math.pi),
        size: 8 + random.nextDouble() * 16,
        rotation: random.nextDouble() * 2 * math.pi,
        color: [
          Colors.pink,
          Colors.pinkAccent,
          Colors.red.shade300,
          Colors.purple.shade300,
          Colors.orange.shade300,
        ][random.nextInt(5)],
      ));
    }

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onFinished();
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ParticlePainter(
            particles: _particles,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

class _Particle {
  final double x;
  final double y;
  final double speed;
  final double angle;
  final double size;
  final double rotation;
  final Color color;

  _Particle({
    required this.x,
    required this.y,
    required this.speed,
    required this.angle,
    required this.size,
    required this.rotation,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ParticlePainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final dx = math.cos(p.angle) * p.speed * progress * size.width * 0.5;
      final dy = -p.speed * progress * size.height;
      final opacity = (1 - progress).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(p.x * size.width + dx, p.y * size.height + dy);
      canvas.rotate(p.rotation + progress * 4);
      final paint = Paint()..color = p.color.withValues(alpha: opacity);
      final heartSize = p.size * (1 - progress * 0.3);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: heartSize, height: heartSize),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SummaryProgressDialog extends StatelessWidget {
  final ValueNotifier<Map<String, int>> notifier;

  const _SummaryProgressDialog({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: notifier,
      builder: (context, progress, _) {
        final total = progress['total'] ?? 0;
        final done = progress['done'] ?? 0;
        final remaining = progress['remaining'] ?? 0;
        final progressValue = total > 0 ? done / total : 0.0;

        return Dialog(
          backgroundColor: surfaceBackground(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  tr('chat_summary_locking_title'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr('chat_summary_wait'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                  minHeight: 4,
                ),
                const SizedBox(height: 12),
                Text(
                  tr('chat_summary_progress')
                      .replaceFirst('{total}', total.toString())
                      .replaceFirst('{done}', done.toString())
                      .replaceFirst('{remaining}', remaining.toString()),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
