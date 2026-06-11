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
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:intl/intl.dart';
import '../constants.dart';

import '../services/localization_service.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/chat/dot_animation.dart';
import '../widgets/chat/bond_explosion_effect.dart';
import '../widgets/chat/safety_bar.dart';
import '../widgets/chat/delete_bottom_sheet.dart';
import '../widgets/chat/message_options_sheet.dart';
import '../utils/chat_helpers.dart';
import 'student_bio_screen.dart';

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
  final VoidCallback? onChatDeleted;

  const ChatDetailScreen({
    super.key,
    required this.bot,
    required this.provider,
    this.initialMessage,
    this.isDesktopMode = false,
    this.onChatDeleted,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> with ChatHelpers {
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
  final ValueNotifier<String> _summaryProgressText = ValueNotifier<String>('');
  bool _isTypingEffectActive = false;
  bool _isDisposed = false;
  bool _showScrollButton = false;
  bool _isPollingActive = false;

  // Debug overlay state
  bool _showDebugOverlay = false;
  OverlayEntry? _debugOverlayEntry;
  final List<String> _debugLogs = [];
  final ScrollController _debugScrollController = ScrollController();

  final TextEditingController _systemNoteController = TextEditingController();
  bool _isSystemNoteOpen = false;
  bool _isCharacterMenuOpen = false;

  // Bond state
  String _bondStatus = 'normal';
  String _bondRelationship = 'Orang Asing';
  late int _bondLevel;
  String? _pendingBondEvent;

  static const String _chatHeaderFont = 'Roboto';
  bool _showExplosion = false;
  bool _showSafetyBar = false;

  bool _isGroup = false;
  bool _groupInfoChanged = false;
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
    _isPollingActive = false;
    _debugOverlayEntry?.remove();
    _debugScrollController.dispose();
    _scrollController.removeListener(_scrollListener);
    _messageController.dispose();
    _scrollController.dispose();
    _systemNoteController.dispose();
    _messages.removeWhere((m) => m['isTempSummary'] == true);
    unawaited(_localChatService.saveChat(widget.bot['id'], _messages));
    unawaited(_localChatService.saveSummaries(widget.bot['id'], _summaries));
    _summaryProgressText.dispose();
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
    _safeSetState(() => _isLoading = true);
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
      _isLoading = false;
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
      _messages.add({
        'role': 'assistant',
        'content': tr('chat_compressing_memory'),
        'status': 'processing',
        'isTempSummary': true,
      });
    });
    _scrollToBottom();

    bool updated = false;
    int processedBatches = 0;

    for (int i = 0; i <= realMessages.length - batchSize; i += batchSize) {
      if (!_summaries.containsKey(i)) {
        try {
          final List<Map<String, String>> batch = realMessages
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

          if (result != null &&
              result['status'] == 'queued' &&
              result['uuid'] != null) {
            String uuid = result['uuid'];
            bool summaryCompleted = false;
            int timeoutChecks = 60; // Max 2 minutes

            while (mounted &&
                !_isDisposed &&
                !summaryCompleted &&
                timeoutChecks > 0) {
              await Future.delayed(const Duration(seconds: 1));
              final statusCheck = await _aiService.checkChatStatus(uuid);
              if (statusCheck != null) {
                if (statusCheck['status'] == 'queued' ||
                    statusCheck['status'] == 'processing') {
                  // Masih diproses, teruskan polling
                } else if (statusCheck['status'] == 'not_found' ||
                    statusCheck['status'] == 'failed' ||
                    statusCheck['error'] != null) {
                  // Gagal atau tidak ditemukan
                  summaryCompleted = true;
                } else {
                  // Berhasil! Backend menghapus kunci Redis dan langsung mengembalikan payload response
                  // Karena ProcessAiChatJob mengembalikan ['summary' => 'teks...']
                  final summaryText =
                      statusCheck['summary'] ??
                      statusCheck['response']?['summary'];
                  if (summaryText != null) {
                    _summaries[i] = summaryText;
                    updated = true;
                  }
                  summaryCompleted = true;
                }
              }
              timeoutChecks--;
            }
          } else if (result != null && result['summary'] != null) {
            _summaries[i] = result['summary'];
            updated = true;
          }
        } catch (e) {
          // Log failed batch if needed
        }

        processedBatches++;
        _safeSetState(() {
          _summaryProgress = processedBatches / totalBatchesToSummarize;
          if (_messages.isNotEmpty && _messages.last['isTempSummary'] == true) {
            _messages.last['content'] =
                '${tr('chat_compressing_memory')} ($processedBatches/$totalBatchesToSummarize)';
          }
        });
        _summaryProgressText.value =
            '$processedBatches/$totalBatchesToSummarize';
        await _localChatService.saveSummaries(
            widget.bot['id'], _summaries);
      }
    }

    if (updated) {
      await _localChatService.saveSummaries(widget.bot['id'], _summaries);
    }

    _safeSetState(() {
      _messages.removeWhere((m) => m['isTempSummary'] == true);
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
    if (_isLoading || _isTypingEffectActive || _isSummarizing) return;

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
        'status': 'sending',
        'uuid': null,
      });
    });
    _scrollToBottom();

    await _generateSummaries();
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

    final bool realtimeDateTime = prefs.getBool('realtime_date_time_enabled') ?? false;
    if (realtimeDateTime) {
      final timeTag = DateFormat("'[this message sent at 'dd/MM/yyyy HH:mm:ss']'").format(DateTime.now());
      final List<Map<String, String>> injected = [];
      for (final msg in aiMessages) {
        injected.add(msg);
        if (msg['role'] == 'user' && msg['content'] != '[Continue]') {
          injected.add({'role': 'user', 'content': timeTag});
        }
      }
      aiMessages = injected;
    }

    // DEBUG LOGGING
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

      final aiTimestamp = DateTime.now().toIso8601String();

      if (response != null && response['status'] == 'queued') {
        _safeSetState(() {
          if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
            _messages.last['status'] = 'sent';
            _messages.last['uuid'] = response['uuid'];
          }
        });
        _startPolling(response['uuid'], botIdForRequest, aiTimestamp);
        return;
      }

      await _handleAIResponseData(response, botIdForRequest, aiTimestamp);
    } catch (e) {
      if (!mounted || _isDisposed) return;
      _safeSetState(() {
        _isLoading = false;
        _activeBotId = null;
        _addSystemError(DateTime.now().toIso8601String());
      });
    }
  }

  Future<void> _startPolling(
    String uuid,
    String? botIdForRequest,
    String aiTimestamp,
  ) async {
    _isPollingActive = false;
    _isPollingActive = true;
    await _pollLoop(uuid, botIdForRequest, aiTimestamp);
  }

  Future<void> _pollLoop(
    String uuid,
    String? botIdForRequest,
    String aiTimestamp,
  ) async {
    while (_isPollingActive && mounted && !_isDisposed) {
      final response = await _aiService.checkChatStatus(uuid);

      if (!_isPollingActive || !mounted || _isDisposed) return;

      if (response == null || response['status'] == 'not_found') {
        _isPollingActive = false;
        if (mounted && !_isDisposed) {
          _safeSetState(() {
            _isLoading = false;
            _activeBotId = null;
            _addSystemError(aiTimestamp);
          });
        }
        return;
      }

      if (response['status'] == 'processing') {
        _safeSetState(() {
          if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
            _messages.last['status'] = 'processing';
          }
        });
        await Future.delayed(const Duration(seconds: 1));
        continue;
      }

      if (response['status'] == 'completed' ||
          response['choices'] != null ||
          response['error'] != null) {
        _isPollingActive = false;
        if (mounted && !_isDisposed) {
          _safeSetState(() {
            if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
              _messages.last['status'] = 'completed';
            }
          });
          await _handleAIResponseData(response, botIdForRequest, aiTimestamp);
        }
        return;
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _handleAIResponseData(
    Map<String, dynamic>? response,
    String? botIdForRequest,
    String aiTimestamp,
  ) async {
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
            ? response['raw_error'] ?? response
            : null;
        _addSystemError(
          aiTimestamp,
          statusCode: statusCode,
          rawError: rawError,
        );
      }

      // Update bond state from response
      if (response != null) {
        _bondStatus = response['bond_status'] ?? _bondStatus;
        _bondRelationship = response['relationship_label'] ?? _bondRelationship;
        _bondLevel = (response['bond_level'] as int?) ?? _bondLevel;
        _pendingBondEvent = response['bond_event'] as String?;
      }
    });

    if (shouldStartTyping) {
      await _startTypingEffect(partsLength);
    } else {
      await _localChatService.saveChat(widget.bot['id'], _messages);
      _generateSummaries();
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

    await _localChatService.saveChat(widget.bot['id'], _messages);

    for (int i = 1; i < totalParts; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      _scrollToBottom();

      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted || _isDisposed) {
        await _localChatService.saveChat(widget.bot['id'], _messages);
        return;
      }

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
            color: surfaceBackground(ctx),
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
          'xp': ?xp,
          'level': ?level,
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


  void _addSystemError(String timestamp, {int? statusCode, dynamic rawError}) {
    String errorMsg =
        'Error: Failed to get response from ${widget.provider}. please check your API Key, Your Provider, or your BYOM';

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
      if (rawError != null) 'raw_error': rawError,
    });
  }

  void _copyErrorLog(Map<String, dynamic> msg) async {
    final errorText = msg['content']?.toString() ?? '';
    final rawError = msg['raw_error'];
    final prefs = await SharedPreferences.getInstance();
    final devModeEnabled =
        prefs.getBool('developer_mode_enabled') ?? false;
    final copyLogEnabled =
        prefs.getBool('dev_copy_byok_log') ?? false;

    final String copyText;
    if (rawError != null) {
      copyText = const JsonEncoder.withIndent('  ')
          .convert(rawError);
    } else {
      copyText = errorText;
    }

    if (devModeEnabled && copyLogEnabled) {
      await Clipboard.setData(ClipboardData(text: copyText));
      if (!mounted || _isDisposed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('dev_mode_copy_log_copied')),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      if (!mounted || _isDisposed) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('dev_mode_copy_log_toast')),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
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
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentBioScreen(
          bot: widget.bot,
          isGroup: _isGroup,
          groupMembers: _groupMembers,
          groupName: _groupName,
          groupBio: _groupBio,
          botId: widget.bot['id'].toString(),
          onKickMember: _handleKickMemberFromBio,
          onAddMembers: _handleAddMembersFromBio,
          onEditGroupInfo: _handleEditGroupInfoFromBio,
        ),
      ),
    );
  }

  void _handleKickMemberFromBio(int index) {
    final member = _groupMembers[index];
    final kickedId = member['bot_id']?.toString() ?? member['id']?.toString();

    _groupMembers.removeAt(index);

    if (kickedId != null && _selectedBotId == kickedId) {
      _selectedBotId = _groupMembers.isNotEmpty
          ? (_groupMembers.first['bot_id']?.toString() ??
              _groupMembers.first['id']?.toString())
          : null;
      _saveSelectedBot(_selectedBotId ?? '');
    }

    _localChatService.updateGroupMetadata(
      widget.bot['id'].toString(),
      name: _groupName,
      bio: _groupBio,
      members: _groupMembers,
    );
    _syncMetadataToMessages(
      name: _groupName,
      bio: _groupBio,
      members: _groupMembers,
    );
  }

  void _handleAddMembersFromBio(List<Map<String, dynamic>> bots) {
    final currentIds = _groupMembers
        .map((m) => m['bot_id']?.toString() ?? m['id']?.toString())
        .toSet();

    for (final bot in bots) {
      final botId = bot['id'].toString();
      if (!currentIds.contains(botId)) {
        _groupMembers.add({
          'bot_id': botId,
          'id': botId,
          'name': bot['name'] ?? 'Unknown',
          'image_url': bot['image_url'],
          'avatar': bot['avatar'],
          'color': bot['color'],
        });
      }
    }

    _localChatService.updateGroupMetadata(
      widget.bot['id'].toString(),
      name: _groupName,
      bio: _groupBio,
      members: _groupMembers,
    );
    _syncMetadataToMessages(
      name: _groupName,
      bio: _groupBio,
      members: _groupMembers,
    );
    _groupInfoChanged = true;
  }

  void _handleEditGroupInfoFromBio(String name, String bio) {
    _localChatService.updateGroupMetadata(
      widget.bot['id'].toString(),
      name: name,
      bio: bio,
      members: _groupMembers,
    );
    _syncMetadataToMessages(
      name: name,
      bio: bio,
      members: _groupMembers,
    );

    _safeSetState(() {
      _groupName = name;
      _groupBio = bio;
      widget.bot['name'] = name;
      widget.bot['description'] = bio;
    });
    _groupInfoChanged = true;
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

  void _syncMetadataToMessages({
    String? name,
    String? bio,
    List<Map<String, dynamic>>? members,
  }) {
    final idx = _messages.indexWhere(
      (m) => m['role'] == 'system' && m['metadata'] != null,
    );
    if (idx < 0) return;
    final oldMeta = _messages[idx]['metadata'];
    final meta = Map<String, dynamic>.from(
      oldMeta is Map ? Map<String, dynamic>.from(oldMeta) : <String, dynamic>{},
    );
    if (name != null) meta['name'] = name;
    if (bio != null) {
      meta['bio'] = bio;
      meta['description'] = bio;
    }
    if (members != null) meta['members'] = members;
    _messages[idx] = {..._messages[idx], 'metadata': meta};
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
      members: _groupMembers,
    );
    _syncMetadataToMessages(
      name: newName,
      bio: newBio,
      members: _groupMembers,
    );

    if (!mounted || _isDisposed) return;

    _safeSetState(() {
      _groupName = newName;
      _groupBio = newBio;
      widget.bot['name'] = newName;
      widget.bot['description'] = newBio;
    });
    _groupInfoChanged = true;

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
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (!mounted || _isDisposed) return;
            if (_groupInfoChanged) {
              Navigator.of(context).pop(<String, dynamic>{
                'type': 'group_info_updated',
                'id': widget.bot['id'].toString(),
                'name': _groupName,
                'bio': _groupBio,
              });
            } else {
              Navigator.of(context).pop();
            }
          },
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

                    _summaryProgressText.value = '';

                    // Show persistent loading popup
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
                              ListenableBuilder(
                                listenable: _summaryProgressText,
                                builder: (context, _) {
                                  final progress = _summaryProgressText.value;
                                  return Text(
                                    progress.isNotEmpty
                                        ? '${tr('chat_resummary_loading')} ($progress)'
                                        : tr('chat_resummary_loading'),
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                  );
                                },
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
                        const SnackBar(
                          content: Text('Re-generating summaries...'),
                        ),
                      );
                    }
                  } else if (value == 'delete') {
                    final result = await showDeleteChatSheet(context);
                    if (result == 'delete_all') {
                      await _localChatService.deleteChat(widget.bot['id']);
                      if (!context.mounted) return;
                      _safeSetState(() {
                        _messages = [];
                        _summaries.clear();
                      });
                      if (widget.isDesktopMode) {
                        widget.onChatDeleted?.call();
                      } else {
                        Navigator.of(context).pop();
                      }
                    } else if (result == 'delete_chat_only') {
                      await _localChatService.deleteChatOnly(widget.bot['id']);
                      if (!context.mounted) return;
                      _safeSetState(() {
                        _messages = [];
                      });
                    }
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
                  child: BondExplosionEffect(
                    onFinished: () {
                      _safeSetState(() => _showExplosion = false);
                    },
                  ),
                ),
              Container(
                decoration: getWallpaperDecoration(context) ?? BoxDecoration(color: pageBackground(context)),
                child: Column(
                  children: [
                    if (_showSafetyBar)
                      SafetyBar(
                        onDismiss: () => _safeSetState(
                          () => _showSafetyBar = false,
                        ),
                      ),
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
                          if (_isLoading && _messages.isEmpty)
                            const ChatMessagesSkeleton()
                          else
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
                                  final errorContent =
                                      msg['content']?.toString() ?? '';
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            errorContent,
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: IconButton(
                                            padding: EdgeInsets.zero,
                                            icon: Icon(
                                              Icons.copy,
                                              size: 14,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error,
                                            ),
                                            tooltip: tr('dev_mode_copy_log'),
                                            onPressed: () => _copyErrorLog(
                                              msg,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }

                                final timestamp = msg['timestamp'] != null
                                    ? DateTime.parse(msg['timestamp'])
                                    : null;

                                final content =
                                    msg['content']?.toString() ?? '';

                                final bubble = isUser
                                    ? _buildUserBubble(
                                        content,
                                        timestamp,
                                        index,
                                        status: msg['status']?.toString(),
                                      )
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
                                      showMessageOptionsSheet(
                                        context: context,
                                        content: content,
                                        canRegenerate: index ==
                                                _messages.length - 1 &&
                                            (_messages[index]['role'] ==
                                                    'assistant' ||
                                                _messages[index]['role'] ==
                                                    'system'),
                                        onRegenerate: _regenerateResponse,
                                        onRewind: () async {
                                          final trimmed =
                                              _messages.sublist(0, index + 1);

                                          _safeSetState(() {
                                            _messages = trimmed;
                                            _summaries.removeWhere(
                                              (key, value) =>
                                                  key >= trimmed.length,
                                            );
                                          });

                                          await _localChatService.saveChat(
                                            widget.bot['id'],
                                            _messages,
                                          );
                                          await _localChatService
                                              .saveSummaries(
                                            widget.bot['id'],
                                            _summaries,
                                          );
                                          _scrollToBottom();
                                        },
                                        onCopy: () {
                                          Clipboard.setData(
                                            ClipboardData(text: content),
                                          );
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                tr('chat_copy_success'),
                                              ),
                                              duration:
                                                  const Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        onEdit: () =>
                                            _showEditMessageDialog(index),
                                      ),
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
            ],
          ),
        ),
        ),
      ),
    );
  }

  String? _resolveBotName(String? botId) {
    if (botId == null) return null;
    try {
      final member = _groupMembers.firstWhere(
        (m) => (m['bot_id']?.toString() ?? m['id']?.toString()) == botId,
        orElse: () => <String, dynamic>{},
      );
      if (member.isNotEmpty && member['name'] != null) {
        return member['name'] as String;
      }
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
    if (botId == null) return parseColor(widget.bot['color']);
    try {
      final member = _groupMembers.firstWhere(
        (m) => (m['bot_id']?.toString() ?? m['id']?.toString()) == botId,
        orElse: () => <String, dynamic>{},
      );
      if (member.isNotEmpty && member['color'] != null) {
        return parseColor(member['color']);
      }
    } catch (_) {}
    return parseColor(widget.bot['color']);
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
                  color: titleColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: botBubbleBackground(context),
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
                    DotAnim(delay: 0),
                    SizedBox(width: 4),
                    DotAnim(delay: 0.2),
                    SizedBox(width: 4),
                    DotAnim(delay: 0.4),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserBubble(
    String content,
    DateTime? timestamp,
    int index, {
    String? status,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildStatusIcon() {
      if (status == 'sending') {
        return Icon(
          Icons.access_time,
          size: 12,
          color: Colors.white,
        );
      } else if (status == 'sent') {
        return Icon(Icons.check, size: 14, color: Colors.white);
      } else if (status == 'processing' || status == 'completed') {
        return Icon(Icons.done_all, size: 14, color: Colors.white);
      }
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timestamp != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, right: 4),
              child: Text(
                formatMessageTime(timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: subtextOnWallpaper(context, colorScheme.onSurfaceVariant),
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
                    if (status != null) ...[
                      const SizedBox(height: 4),
                      buildStatusIcon(),
                    ],
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
                        color: textOnWallpaper(context, titleColor(context)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (timestamp != null)
                      Text(
                        formatMessageTime(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: subtextOnWallpaper(context, colorScheme.onSurfaceVariant),
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
                        color: botBubbleBackground(context),
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
                        color: botBubbleBackground(context),
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
                          DotAnim(delay: 0),
                          SizedBox(width: 4),
                          DotAnim(delay: 0.2),
                          SizedBox(width: 4),
                          DotAnim(delay: 0.4),
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
        color: surfaceBackground(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fieldBorderColor(context)),
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
                    color: subtitleColor(context),
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
            style: TextStyle(color: titleColor(context), fontSize: 13),
            onChanged: (_) => _saveSystemNote(),
            decoration: InputDecoration(
              hintText: tr('chat_system_note_hint'),
              hintStyle: TextStyle(color: hintColor(context), fontSize: 12),
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
        child: Icon(
          Icons.shuffle,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 28,
        ),
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
        bgColor = parseColor(member['color']);
      }
    } else {
      avatarUrl = widget.bot['image_url'];
      initial = (widget.bot['name'] ?? '?')[0].toUpperCase();
      bgColor = parseColor(widget.bot['color']);
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
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: surfaceBackground(context),
        borderRadius: BorderRadius.circular(28),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ..._groupMembers.map((member) {
              final memberId =
                  member['bot_id']?.toString() ?? member['id']?.toString();
              final isSelected = _selectedBotId == memberId;
              final color = parseColor(member['color']);

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
                    child:
                        (member['image_url'] == null &&
                            member['avatar'] == null)
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
                    color: _selectedBotId == 'random'
                        ? Colors.orange
                        : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: _selectedBotId == 'random'
                      ? Colors.orange.withValues(alpha: 0.1)
                      : Colors.transparent,
                  child: Icon(
                    Icons.shuffle,
                    size: 22,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemNoteIconButton() {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: () =>
          _safeSetState(() => _isSystemNoteOpen = !_isSystemNoteOpen),
      icon: Icon(
        _isSystemNoteOpen ? Icons.sticky_note_2 : Icons.sticky_note_2_outlined,
        color: _isSystemNoteOpen
            ? colorScheme.primary
            : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
      ),
      iconSize: 22,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
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
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                            fontSize: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(50),
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                            ),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                        onSubmitted: (_) {
                          if (!_isTypingEffectActive && !_isSummarizing) {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    if (_isGroup) ...[_buildSystemNoteIconButton()],
                    GestureDetector(
                      onTap: (_isTypingEffectActive || _isSummarizing)
                          ? null
                          : _sendMessage,
                      child: Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.send,
                          color: (_isTypingEffectActive || _isSummarizing)
                              ? colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                )
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
                    color: subtitleColor(context),
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


