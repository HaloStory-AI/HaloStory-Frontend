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
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:intl/intl.dart';
import '../constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/rendering.dart';

import '../services/localization_service.dart';
import '../widgets/skeleton_loader.dart';

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
  bool _isDisposed = false;
  bool _showScrollButton = false;

  // Debug overlay state
  bool _showDebugOverlay = false;
  OverlayEntry? _debugOverlayEntry;
  final List<String> _debugLogs = [];
  final ScrollController _debugScrollController = ScrollController();

  final TextEditingController _systemNoteController = TextEditingController();
  bool _isSystemNoteOpen = false;
  bool _isCharacterMenuOpen = false;
  String? _activeOverlay; // 'bio' or 'bond'

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

  String _filterItalics(String text) {
    if (!_hideItalics) return text;
    // Remove text wrapped in single asterisks or underscores.
    // Uses non-greedy matches to avoid over-matching.
    String filtered = text
        .replaceAll(RegExp(r'\*(?!\*)[^*]+\*'), '')
        .replaceAll(RegExp(r'_(?!_)[^_]+_'), '');

    // Clean up empty lines or double spaces left behind
    return filtered.trim();
  }

  @override
  void dispose() {
    _isDisposed = true;
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
            color: _surfaceBackground(context),
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
                  color: _subtitleColor(context),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _surfaceAltBackground(context),
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
              color: _surfaceBackground(context),
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
                    color: _subtitleColor(context),
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
                    backgroundColor: _surfaceAltBackground(context),
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
        builder: (context) => Positioned(
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          child: Material(
            color: Colors.black87,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Debug Console',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _safeSetState(() {
                            _showDebugOverlay = false;
                          });
                          _debugOverlayEntry?.remove();
                          _debugOverlayEntry = null;
                        },
                        child: Icon(Icons.close, color: Colors.red, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: _debugScrollController,
                      itemCount: _debugLogs.length,
                      itemBuilder: (context, index) {
                        final log = _debugLogs[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            log,
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _safeSetState(() {
                              _debugLogs.clear();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Clear Logs'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _addDebugLog('Debug log test at ${DateTime.now()}');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Test Log'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
      _messages = history;
      _summaries = summaries;
    });
    _scrollToBottom();

    _generateSummaries();

    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _messageController.text = widget.initialMessage!;
      _sendMessage();
    }
  }

  Future<void> _generateSummaries() async {
    if (_isSummarizing) return;
    if (!mounted || _isDisposed) return;

    _addDebugLog('Starting summary generation for bot ${widget.bot['id']}');

    final int batchSize = 20;

    int totalBatchesToSummarize = 0;
    for (int i = 0; i <= _messages.length - batchSize; i += batchSize) {
      if (!_summaries.containsKey(i)) {
        totalBatchesToSummarize++;
      }
    }

    if (totalBatchesToSummarize == 0) return;

    _safeSetState(() {
      _isSummarizing = true;
      _summaryProgress = 0.0;
    });

    bool updated = false;
    int processedBatches = 0;

    for (int i = 0; i <= _messages.length - batchSize; i += batchSize) {
      if (!_summaries.containsKey(i)) {
        try {
          final List<Map<String, String>> batch = _messages
              .sublist(i, i + batchSize)
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

          if (result != null && result['summary'] != null) {
            _summaries[i] = result['summary'];
            updated = true;
          }
        } catch (e) {
          // Log failed batch if needed
        }

        processedBatches++;
        _safeSetState(() {
          _summaryProgress = processedBatches / totalBatchesToSummarize;
        });
      }
    }

    if (updated) {
      await _localChatService.saveSummaries(widget.bot['id'], _summaries);
    }

    _safeSetState(() {
      _isSummarizing = false;
      _summaryProgress = 0.0;
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
    _safeSetState(() {
      _messages.add({
        'role': 'user',
        'content': userMessage,
        'timestamp': timestamp,
      });
    });
    _scrollToBottom();

    _generateSummaries();
    await _getAIResponse();
  }

  Future<void> _regenerateResponse() async {
    if (_isLoading || _messages.isEmpty) return;

    if (_messages.last['role'] == 'assistant' ||
        _messages.last['role'] == 'system') {
      // capture original bot_id from the message if present
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

          // Check for full name or any part of the name (minimum 3 chars)
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
          botIdForRequest = _groupMembers[rIndex]['bot_id']?.toString() ??
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

    List<Map<String, String>> aiMessages;
    if (summaryPrompt != null && fullHistory.length > 4) {
      aiMessages = fullHistory.sublist(fullHistory.length - 4);
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

    // DEBUG LOGGING
    print('DEBUG: --- SENDING TO AI ---');
    print('DEBUG: Bot ID: $botIdForRequest');
    print('DEBUG: Language: $language');
    if (summaryPrompt != null) {
      print('DEBUG: Summary Prompt: $summaryPrompt');
    }
    print('DEBUG: Messages Payload: ${jsonEncode(aiMessages)}');
    print('DEBUG: ---------------------');

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

      bool shouldStartTyping = false;
      int partsLength = 0;

      _safeSetState(() {
        _isLoading = false;
        _activeBotId = null;
        final aiTimestamp = DateTime.now().toIso8601String();

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

            _messages.add({
              'role': 'assistant',
              'content': aiContent,
              'timestamp': aiTimestamp,
              'bot_id': botIdForRequest,
              'bot_name': _resolveBotName(botIdForRequest),
              'bot_avatar': _resolveBotAvatar(botIdForRequest),
              if (parts.length > 1) 'visible_parts': 1,
              if (parts.length > 1) 'is_typing_next': true,
            });

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
      });

      // Update bond state from response
      if (response != null) {
        _safeSetState(() {
          _bondStatus = response['bond_status'] ?? _bondStatus;
          _bondRelationship =
              response['relationship_label'] ?? _bondRelationship;
          _bondLevel = (response['bond_level'] as int?) ?? _bondLevel;
          _pendingBondEvent = response['bond_event'] as String?;
        });
      }

      if (shouldStartTyping) {
        _startTypingEffect(partsLength);
      }
    } catch (e) {
      if (!mounted || _isDisposed) return;
      _safeSetState(() {
        _isLoading = false;
        _activeBotId = null;
        _addSystemError(DateTime.now().toIso8601String());
      });
    }

    if (!_isTypingEffectActive) {
      await _localChatService.saveChat(widget.bot['id'], _messages);
      _generateSummaries();
    }
    _scrollToBottom();

    // Handle bond event from AI response (after UI has settled)
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

  // ───────────────────────────────────────────────────────────────
  // Bond Simulator (Debug Only)
  // ───────────────────────────────────────────────────────────────

  void _showBondSimulator() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _surfaceBackground(ctx),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Bond Simulator (God Mode)",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => _simulateBond(xp: 1000),
                    child: const Text("+1k XP"),
                  ),
                  ElevatedButton(
                    onPressed: () => _simulateBond(level: 25),
                    child: const Text("Lv 25"),
                  ),
                  ElevatedButton(
                    onPressed: () => _simulateBond(level: 100),
                    child: const Text("Lv 100"),
                  ),
                  ElevatedButton(
                    onPressed: () => _simulateBond(level: 150),
                    child: const Text("Lv 150"),
                  ),
                  ElevatedButton(
                    onPressed: () => _handleBondEvent('confession_triggered'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Trigger Confession"),
                  ),
                  ElevatedButton(
                    onPressed: () => _handleBondEvent('marriage_triggered'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purpleAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Trigger Marriage"),
                  ),
                  ElevatedButton(
                    onPressed: () => _simulateBond(reset: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text(
                      "Reset Bond",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                "Note: Changes on server will sync on next message or refresh",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _simulateBond({int? xp, int? level, bool reset = false}) async {
    final token = await AuthService().getToken();
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse(
          '${AppConstants.baseUrl}/bots/bond/${widget.bot['id']}/debug',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          if (xp != null) 'xp': xp,
          if (level != null) 'level': level,
          if (reset) 'reset': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _safeSetState(() {
          _bondStatus = data['bond_status'];
          _bondRelationship = data['relationship_label'];
          _bondLevel = data['bond_hearts'];
        });
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Simulasi Berhasil!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Simulasi Gagal: ${response.statusCode} - ${errorData['error'] ?? 'Unknown Error'}",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Simulator Error: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ───────────────────────────────────────────────────────────────
  // Bond Event Handling
  // ───────────────────────────────────────────────────────────────

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
        // Popups removed for Natural Flow. AI handles dialogue.
        break;

      case 'marriage_triggered':
        // Popups removed for Natural Flow. AI handles dialogue.
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

  Widget _groupBondSkeleton() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SkeletonWidget(width: 160, height: 20),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: 4,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const SkeletonWidget(
                        width: 40,
                        height: 40,
                        borderRadius: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonWidget(width: 120, height: 14),
                            SizedBox(height: 8),
                            SkeletonWidget(width: 80, height: 12),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const SkeletonWidget(width: 40, height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
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
                return _groupBondSkeleton();
              }
              return _buildGroupBondStats();
            },
          );
        },
      );
      return;
    }
    if (widget.isDesktopMode) {
      if (await Navigator.maybePop(context)) {
        // If there's a popup (like more menu), close it first
      }
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
            return _buildBondStatsContainer(bondData);
          },
        );
      },
    );
  }

  Widget _buildGroupBondStats() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surfaceBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Group Bond Levels',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: _groupMembers.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final member = _groupMembers[index];
                final hearts = member['bond_hearts'] ?? 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _parseColor(member['color']),
                    backgroundImage: member['image_url'] != null
                        ? NetworkImage(member['image_url'])
                        : (member['avatar'] != null
                              ? NetworkImage(member['avatar'])
                              : null),
                    child:
                        (member['image_url'] == null &&
                            member['avatar'] == null)
                        ? Text(
                            (member['name'] as String)[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  title: Text(
                    member['name'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _titleColor(context),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: Color(0xFFFBB6CE),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$hearts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBondStatsContainer(
    Map<String, dynamic>? bondData, {
    bool isDesktop = false,
  }) {
    final hearts = bondData?['bond_hearts'] ?? widget.bot['bond_hearts'] ?? 0;
    final xp = bondData?['xp'] ?? 0;
    final xpInto = bondData?['xp_into_level'] ?? 0;
    final xpPer = bondData?['xp_per_level'] ?? 5;
    final progress = bondData != null
        ? (bondData['progress_percent'] as num) / 100.0
        : 0.0;

    return Container(
      padding: EdgeInsets.fromLTRB(24, isDesktop ? 32 : 16, 24, 32),
      decoration: BoxDecoration(
        color: _surfaceBackground(context),
        borderRadius: isDesktop
            ? BorderRadius.circular(24)
            : BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isDesktop)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _parseColor(widget.bot['color']),
                backgroundImage: widget.bot['image_url'] != null
                    ? NetworkImage(widget.bot['image_url'])
                    : null,
                child: widget.bot['image_url'] == null
                    ? Text(
                        (widget.bot['name'] as String)[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.bot['name'],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _titleColor(context),
                    ),
                  ),
                  Text(
                    'Total XP: $xp',
                    style: TextStyle(
                      fontSize: 13,
                      color: _subtitleColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _relationshipColor(
                        _bondStatus,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _relationshipColor(
                          _bondStatus,
                        ).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _bondRelationship.isNotEmpty
                          ? _bondRelationship
                          : (bondData?['relationship_label'] ?? 'Orang Asing'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _relationshipColor(_bondStatus),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Color(0xFFFBB6CE),
                    size: 72,
                  ),
                  Text(
                    '$hearts',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bond Level',
                    style: TextStyle(
                      fontSize: 13,
                      color: _subtitleColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Lv. $hearts',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progress to Lv. ${hearts + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _subtitleColor(context),
                    ),
                  ),
                  Text(
                    '$xpInto / $xpPer XP',
                    style: TextStyle(
                      fontSize: 12,
                      color: _subtitleColor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: Colors.pink.shade50,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFB6F9D),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addSystemError(String timestamp, {int? statusCode, dynamic rawError}) {
    String errorMsg = 'Error: Failed to get response from ${widget.provider}.';

    if (statusCode == 503) {
      errorMsg = 'Server is under maintenance, try again later';
      rawError = null; // Skip raw payload formatting
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

    _messages.add({
      'role': 'system',
      'content': errorMsg,
      'timestamp': timestamp,
    });
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
      if (await Navigator.maybePop(context)) {
        // If there's a popup (like more menu), close it first
      }
      setState(() => _activeOverlay = 'bio');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildStudentBioContainer(),
    );
  }

  Widget _buildStudentBioContainer({bool isDesktop = false}) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: _surfaceBackground(context),
        borderRadius: isDesktop
            ? BorderRadius.circular(24)
            : BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          if (!isDesktop)
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: _parseColor(widget.bot['color']),
                    backgroundImage: widget.bot['image_url'] != null
                        ? NetworkImage(widget.bot['image_url'])
                        : null,
                    child: widget.bot['image_url'] == null
                        ? Text(
                            widget.bot['name'][0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.bot['name'],
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _titleColor(context),
                    ),
                  ),
                  if (_isBirthday(widget.bot['birthday']))
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        '🎂 Birthday Today!',
                        style: TextStyle(
                          color: Colors.pinkAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    widget.bot['description'] ?? tr('bio_no_description'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: _subtitleColor(context),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tr('personality_title_label'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Builder(
                      builder: (context) {
                        final pData = widget.bot['personality'] ?? '';
                        if (pData.trim().isEmpty) {
                          return Text(
                            tr('bio_no_personality'),
                            style: TextStyle(
                              fontSize: 15,
                              color: _subtitleColor(context),
                            ),
                          );
                        }

                        Map<String, String> parseBioAttributes(
                          String personality,
                        ) {
                          Map<String, String> result = {
                            'Nickname': '*Unknown*',
                            'Age': '*Unknown*',
                            'Nationality': '*Unknown*',
                            'Height': '*Unknown*',
                            'Weight': '*Unknown*',
                            'Like': '*Unknown*',
                            'Dislike': '*Unknown*',
                          };

                          String? findMatch(String pattern) {
                            final regExp = RegExp(
                              pattern,
                              caseSensitive: false,
                              multiLine: true,
                            );
                            final match = regExp.firstMatch(personality);
                            if (match != null && match.groupCount >= 1) {
                              String val = match.group(1)!.trim();
                              val = val
                                  .replaceAll(RegExp('^["\'*]+|["\'*]+\$'), '')
                                  .trim();
                              if (val.endsWith(',')) {
                                val = val.substring(0, val.length - 1).trim();
                              }
                              return val;
                            }
                            return null;
                          }

                          result['Nickname'] =
                              findMatch(
                                r'(?:Nickname|Alias(?:es)?)\s*[:\-]\s*(.+)$',
                              ) ??
                              '*Unknown*';
                          result['Age'] =
                              findMatch(r'Age\s*[:\-]\s*(.+)$') ?? '*Unknown*';
                          result['Nationality'] =
                              findMatch(
                                r'(?:Nationality|Country)\s*[:\-]\s*(.+)$',
                              ) ??
                              '*Unknown*';
                          result['Height'] =
                              findMatch(r'Height\s*[:\-]\s*(.+)$') ??
                              '*Unknown*';
                          result['Weight'] =
                              findMatch(r'Weight\s*[:\-]\s*(.+)$') ??
                              '*Unknown*';
                          result['Like'] =
                              findMatch(r'Like(?:s)?\s*[:\-]\s*(.+)$') ??
                              '*Unknown*';
                          result['Dislike'] =
                              findMatch(r'Dislike(?:s)?\s*[:\-]\s*(.+)$') ??
                              '*Unknown*';

                          return result;
                        }

                        final attrs = parseBioAttributes(pData);

                        Widget buildBioRow(String label, String value) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _subtitleColor(context),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    value,
                                    style: TextStyle(
                                      color: _titleColor(context),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: [
                            buildBioRow('Nickname', attrs['Nickname']!),
                            buildBioRow('Age', attrs['Age']!),
                            buildBioRow('Nationality', attrs['Nationality']!),
                            buildBioRow('Height', attrs['Height']!),
                            buildBioRow('Weight', attrs['Weight']!),
                            buildBioRow('Like', attrs['Like']!),
                            buildBioRow('Dislike', attrs['Dislike']!),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: _surfaceBackground(ctx),
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
                  color: Theme.of(ctx).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (canRegenerate) ...[
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      Icons.refresh_rounded,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  title: const Text(
                    'Regenerate Response',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Retry getting a new answer from the AI',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _regenerateResponse();
                  },
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.secondaryContainer,
                  child: Icon(
                    Icons.fast_rewind_rounded,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                title: Text(
                  tr('chat_rewind_title'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  tr('chat_rewind_subtitle'),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
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
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    Icons.copy_rounded,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  tr('chat_copy_text'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr('chat_copy_success')),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.tertiaryContainer,
                  child: Icon(
                    Icons.edit_rounded,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                title: Text(
                  tr('chat_edit_message'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditMessageDialog(index);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
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
            backgroundColor: _pageBackground(context),
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
                    backgroundColor: _parseColor(widget.bot['color']),
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
                                color: _titleColor(context),
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
                                style: _bondCountHeaderStyle(context),
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
                icon: Icon(Icons.more_vert, color: _subtitleColor(context)),
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

                    // Show persistent loading popup
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => Dialog(
                        backgroundColor: _surfaceBackground(context),
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
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );

                    await _generateSummaries();

                    if (mounted) {
                      Navigator.pop(context); // Close loading dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Re-generating summaries...'),
                        ),
                      );
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
                color: _pageBackground(context),
                child: Column(
                  children: [
                    if (_showSafetyBar) _buildSafetyBar(),
                    if (_isSummarizing && _summaryProgress >= 0.0)
                      LinearProgressIndicator(
                        value: _summaryProgress,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainer,
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
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
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
                                  ? _buildUserBubble(content, timestamp, index)
                                  : _buildBotBubble(
                                      msg,
                                      timestamp,
                                      index,
                                      visibleParts:
                                          msg['visible_parts'] as int?,
                                      isTypingNext:
                                          msg['is_typing_next'] == true,
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
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary,
                                onPressed: _scrollToBottom,
                                child: Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
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
                                  onTap: () => setState(() => _isCharacterMenuOpen = false),
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
                              child: _buildCompactCharacterMenu(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoading) _buildTypingIndicator(),
                    _buildSystemNoteArea(),
                    _buildInputArea(),
                  ],
                ),
              ),
              if (_activeOverlay != null) _buildDesktopOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopOverlay() {
    final isBio = _activeOverlay == 'bio';

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.4),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450, maxHeight: 650),
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _surfaceBackground(context),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  if (isBio) _buildBioContent() else _buildBondContent(),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      onPressed: () => setState(() => _activeOverlay = null),
                      icon: Icon(Icons.close, color: _subtitleColor(context)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBioContent() {
    return _buildStudentBioContainer(isDesktop: true);
  }

  Widget _buildBondContent() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchBondStats(),
      builder: (context, snapshot) {
        final bondData = snapshot.data;
        return _buildBondStatsContainer(bondData, isDesktop: true);
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

  bool _isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _pageBackground(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  Color _surfaceBackground(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  Color _surfaceAltBackground(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  Color _titleColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  Color _subtitleColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  Color _relationshipColor(String status) {
    return switch (status) {
      'enemy' => Colors.red.shade400,
      'married' => Colors.purple.shade400,
      'lover' => const Color(0xFFFB6F9D),
      'rejected' => Colors.grey.shade500,
      'stuck' => Colors.orange.shade400,
      _ => Colors.blue.shade400,
    };
  }

  TextStyle _bondCountHeaderStyle(BuildContext context) {
    final isDark = _isDarkMode(context);
    final colorScheme = Theme.of(context).colorScheme;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.45)
        : Colors.white;

    return TextStyle(
      color: colorScheme.primary,
      fontWeight: FontWeight.w800,
      fontSize: 12,
      shadows: [
        Shadow(color: shadowColor, offset: const Offset(1, 0)),
        Shadow(color: shadowColor, offset: const Offset(-1, 0)),
        Shadow(color: shadowColor, offset: const Offset(0, 1)),
        Shadow(color: shadowColor, offset: const Offset(0, -1)),
      ],
    );
  }

  Color _botBubbleBackground(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;

  Color _fieldBorderColor(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  Color _hintColor(BuildContext context) {
    final color = Theme.of(context).inputDecorationTheme.hintStyle?.color;
    return color ?? Theme.of(context).colorScheme.onSurfaceVariant;
  }

  String _formatMessageTime(DateTime? dt) {
    if (dt == null) return "";
    return '${DateFormat('MMMM d').format(dt)} at ${DateFormat('h:mm a').format(dt)}';
  }

  String? _resolveBotName(String? botId) {
    if (botId == null) return null;
    try {
      final member = _groupMembers.firstWhere(
        (m) => (m['bot_id']?.toString() ?? m['id']?.toString()) == botId,
        orElse: () => <String, dynamic>{},
      );
      if (member.isNotEmpty && member['name'] != null)
        return member['name'] as String;
    } catch (_) {}
    // fallback to widget.bot name for single chats or unknown ids
    return widget.bot['name'] as String?;
  }

  String? _resolveBotAvatar(String? botId) {
    if (botId == null) return null;
    try {
      final member = _groupMembers.firstWhere(
        (m) => (m['bot_id']?.toString() ?? m['id']?.toString()) == botId,
        orElse: () => <String, dynamic>{},
      );
      if (member.isNotEmpty) {
        return member['image_url'] ?? member['avatar'];
      }
    } catch (_) {}
    return widget.bot['image_url'] as String?;
  }

  Color _resolveBotColor(String? botId) {
    if (botId == null) return _parseColor(widget.bot['color']);
    try {
      final member = _groupMembers.firstWhere(
        (m) => (m['bot_id']?.toString() ?? m['id']?.toString()) == botId,
        orElse: () => <String, dynamic>{},
      );
      if (member.isNotEmpty && member['color'] != null)
        return _parseColor(member['color']);
    } catch (_) {}
    return _parseColor(widget.bot['color']);
  }

  Widget _buildTypingIndicator() {
    // Prefer to show the author of the message that's currently typing
    Map<String, dynamic>? typingMsg;
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m['role'] == 'assistant' && m['is_typing_next'] == true) {
        typingMsg = m;
        break;
      }
    }

    final effectiveBotId = typingMsg != null
        ? typingMsg['bot_id']?.toString()
        : (_isLoading ? _activeBotId : _selectedBotId);

    final displayName = _resolveBotName(effectiveBotId) ?? widget.bot['name'];
    final avatarUrl = _resolveBotAvatar(effectiveBotId);
    final bgColor = _resolveBotColor(effectiveBotId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: bgColor,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    displayName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _titleColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _botBubbleBackground(context),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DotAnim(delay: 0),
                    SizedBox(width: 4),
                    _DotAnim(delay: 0.2),
                    SizedBox(width: 4),
                    _DotAnim(delay: 0.4),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(String content, DateTime? timestamp, int index) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timestamp != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: Text(
                _formatMessageTime(timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(0),
                ),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MarkdownBody(
                      data: _filterItalics(content),
                      selectable: false,
                      extensionSet: md.ExtensionSet(
                        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                        <md.InlineSyntax>[
                          md.EmojiSyntax(),
                          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                        ],
                      ),
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 14,
                        ),
                        strong: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        em: TextStyle(
                          color: colorScheme.onPrimary.withValues(alpha: 0.86),
                          fontStyle: FontStyle.italic,
                        ),
                        listBullet: TextStyle(color: colorScheme.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotBubble(
    Map<String, dynamic> msg,
    DateTime? timestamp,
    int index, {
    int? visibleParts,
    bool isTypingNext = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = msg['content']?.toString() ?? '';
    final parts = content
        .split('\n\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return const SizedBox.shrink();

    final partsToRender = visibleParts != null
        ? parts.take(visibleParts).toList()
        : parts;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _resolveBotColor(msg['bot_id']),
            backgroundImage: _resolveBotAvatar(msg['bot_id']) != null
                ? NetworkImage(_resolveBotAvatar(msg['bot_id'])!)
                : null,
            child: _resolveBotAvatar(msg['bot_id']) == null
                ? Text(
                    (_resolveBotName(msg['bot_id']) ?? widget.bot['name'])[0]
                        .toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _resolveBotName(msg['bot_id']) ?? widget.bot['name'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _titleColor(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (timestamp != null)
                      Text(
                        _formatMessageTime(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ...partsToRender.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String part = entry.value;
                  bool isFirst = idx == 0;

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: idx == partsToRender.length - 1 ? 0 : 4,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _botBubbleBackground(context),
                        borderRadius: BorderRadius.only(
                          topLeft: isFirst
                              ? const Radius.circular(2)
                              : const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: const Radius.circular(12),
                          bottomRight: const Radius.circular(12),
                        ),
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.65,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarkdownBody(
                            data: _filterItalics(part),
                            selectable: false,
                            extensionSet: md.ExtensionSet(
                              md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                              <md.InlineSyntax>[
                                md.EmojiSyntax(),
                                ...md
                                    .ExtensionSet
                                    .gitHubFlavored
                                    .inlineSyntaxes,
                              ],
                            ),
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 14,
                                height: 1.4,
                              ),
                              strong: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                              em: TextStyle(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.86,
                                ),
                                fontStyle: FontStyle.italic,
                              ),
                              code: TextStyle(
                                color: colorScheme.primary,
                                backgroundColor: colorScheme.surfaceContainer,
                                fontSize: 14,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              listBullet: TextStyle(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (isTypingNext)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _botBubbleBackground(context),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _DotAnim(delay: 0),
                          SizedBox(width: 4),
                          _DotAnim(delay: 0.2),
                          SizedBox(width: 4),
                          _DotAnim(delay: 0.4),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemNoteArea() {
    if (!_isSystemNoteOpen) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: _surfaceBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _fieldBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  tr('chat_system_note'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _safeSetState(() {
                      _isSystemNoteOpen = false;
                    });
                  },
                  child: Icon(
                    Icons.close,
                    color: _subtitleColor(context),
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          TextField(
            controller: _systemNoteController,
            maxLines: 3,
            minLines: 1,
            style: TextStyle(color: _titleColor(context), fontSize: 13),
            onChanged: (_) => _saveSystemNote(),
            decoration: InputDecoration(
              hintText: tr('chat_system_note_hint'),
              hintStyle: TextStyle(color: _hintColor(context), fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftInputIcon() {
    if (_isGroup && _selectedBotId == 'random') {
      return CircleAvatar(
        radius: 19,
        backgroundColor: Colors.transparent,
        child: Icon(Icons.shuffle, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 28),
      );
    }

    String? avatarUrl;
    String initial = '?';
    Color bgColor = Colors.blueGrey;

    if (_isGroup && _selectedBotId != null) {
      final member = _groupMembers.firstWhere(
        (m) =>
            (m['bot_id']?.toString() ?? m['id']?.toString()) == _selectedBotId,
        orElse: () => <String, dynamic>{},
      );
      if (member.isNotEmpty) {
        avatarUrl = member['image_url'] ?? member['avatar'];
        initial = (member['name'] ?? '?')[0].toUpperCase();
        bgColor = _parseColor(member['color']);
      }
    } else {
      avatarUrl = widget.bot['image_url'];
      initial = (widget.bot['name'] ?? '?')[0].toUpperCase();
      bgColor = _parseColor(widget.bot['color']);
    }

    return CircleAvatar(
      radius: 17,
      backgroundColor: bgColor,
      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
      child: avatarUrl == null
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Widget _buildCompactCharacterMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: _surfaceBackground(context),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._groupMembers.map((member) {
            final memberId =
                member['bot_id']?.toString() ?? member['id']?.toString();
            final isSelected = _selectedBotId == memberId;
            final color = _parseColor(member['color']);

            return GestureDetector(
              onTap: () {
                _saveSelectedBot(memberId!);
                _safeSetState(() => _isCharacterMenuOpen = false);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: color,
                  backgroundImage: member['image_url'] != null
                      ? NetworkImage(member['image_url'])
                      : (member['avatar'] != null
                          ? NetworkImage(member['avatar'])
                          : null),
                  child: (member['image_url'] == null && member['avatar'] == null)
                      ? Text(
                          (member['name'] as String)[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
            );
          }),
          GestureDetector(
            onTap: () {
              _saveSelectedBot('random');
              _safeSetState(() => _isCharacterMenuOpen = false);
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selectedBotId == 'random' ? Colors.orange : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: _selectedBotId == 'random' ? Colors.orange.withValues(alpha: 0.1) : Colors.transparent,
                child: Icon(Icons.shuffle, size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemNoteIconButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: () => _safeSetState(
        () => _isSystemNoteOpen = !_isSystemNoteOpen,
      ),
      icon: Icon(
        _isSystemNoteOpen
            ? Icons.sticky_note_2
            : Icons.sticky_note_2_outlined,
        color: _isSystemNoteOpen
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      iconSize: 22,
      constraints: const BoxConstraints(
        minWidth: 34,
        minHeight: 34,
      ),
      padding: const EdgeInsets.all(4),
    );
  }

  Widget _buildInputArea() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          decoration: BoxDecoration(color: colorScheme.surfaceContainer),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_isGroup) ...[
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: IconButton(
                          onPressed: () {
                            _safeSetState(() {
                              _isCharacterMenuOpen = !_isCharacterMenuOpen;
                            });
                          },
                          icon: _buildLeftInputIcon(),
                          iconSize: 34,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 34,
                            minHeight: 34,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ] else ...[
                      _buildSystemNoteIconButton(),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: colorScheme.surfaceContainerHighest,
                          hintText: _isGroup
                              ? 'Chatting with ${_selectedBotId == 'random' ? 'someone' : _groupMembers.firstWhere((m) => (m['bot_id']?.toString() ?? m['id']?.toString()) == _selectedBotId, orElse: () => {'name': widget.bot['name']})['name']}'
                              : '${tr('tab_chat')} ${widget.bot['name']}',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: const BorderSide(color: Colors.transparent),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: const BorderSide(color: Colors.transparent),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: const BorderSide(color: Colors.transparent),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) {
                          if (!_isTypingEffectActive) _sendMessage();
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (_isGroup) ...[
                      _buildSystemNoteIconButton(),
                    ],
                    GestureDetector(
                      onTap: _isTypingEffectActive ? null : _sendMessage,
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.send,
                          color: _isTypingEffectActive
                              ? colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                              : colorScheme.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  tr('chat_fictional_disclaimer'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: _subtitleColor(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
              if (mounted) {
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

  Widget _buildSafetyBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.redAccent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "We care about your safety.",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                    fontSize: 14,
                  ),
                ),
                Text(
                  "If you are going through a difficult time, please know that you are not alone.",
                  style: TextStyle(
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () =>
                      launchUrl(Uri.parse('https://findahelpline.com/')),
                  child: const Text(
                    "Find a helpline →",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
            onPressed: () {
              _safeSetState(() {
                _showSafetyBar = false;
              });
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Visual Effect: Bond Explosion (Particle Hearts)
// ─────────────────────────────────────────────────────────────────────────────
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
      _particles.add(_Particle(random));
    }

    _controller.addListener(() {
      if (mounted) setState(() {});
    });

    _controller.forward().then((_) => widget.onFinished());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _ParticlePainter(_particles, _controller.value),
        child: Container(),
      ),
    );
  }
}

class _Particle {
  late double x, y;
  late double vx, vy;
  late double size;
  late Color color;

  _Particle(math.Random rand) {
    x = 0.5;
    y = 0.4; // Explode from slightly above center (near avatar area)
    final angle = rand.nextDouble() * 2 * math.pi;
    final speed = 0.05 + rand.nextDouble() * 0.15;
    vx = math.cos(angle) * speed;
    vy = math.sin(angle) * speed;
    size = 12.0 + rand.nextDouble() * 20.0;
    color = rand.nextBool() ? Colors.pinkAccent : Colors.redAccent;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  _ParticlePainter(this.particles, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      final t = progress;
      final dx = size.width * (p.x + p.vx * t);
      final dy = size.height * (p.y + p.vy * t - 0.15 * t * t);

      final fade = (1.0 - t).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: fade);

      final heartSize = p.size * (0.5 + t);
      _drawHeart(canvas, Offset(dx, dy), heartSize, paint);
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    final width = size;
    final height = size;

    path.moveTo(center.dx, center.dy + height * 0.35);
    path.cubicTo(
      center.dx + width * 0.1,
      center.dy,
      center.dx + width * 0.5,
      center.dy,
      center.dx + width * 0.5,
      center.dy + height * 0.35,
    );
    path.cubicTo(
      center.dx + width * 0.5,
      center.dy + height * 0.6,
      center.dx + width * 0.25,
      center.dy + height * 0.85,
      center.dx,
      center.dy + height,
    );
    path.cubicTo(
      center.dx - width * 0.25,
      center.dy + height * 0.85,
      center.dx - width * 0.5,
      center.dy + height * 0.6,
      center.dx - width * 0.5,
      center.dy + height * 0.35,
    );
    path.cubicTo(
      center.dx - width * 0.5,
      center.dy,
      center.dx - width * 0.1,
      center.dy,
      center.dx,
      center.dy + height * 0.35,
    );
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DotAnim extends StatefulWidget {
  final double delay;
  const _DotAnim({required this.delay});

  @override
  State<_DotAnim> createState() => _DotAnimState();
}

class _DotAnimState extends State<_DotAnim>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
