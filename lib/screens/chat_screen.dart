import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/widget_previews.dart';
import 'package:http/http.dart' as http;
import '../services/ai_service.dart';
import '../services/auth_service.dart';
import '../services/local_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../services/localization_service.dart';
import '../widgets/skeleton_loader.dart';
import 'call_screen.dart';
import '../widgets/chat/bond_explosion_effect.dart';
import '../widgets/chat/safety_bar.dart';
import '../widgets/chat/delete_bottom_sheet.dart';
import '../widgets/chat/message_options_sheet.dart';
import '../widgets/chat/user_message_bubble.dart';
import '../widgets/chat/bot_message_bubble.dart';
import '../widgets/chat/typing_indicator.dart';
import '../widgets/chat/compact_character_menu.dart';
import '../widgets/chat/system_note_area.dart';
import '../widgets/chat/chat_input_area.dart';
import '../widgets/chat/edit_message_dialog.dart';
import '../widgets/chat/edit_group_info_dialog.dart';
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
  final void Function(Widget child, String title)? onOpenPanel4;
  final VoidCallback? onClosePanel4;

  const ChatDetailScreen({
    super.key,
    required this.bot,
    required this.provider,
    this.initialMessage,
    this.isDesktopMode = false,
    this.onChatDeleted,
    this.onOpenPanel4,
    this.onClosePanel4,
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
  Set<int> _failedSummaryBatches = {};
  static const int _maxSummaryRetries = 5;
  bool _isSummarizing = false;
  double _summaryProgress = 0.0;
  final ValueNotifier<String> _summaryProgressText = ValueNotifier<String>('');
  bool _isTypingEffectActive = false;
  bool _isDisposed = false;
  bool _showScrollButton = false;
  bool _isPollingActive = false;
  bool _streamStopRequested = false;
  String? _retryCountdownText;
  bool _hasSystemError = false;
  bool _showChildWarning = false;

  // Debug overlay state
  bool _showDebugOverlay = false;

  OverlayEntry? _debugOverlayEntry;
  final List<String> _debugLogs = [];
  final ScrollController _debugScrollController = ScrollController();

  final TextEditingController _systemNoteController = TextEditingController();
  bool _isSystemNoteOpen = false;
  final TextEditingController _personaController = TextEditingController();
  bool _isPersonaOpen = false;
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
    _showChildWarning = widget.bot['child'] == true && !_isGroup;
    _scrollController.addListener(_scrollListener);
    _loadHistory();
    _loadSystemNote();
    _loadPersona();
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
    _isPollingActive = false;
    _debugOverlayEntry?.remove();
    _debugScrollController.dispose();
    _scrollController.removeListener(_scrollListener);
    _messageController.dispose();
    _scrollController.dispose();
    _systemNoteController.dispose();
    _personaController.dispose();
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

  Future<void> _loadPersona() async {
    final prefs = await SharedPreferences.getInstance();
    final persona = prefs.getString('persona_${widget.bot['id']}') ?? '';
    if (!mounted || _isDisposed) return;
    _personaController.text = persona;
  }

  Future<void> _savePersona() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'persona_${widget.bot['id']}',
      _personaController.text,
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
    debugPrint('[$timestamp] $message');
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
          }

          _groupBio = resolvedBio;

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

    // Retry 1-2 batch summary terakhir yang gagal ([...])
    final sortedKeys = _summaries.keys.toList()..sort();
    int retried = 0;
    for (int k = sortedKeys.length - 1; k >= 0 && retried < 2; k--) {
      final idx = sortedKeys[k];
      if (_summaries[idx] == '[...]') {
        _summaries.remove(idx);
        _failedSummaryBatches.remove(idx);
        retried++;
        _addDebugLog('Retrying previously failed summary batch $idx');
        debugPrint('DEBUG: Retrying previously failed summary batch $idx');
      } else {
        break;
      }
    }

    if (retried > 0) {
      totalBatchesToSummarize = 0;
      for (int i = 0; i <= realMessages.length - batchSize; i += batchSize) {
        if (!_summaries.containsKey(i)) {
          totalBatchesToSummarize++;
        }
      }
    }

    if (totalBatchesToSummarize == 0) return;

    // Load existing memories to pass to AI
    final existingMemories = await _localChatService.loadMemories(widget.bot['id']);

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
    List<String> latestMemories = List.from(existingMemories);

    for (int i = 0; i <= realMessages.length - batchSize; i += batchSize) {
      if (!_summaries.containsKey(i)) {
        if (_failedSummaryBatches.contains(i)) continue;

        bool batchDone = false;

        for (int attempt = 1; attempt <= _maxSummaryRetries && !batchDone && mounted && !_isDisposed; attempt++) {
          if (mounted && !_isDisposed) {
            _safeSetState(() {
              if (_messages.isNotEmpty && _messages.last['isTempSummary'] == true) {
                _messages.last['content'] = '${tr('chat_compressing_memory')} ($processedBatches/$totalBatchesToSummarize)';
              }
            });
          }
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
              existingMemories: latestMemories,
            );

            if (result != null &&
                result['status'] == 'queued' &&
                result['uuid'] != null) {
              final pollResult = await _pollSummaryStatus(result['uuid']);
              if (!mounted || _isDisposed) return;

              if (pollResult == null) {
                // Timeout - retry
                _addDebugLog('Summary batch $i attempt $attempt: poll timeout');
                debugPrint('DEBUG: Summary batch $i attempt $attempt: poll timeout');
                if (attempt >= _maxSummaryRetries) {
                  _summaries[i] = '[...]';
                  _failedSummaryBatches.add(i);
                  batchDone = true;
                  updated = true;
                }
                continue;
              }

              if (pollResult['error'] != null ||
                  pollResult['status'] == 'not_found' ||
                  pollResult['status'] == 'failed') {
                final errorStatusCode = pollResult['error_status_code'] ?? 0;
                final delay = _getRetryDelay(errorStatusCode);

                _addDebugLog('Summary batch $i attempt $attempt error: status_code=$errorStatusCode');
                debugPrint('DEBUG: Summary batch $i attempt $attempt error: status_code=$errorStatusCode');

                if (delay < 0 || attempt >= _maxSummaryRetries) {
                  _summaries[i] = '[...]';
                  _failedSummaryBatches.add(i);
                  batchDone = true;
                  updated = true;
                  _addDebugLog('Summary batch $i: gave up after $attempt attempts');
                  debugPrint('DEBUG: Summary batch $i: gave up after $attempt attempts');
                  break;
                }

                // Countdown before retry
                for (int s = delay; s > 0 && mounted && !_isDisposed; s--) {
                  final msg = tr('summary_error_retry').replaceAll('{interval}', s.toString());
                  _safeSetState(() {
                    if (_messages.isNotEmpty && _messages.last['isTempSummary'] == true) {
                      _messages.last['content'] = msg;
                    }
                  });
                  await Future.delayed(const Duration(seconds: 1));
                }
                continue; // retry
              } else {
                // Success
                final summaryText = pollResult['summary'] ?? pollResult['response']?['summary'];
                if (summaryText != null && summaryText.isNotEmpty) {
                  _summaries[i] = summaryText;
                  updated = true;
                }
                final mems = pollResult['memory_worth_keeping'] ?? pollResult['response']?['memory_worth_keeping'];
                if (mems is List && mems.isNotEmpty) {
                  latestMemories = List<String>.from(mems);
                  await _localChatService.saveMemories(widget.bot['id'], latestMemories);
                }
                batchDone = true;
                _addDebugLog('Summary batch $i attempt $attempt succeeded');
                debugPrint('DEBUG: Summary batch $i attempt $attempt succeeded');
              }
            } else if (result != null &&
                result['summary'] != null &&
                (result['summary'] as String).isNotEmpty &&
                result['error'] != true) {
              _summaries[i] = result['summary'];
              updated = true;
              if (result['memory_worth_keeping'] is List) {
                latestMemories = List<String>.from(result['memory_worth_keeping']);
                await _localChatService.saveMemories(widget.bot['id'], latestMemories);
              }
              batchDone = true;
              _addDebugLog('Summary batch $i direct success');
              debugPrint('DEBUG: Summary batch $i direct success');
            } else {
              // Direct error
              final errorStatusCode = result != null ? (result['error_status_code'] ?? 0) : 0;
              final delay = _getRetryDelay(errorStatusCode);

              _addDebugLog('Summary batch $i attempt $attempt direct error: status_code=$errorStatusCode');
              debugPrint('DEBUG: Summary batch $i attempt $attempt direct error: status_code=$errorStatusCode');

              if (delay < 0 || attempt >= _maxSummaryRetries) {
                _summaries[i] = '[...]';
                _failedSummaryBatches.add(i);
                batchDone = true;
                updated = true;
                break;
              }

              for (int s = delay; s > 0 && mounted && !_isDisposed; s--) {
                final msg = tr('summary_error_retry').replaceAll('{interval}', s.toString());
                _safeSetState(() {
                  if (_messages.isNotEmpty && _messages.last['isTempSummary'] == true) {
                    _messages.last['content'] = msg;
                  }
                });
                await Future.delayed(const Duration(seconds: 1));
              }
            }
          } catch (e) {
            _addDebugLog('Summary batch $i attempt $attempt exception: $e');
            debugPrint('DEBUG: Summary batch $i attempt $attempt exception: $e');
            if (attempt >= _maxSummaryRetries) {
              _summaries[i] = '[...]';
              _failedSummaryBatches.add(i);
              batchDone = true;
              updated = true;
            }
          }
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

  int _getRetryDelay(int statusCode) {
    if (statusCode == 429) return 30;
    if (statusCode == 500 || statusCode == 503) return 15;
    if (statusCode == 422) return -1;
    if (statusCode == 400 || statusCode == 401) return 10;
    return 15;
  }

  Future<Map<String, dynamic>?> _pollSummaryStatus(String uuid) async {
    int checks = 30;
    while (mounted && !_isDisposed && checks > 0) {
      await Future.delayed(const Duration(seconds: 3));
      final status = await _aiService.checkChatStatus(uuid);
      if (status == null) { checks--; continue; }
      if (status['status'] == 'processing' ||
          status['status'] == 'queued') { checks--; continue; }
      return status;
    }
    return null;
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

    await _getAIResponse();
  }

  Future<void> _retryAfterError() async {
    _safeSetState(() {
      if (_messages.isNotEmpty && _messages.last['role'] == 'system') {
        _messages.removeLast();
      }
      _hasSystemError = false;
      _isLoading = true;
    });
    _scrollToBottom();
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

    // Determine which summaries to use (last 2 for context efficiency)
    final sortedSummaryKeys = _summaries.keys.toList()..sort();
    final keysToUse = sortedSummaryKeys.length > 2
        ? sortedSummaryKeys.sublist(sortedSummaryKeys.length - 2)
        : sortedSummaryKeys;

    String? summaryPrompt;
    if (_summaries.isNotEmpty) {
      summaryPrompt = "[CONVERSATION RECAP]\n";
      for (var key in keysToUse) {
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

    int summarizedCount = keysToUse.length * 20;
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
    final bool bondDisabled = prefs.getBool('bond_disabled') ?? false;

    // Resolve persona: per-chat override > global persona > none
    String? resolvedPersona;
    final chatPersona = prefs.getString('persona_${widget.bot['id']}');
    if (chatPersona != null && chatPersona.trim().isNotEmpty) {
      resolvedPersona = chatPersona.trim();
    } else {
      final profile = await AuthService().getUserProfile();
      final globalPersona = profile?['persona'] as String?;
      if (globalPersona != null && globalPersona.trim().isNotEmpty) {
        resolvedPersona = globalPersona.trim();
      }
    }
    if (realtimeDateTime) {
      final timeTag = DateFormat("'[this message sent at 'dd/MM/yyyy HH:mm:ss']'").format(DateTime.now());
      final List<Map<String, String>> injected = [];
      for (final msg in aiMessages) {
        if (msg['role'] == 'user' && msg['content'] != '[Continue]') {
          injected.add({'role': 'user', 'content': timeTag});
        }
        injected.add(msg);
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
      if (resolvedPersona != null) {
        print('DEBUG: Persona: $resolvedPersona');
      }
      print('DEBUG: Messages Payload: ${jsonEncode(aiMessages)}');
      print('DEBUG: ---------------------');
    }

    final aiTimestamp = DateTime.now().toIso8601String();

    for (int attempt = 1; attempt <= _maxSummaryRetries; attempt++) {
      if (attempt > 1) {
        _safeSetState(() {
          if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
            _messages.last['status'] = 'sent';
          }
        });
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
          persona: resolvedPersona,
          bondDisabled: bondDisabled,
          isGroup: _isGroup,
        );

        if (!mounted || _isDisposed) return;

        if (response != null && response['status'] == 'queued') {
          _safeSetState(() {
            if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
              _messages.last['status'] = 'sent';
              _messages.last['uuid'] = response['uuid'];
            }
          });

          _isPollingActive = true;
          _streamStopRequested = false;
          // Mode stream (default true): baca SSE /chat/stream/:uuid dengan
          // render inkremental per kata. Gagal/terputus -> fallback polling.
          // Mode false: polling biasa + bubble delay 2 detik (legacy).
          Map<String, dynamic>? pollResult;
          bool streamSkipTyping = false;
          String? streamUuid;
          if (await AIService.isStreamEnabled()) {
            streamUuid = response['uuid'] as String?;
            final outcome = await _streamForResult(
              response['uuid'],
              botIdForRequest,
              aiTimestamp,
            );
            if (outcome.kind == StreamOutcomeKind.done) {
              pollResult = outcome.result;
              streamSkipTyping = true;
            } else if (outcome.kind == StreamOutcomeKind.stopped) {
              // User menekan Stop: finalisasi teks parsial, tetap tersimpan
              // sebagai riwayat — tanpa error, tanpa retry.
              _isPollingActive = false;
              if (!mounted || _isDisposed) return;
              if (!_hasStreamingTail()) {
                // Belum ada delta sama sekali: fallback polling sekali,
                // job mungkin selesai normal.
                _isPollingActive = true;
                _streamStopRequested = false;
                if (mounted && !_isDisposed) {
                  pollResult = await _pollLoopForResult(response['uuid']);
                }
                _isPollingActive = false;
                if (!mounted || _isDisposed) return;
                if (pollResult == null) {
                  if (attempt >= _maxSummaryRetries) {
                    _safeSetState(() {
                      _isLoading = false;
                      _activeBotId = null;
                    });
                    _addSystemError(aiTimestamp);
                    return;
                  }
                  await _doRetryCountdown(15);
                  continue;
                }
              } else {
                _safeSetState(() {
                  if (_messages.isNotEmpty &&
                      _messages.last['role'] == 'user') {
                    _messages.last['status'] = 'completed';
                  }
                });
                await _finalizeStoppedStream();
                return;
              }
            } else if (mounted && !_isDisposed) {
              pollResult = await _pollLoopForResult(response['uuid']);
            }
          } else {
            pollResult = await _pollLoopForResult(response['uuid']);
          }
          _isPollingActive = false;
          if (!mounted || _isDisposed) return;

          if (pollResult == null) {
            // Stream selesai tanpa done yang valid (mis. done {uuid} kosong):
            // bersihkan bubble streaming parsial lalu fallback polling agar
            // tidak tampil bubble menggantung.
            if (streamUuid != null) _removeStreamingBubbles();
            if (attempt >= _maxSummaryRetries) {
              _safeSetState(() { _isLoading = false; _activeBotId = null; });
              _addSystemError(aiTimestamp);
              return;
            }
            await _doRetryCountdown(15);
            continue;
          }

          if (pollResult['error'] != null ||
              pollResult['status'] == 'not_found') {
            final statusCode = (pollResult['error_status_code'] ?? 0) as int;
            final delay = _getRetryDelay(statusCode);

            if (delay < 0 || attempt >= _maxSummaryRetries) {
              if (streamUuid != null) _removeStreamingBubbles();
              _safeSetState(() {
                if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
                  _messages.last['status'] = 'completed';
                }
              });
              await _handleAIResponseData(pollResult, botIdForRequest, aiTimestamp);
              return;
            }

            await _doRetryCountdown(delay);
            continue;
          }

          _safeSetState(() {
            if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
              _messages.last['status'] = 'completed';
            }
          });
          await _handleAIResponseData(
            pollResult,
            botIdForRequest,
            aiTimestamp,
            skipTypingEffect: streamSkipTyping,
          );
          return;
        }

        await _handleAIResponseData(response, botIdForRequest, aiTimestamp);
        return;
      } catch (e) {
        if (!mounted || _isDisposed) return;
        if (attempt >= _maxSummaryRetries) {
          _safeSetState(() { _isLoading = false; _activeBotId = null; });
          _addSystemError(aiTimestamp);
          return;
        }
        await _doRetryCountdown(15);
      }
    }
  }

  Future<void> _doRetryCountdown(int delay) async {
    for (int s = delay; s > 0 && mounted && !_isDisposed; s--) {
      _safeSetState(() {
        _retryCountdownText = tr('summary_error_retry').replaceAll('{interval}', s.toString());
      });
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted && !_isDisposed) {
      _safeSetState(() => _retryCountdownText = null);
    }
  }

  /// Mode stream (Opsi A): satu bubble live berisi seluruh teks sejauh ini
  /// + kursor di ujung, update in-place. Batas paragraf tidak dipecah live —
  /// pemecahan bubble per paragraf terjadi saat `done` via
  /// [_handleAIResponseData] (skipTypingEffect).
  /// [StreamOutcome.done]: hasil `done` yang sudah di-unwrap (bersih).
  /// [StreamOutcome.stopped]: user menekan Stop — bubble live difinalisasi
  /// oleh [_finalizeStoppedStream].
  /// [StreamOutcome.failed]: SSE gagal -> caller fallback ke polling.
  /// Bubble delay 2 detik (_startTypingEffect) dilewati via skipTypingEffect
  /// karena teks sudah muncul bertahap selama streaming.
  Future<StreamOutcome> _streamForResult(
    String uuid,
    String? botIdForRequest,
    String aiTimestamp,
  ) async {
    final buffer = StringBuffer();
    bool bubbleAdded = false;
    bool renderPending = false;
    Timer? coalesceTimer;

    // Satu bubble live: dibuat sekali, lalu content-nya di-update in-place.
    // Tidak pernah hapus-buat ulang agar kursor mengetik maju di tempat.
    void renderStreaming() {
      renderPending = false;
      if (!mounted || _isDisposed || !_isPollingActive) return;
      final full = buffer.toString();
      if (full.isEmpty) return;
      _safeSetState(() {
        if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
          _messages.last['status'] = 'processing';
        }
        if (!bubbleAdded) {
          _messages.add({
            'role': 'assistant',
            'content': full,
            'timestamp': aiTimestamp,
            'bot_id': botIdForRequest,
            'bot_name': _resolveBotName(botIdForRequest),
            'bot_avatar': _resolveBotAvatar(botIdForRequest),
            // Milik stream: boleh dihapus/diganti cleanup.
            'is_streaming': true,
            // Masih berjalan: tampilkan kursor streaming.
            'is_stream_live': true,
          });
          bubbleAdded = true;
        } else {
          for (var i = _messages.length - 1; i >= 0; i--) {
            final m = _messages[i];
            if (m['role'] != 'assistant') break;
            if (m['is_streaming'] == true) {
              m['content'] = full;
              break;
            }
          }
        }
      });
      _scrollToBottom();
    }

    void scheduleRender() {
      if (renderPending) return;
      renderPending = true;
      coalesceTimer ??= Timer(const Duration(milliseconds: 100), () {
        coalesceTimer = null;
        renderStreaming();
      });
    }

    void appendDelta(String delta) {
      if (!mounted ||
          _isDisposed ||
          !_isPollingActive ||
          _streamStopRequested) {
        return;
      }
      buffer.write(delta);
      scheduleRender();
    }

    final outcome = await _aiService.streamChatStatus(
      uuid,
      onDelta: appendDelta,
      isCancelled: () => _streamStopRequested,
    );
    // Flush sisa delta yang belum sempat ter-render (penting untuk Stop).
    coalesceTimer?.cancel();
    coalesceTimer = null;
    if (renderPending && mounted && !_isDisposed && _isPollingActive) {
      renderStreaming();
    }
    if (!mounted || _isDisposed) return outcome;
    return outcome;
  }

  /// Finalisasi stream yang dihentikan user: ubah bubble live menjadi bubble
  /// final (tanpa kursor), simpan chat + generate summary dari teks yang ada.
  /// Tanpa system error, tanpa retry — pesan parsial tetap tersimpan.
  Future<void> _finalizeStoppedStream() async {
    _safeSetState(() {
      _isLoading = false;
      _activeBotId = null;
      for (var i = _messages.length - 1; i >= 0; i--) {
        final m = _messages[i];
        if (m['role'] != 'assistant') break;
        if (m['is_streaming'] == true) {
          m.remove('is_streaming');
          m.remove('is_stream_live');
        }
      }
    });
    _scrollToBottom();
    await _localChatService.saveChat(widget.bot['id'], _messages);
    _generateSummaries();
  }

  /// Dipanggil tombol Stop: batalkan SSE yang sedang berjalan.
  void _stopStreaming() {
    if (!_isPollingActive) return;
    _safeSetState(() {
      _streamStopRequested = true;
    });
  }

  bool _hasStreamingTail() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m['role'] != 'assistant') break;
      if (m['is_stream_live'] == true) return true;
    }
    return false;
  }

  /// Hapus semua bubble streaming (parsial) — dipakai sebelum fallback
  /// polling / tampilkan error agar tidak ada bubble menggantung.
  void _removeStreamingBubbles() {
    _safeSetState(() {
      _messages.removeWhere((m) => m['is_streaming'] == true);
    });
  }

  Future<Map<String, dynamic>?> _pollLoopForResult(String uuid) async {
    int checks = 60;
    while (_isPollingActive && mounted && !_isDisposed && checks > 0) {
      await Future.delayed(const Duration(seconds: 3));
      final response = await _aiService.checkChatStatus(uuid);
      if (response == null) { checks--; continue; }
      if (response['status'] == 'processing' || response['status'] == 'queued') {
        if (response['status'] == 'processing') {
          _safeSetState(() {
            if (_messages.isNotEmpty && _messages.last['role'] == 'user') {
              _messages.last['status'] = 'processing';
            }
          });
        }
        checks--;
        continue;
      }
      return response;
    }
    return null;
  }

  Future<void> _handleAIResponseData(
    Map<String, dynamic>? response,
    String? botIdForRequest,
    String aiTimestamp, {
    bool skipTypingEffect = false,
  }) async {
    bool shouldStartTyping = false;
    int partsLength = 0;

    final prefsBond = await SharedPreferences.getInstance();
    final bondNowDisabled = prefsBond.getBool('bond_disabled') ?? false;

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

          if (skipTypingEffect) {
            // Mode stream: bubble-bubble inkremental sudah tampil live;
            // hapus semuanya, bangun ulang dari konten final bersih
            // (hasil ParseBondTags backend sebagai bubble per paragraf),
            // tanpa bubble delay 2 detik.
            _messages.removeWhere((m) => m['is_streaming'] == true);
            _messages.add({
              'role': 'assistant',
              'content': aiContent,
              'timestamp': aiTimestamp,
              'bot_id': botIdForRequest,
              'bot_name': _resolveBotName(botIdForRequest),
              'bot_avatar': _resolveBotAvatar(botIdForRequest),
            });
          } else {
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
      if (response != null && !bondNowDisabled) {
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

    if (_pendingBondEvent != null && !bondNowDisabled) {
      final evt = _pendingBondEvent!;
      _pendingBondEvent = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_isDisposed) _handleBondEvent(evt);
      });
    } else {
      _pendingBondEvent = null;
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

      _scrollToBottom();
    }

    _generateSummaries();
    await _localChatService.saveChat(widget.bot['id'], _messages);
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
    _hasSystemError = true;
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
    if (widget.onOpenPanel4 != null) {
      widget.onOpenPanel4!(
        StudentBioScreen(
          bot: widget.bot,
          isGroup: _isGroup,
          groupMembers: _groupMembers,
          groupName: _groupName,
          groupBio: _groupBio,
          botId: widget.bot['id'].toString(),
          isPanel: true,
          onOpenPanel4: widget.onOpenPanel4,
          onClosePanel: () => widget.onClosePanel4?.call(),
          onKickMember: _handleKickMemberFromBio,
          onAddMembers: _handleAddMembersFromBio,
          onEditGroupInfo: _handleEditGroupInfoFromBio,
        ),
        widget.bot['name'] ?? 'Bio',
      );
      return;
    }

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
            automaticallyImplyLeading: false,
            leading: widget.isDesktopMode
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
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
                        ? CachedNetworkImageProvider(widget.bot['image_url'])
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
                              () {
                                final raw = _isGroup
                                    ? (_groupName.isNotEmpty
                                          ? _groupName
                                          : widget.bot['name'])
                                    : widget.bot['name'];
                                return raw.length > 15
                                    ? '${raw.substring(0, 15)}...'
                                    : raw;
                              }(),
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
              IconButton(
                icon: Icon(Icons.call, color: subtitleColor(context)),
                onPressed: () {
                  if (widget.isDesktopMode && widget.onOpenPanel4 != null) {
                    widget.onOpenPanel4!(
                      CallScreen(bot: widget.bot, onClose: widget.onClosePanel4),
                      "Call",
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CallScreen(bot: widget.bot),
                      ),
                    );
                  }
                },
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: subtitleColor(context)),
                onSelected: (value) async {
                  if (value == 'edit_group_info') {
                    final result = await showEditGroupInfoDialog(
                      context: context,
                      initialName: _groupName.isNotEmpty
                          ? _groupName
                          : widget.bot['name'] ?? '',
                      initialBio: _groupBio,
                    );
                    if (result == null) return;
                    await _localChatService.updateGroupMetadata(
                      widget.bot['id'].toString(),
                      name: result.name,
                      bio: result.bio,
                      members: _groupMembers,
                    );
                    _syncMetadataToMessages(
                      name: result.name,
                      bio: result.bio,
                      members: _groupMembers,
                    );
                    if (!mounted || _isDisposed) return;
                    _safeSetState(() {
                      _groupName = result.name;
                      _groupBio = result.bio;
                      widget.bot['name'] = result.name;
                      widget.bot['description'] = result.bio;
                    });
                    _groupInfoChanged = true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Group info updated.')),
                    );
                  } else if (value == 'toggle_italics') {
                    await _saveItalicsSetting(!_hideItalics);
                  } else if (value == 're_summary') {
                    _safeSetState(() => _summaries.clear());
                    await _localChatService.saveSummaries(
                      widget.bot['id'],
                      _summaries,
                    );
                    await _localChatService.saveMemories(widget.bot['id'], []);

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
                decoration: BoxDecoration(color: pageBackground(context)),
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
                                    ? UserMessageBubble(
                                        content: filterItalics(
                                          content,
                                          _hideItalics,
                                        ),
                                        timestampStr:
                                            formatMessageTime(timestamp),
                                        status: msg['status']?.toString(),
                                        maxWidth: MediaQuery.of(context)
                                                .size
                                                .width *
                                             0.7,
                                       )
                                      : BotMessageBubble(
                                          content:
                                              msg['content']?.toString() ?? '',
                                          timestampStr:
                                              formatMessageTime(timestamp),
                                          visibleParts:
                                              msg['visible_parts'] as int?,
                                          isTypingNext:
                                              msg['is_typing_next'] == true,
                                          isStreaming:
                                              msg['is_stream_live'] == true,
                                          hideItalics: _hideItalics,
                                         maxWidth: MediaQuery.of(context)
                                                 .size
                                                 .width *
                                             0.65,
                                         botName: _resolveBotName(
                                                 msg['bot_id']) ??
                                             widget.bot['name'],
                                         botAvatarUrl:
                                             _resolveBotAvatar(msg['bot_id']),
                                         botColor:
                                             _resolveBotColor(msg['bot_id']),
                                          titleTextColor: titleColor(context),
                                          timestampColor: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                         bubbleBgColor:
                                             botBubbleBackground(context),
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
                                            showEditMessageDialog(
                                              context: context,
                                              initialContent:
                                                  _messages[index]
                                                      ['content'],
                                              onSave: (newContent) async {
                                                _safeSetState(() {
                                                  _messages[index]
                                                          ['content'] =
                                                      newContent;
                                                });
                                                await _localChatService
                                                    .saveChat(
                                                  widget.bot['id'],
                                                  _messages,
                                                );
                                              },
                                            ),
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
                              child: CompactCharacterMenu(
                                groupMembers: _groupMembers,
                                selectedBotId: _selectedBotId,
                                onSelected: (id) {
                                  _saveSelectedBot(id!);
                                  _safeSetState(
                                      () => _isCharacterMenuOpen = false);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoading)
                      _buildTypingIndicatorWidget(),
                    if (_retryCountdownText != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 60, top: 2),
                        child: Text(
                          _retryCountdownText!,
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ),
                    SystemNoteArea(
                      isOpen: _isSystemNoteOpen,
                      controller: _systemNoteController,
                      onChanged: (_) => _saveSystemNote(),
                      onClose: () =>
                          _safeSetState(() => _isSystemNoteOpen = false),
                    ),
                    SystemNoteArea(
                      isOpen: _isPersonaOpen,
                      controller: _personaController,
                      onChanged: (_) => _savePersona(),
                      onClose: () =>
                          _safeSetState(() => _isPersonaOpen = false),
                      title: tr('chat_persona'),
                      hintText: tr('chat_persona_hint'),
                      maxLength: 500,
                    ),
                    ChatInputArea(
                      isGroup: _isGroup,
                      leadingAvatar: _buildLeftInputIcon(),
                      onToggleCharacterMenu: () => _safeSetState(
                          () => _isCharacterMenuOpen = !_isCharacterMenuOpen),
                      messageController: _messageController,
                      hintText: _isGroup
                          ? () {
                              final memberName = _selectedBotId == 'random'
                                  ? 'someone'
                                  : _groupMembers.firstWhere(
                                      (m) => (m['bot_id']?.toString() ??
                                              m['id']?.toString()) ==
                                          _selectedBotId,
                                      orElse: () => {
                                        'name': widget.bot['name']
                                      })['name'];
                              final truncated = memberName.length > 15
                                  ? '${memberName.substring(0, 15)}...'
                                  : memberName;
                              return 'Chatting with $truncated';
                            }()
                          : '${tr('tab_chat')} ${(widget.bot['name'] as String).length > 15 ? '${(widget.bot['name'] as String).substring(0, 15)}...' : widget.bot['name']}',
                      isSendEnabled:
                          !_isLoading && !_isTypingEffectActive && !_isSummarizing,
                      onSend: _sendMessage,
                      hasSystemError: _hasSystemError,
                      onRetry: _retryAfterError,
                      isStreaming: _isPollingActive && !_streamStopRequested,
                      onStop: _stopStreaming,
                      isSystemNoteOpen: _isSystemNoteOpen,
                      isPersonaOpen: _isPersonaOpen,
                      onToggleSystemNote: () => _safeSetState(
                          () => _isSystemNoteOpen = !_isSystemNoteOpen),
                      onTogglePersona: () => _safeSetState(
                          () => _isPersonaOpen = !_isPersonaOpen),
                    ),
                  ],
                ),
              ),
              if (_showChildWarning)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _buildChildWarningBanner(context),
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

  Widget _buildChildWarningBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.amber.shade100,
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: TextStyle(fontSize: 12, color: Colors.black87),
                children: [
                  TextSpan(text: tr('child_sfw_warning')),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: 'https://s.my-bini.my.id/hs-sfw-policy',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      decoration: TextDecoration.underline,
                      fontSize: 12,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(
                          Uri.parse('https://s.my-bini.my.id/hs-sfw-policy'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _safeSetState(() => _showChildWarning = false),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, color: Colors.black54, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicatorWidget() {
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

    final displayName =
        _resolveBotName(effectiveBotId) ?? widget.bot['name'];
    final avatarUrl = _resolveBotAvatar(effectiveBotId);
    final bgColor = _resolveBotColor(effectiveBotId);

    return TypingIndicator(
      botName: displayName,
      botAvatarUrl: avatarUrl,
      botColor: bgColor,
      titleColor: titleColor(context),
      bubbleBgColor: botBubbleBackground(context),
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
      backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
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

  void _triggerBondExplosion() {
    _safeSetState(() {
      _showExplosion = true;
    });
  }
}


