import 'dart:convert';
import 'dart:io';
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

  const ChatDetailScreen({
    super.key,
    required this.bot,
    required this.provider,
    this.initialMessage,
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

  // System Note
  final TextEditingController _systemNoteController = TextEditingController();
  bool _isSystemNoteOpen = false;

  bool _showScrollButton = false;
  bool _isDisposed = false;
  static const String _chatHeaderFont = 'Roboto';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadHistory();
    _loadSystemNote();
    if (widget.provider == 'System' && !_hasShownSystemAiWarning) {
      _showSystemAiWarning();
      _hasShownSystemAiWarning = true;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
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
                  color: Colors.grey[300],
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
    // Strip any temporary animation keys that might have been saved if the app was closed mid-typing
    for (var msg in history) {
      msg.remove('visible_parts');
      msg.remove('is_typing_next');
    }
    final summaries = await _localChatService.loadSummaries(widget.bot['id']);
    if (!mounted || _isDisposed) return;
    _safeSetState(() {
      _messages = history;
      _summaries = summaries;
    });
    _scrollToBottom();

    // Auto-catchup / update summaries
    _generateSummaries();

    // Jika ada pesan awal (dari reply story), kirim langsung
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _messageController.text = widget.initialMessage!;
      _sendMessage();
    }
  }

  Future<void> _generateSummaries() async {
    if (_isSummarizing) return;
    if (!mounted || _isDisposed) return;

    final int batchSize = 20;

    // First, count total batches that need summarizing
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

    // Find batches that need summarizing
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
          );

          if (result != null && result['summary'] != null) {
            _summaries[i] = result['summary'];
            updated = true;
          }
        } catch (e) {
          print('DEBUG: Summarization failed for batch $i: $e');
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
    // Attempt 1: Standard immediate scroll after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isDisposed || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    // Attempt 2: Delayed scroll to catch late layout updates (e.g. images, long texts)
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

    final userMessage = _messageController.text.trim();

    if (userMessage.isEmpty) {
      // C.AI Style Continue: If empty, remove trailing system errors if any, and fetch AI response.
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

    await _getAIResponse();
  }

  Future<void> _regenerateResponse() async {
    if (_isLoading || _messages.isEmpty) return;

    // Check if the last message is from assistant or system (error)
    if (_messages.last['role'] == 'assistant' ||
        _messages.last['role'] == 'system') {
      _safeSetState(() {
        _messages.removeLast(); // Remove the old response
      });
      await _getAIResponse();
    }
  }

  Future<void> _getAIResponse() async {
    _safeSetState(() {
      _isLoading = true;
    });
    _scrollToBottom();

    // 1. Build Structured Summary Recap
    String? summaryPrompt;
    if (_summaries.isNotEmpty) {
      summaryPrompt = "[CONVERSATION RECAP]\n";
      final sortedKeys = _summaries.keys.toList()..sort();
      for (var key in sortedKeys) {
        summaryPrompt =
            "${summaryPrompt!}- Messages ${key + 1}-${key + 20}: ${_summaries[key]}\n";
      }
    }

    // 2. Prepare recent messages (History Limit)
    List<Map<String, String>> fullHistory = _messages
        .where((m) => m['content'] != null && m['role'] != 'system')
        .map(
          (m) => {
            'role': m['role'] as String,
            'content': m['content'] as String,
          },
        )
        .toList();

    // Optimization: Only send the last 4 messages (2 turns) if we have a summary recap
    List<Map<String, String>> aiMessages;
    if (summaryPrompt != null && fullHistory.length > 4) {
      aiMessages = fullHistory.sublist(fullHistory.length - 4);
    } else {
      aiMessages = fullHistory;
    }

    // Inject System Note if present
    if (_systemNoteController.text.trim().isNotEmpty) {
      aiMessages.insert(0, {
        'role': 'system',
        'content': _systemNoteController.text.trim(),
      });
    }

    // If the history ends with the assistant, we must supply a user prompt
    // to satisfy strict API constraints (like Gemini) and instruct the model to continue.
    if (aiMessages.isNotEmpty && aiMessages.last['role'] == 'assistant') {
      aiMessages.add({'role': 'user', 'content': '[Continue]'});
    }

    // Get language from settings or use default
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || _isDisposed) return;
    String language = prefs.getString('app_language') ?? 'Indonesian';

    try {
      final response = await _aiService.sendMessage(
        provider: widget.provider,
        messages: aiMessages,
        botId: widget.bot['id'],
        language: language,
        summary: summaryPrompt,
      );

      if (!mounted || _isDisposed) return;

      bool shouldStartTyping = false;
      int partsLength = 0;

      _safeSetState(() {
        _isLoading = false;
        final aiTimestamp = DateTime.now().toIso8601String();

        if (response != null &&
            response['error'] != true &&
            response['choices'] != null) {
          final aiContent = response['choices'][0]['message']['content'];
          if (aiContent != null && (aiContent as String).isNotEmpty) {
            final parts = aiContent
                .split('\n\n')
                .where((s) => s.trim().isNotEmpty)
                .toList();
            _messages.add({
              'role': 'assistant',
              'content': aiContent,
              'timestamp': aiTimestamp,
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

      if (shouldStartTyping) {
        _startTypingEffect(partsLength);
      }
    } catch (e) {
      if (!mounted || _isDisposed) return;
      _safeSetState(() {
        _isLoading = false;
        _addSystemError(DateTime.now().toIso8601String());
      });
    }

    // Save to local storage only if not handled by typing effect loop
    if (!_isTypingEffectActive) {
      await _localChatService.saveChat(widget.bot['id'], _messages);
      _generateSummaries();
    }
    _scrollToBottom();
  }

  Future<void> _startTypingEffect(int totalParts) async {
    _safeSetState(() {
      _isTypingEffectActive = true;
    });

    for (int i = 1; i < totalParts; i++) {
      await Future.delayed(
        const Duration(milliseconds: 500),
      ); // Natural typing pause
      _scrollToBottom(); // Scroll to ensure typing indicator is visible

      await Future.delayed(
        const Duration(milliseconds: 1500),
      ); // Simulated typing time

      if (!mounted || _isDisposed) return;

      _safeSetState(() {
        _messages.last['visible_parts'] = i + 1;
        if (i == totalParts - 1) {
          _messages.last.remove('is_typing_next');
          _isTypingEffectActive = false;
        }
      });

      // Save state progressively
      await _localChatService.saveChat(widget.bot['id'], _messages);
      _scrollToBottom();
    }

    // Trigger bulk summaries after animation completes
    _generateSummaries();
  }

  Future<void> _showBondStats() async {
    final authService = AuthService();
    final token = await authService.getToken();
    if (token == null || !mounted || _isDisposed) return;

    final botId = widget.bot['id'];

    Map<String, dynamic>? bondData;
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/bots/bond/$botId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        bondData = jsonDecode(response.body);
      }
    } catch (_) {}

    if (!mounted || _isDisposed) return;

    final hearts = bondData?['bond_hearts'] ?? widget.bot['bond_hearts'] ?? 0;
    final xp = bondData?['xp'] ?? 0;
    final xpInto = bondData?['xp_into_level'] ?? 0;
    final xpPer = bondData?['xp_per_level'] ?? 5;
    final progress = bondData != null
        ? (bondData['progress_percent'] as num) / 100.0
        : 0.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: BoxDecoration(
            color: _surfaceBackground(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Avatar + name
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
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Large heart + level display
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
                        style: const TextStyle(
                          color: Color(0xFF135ACF),
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
                      const Text(
                        'Bond Level',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        'Lv. $hearts',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF135ACF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // XP Progress Bar
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
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
      },
    );
  }

  void _addSystemError(String timestamp, {int? statusCode, dynamic rawError}) {
    String errorMsg = 'Error: Failed to get response from ${widget.provider}.';

    if (statusCode == 429) {
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
        // Detect if the error is an HTML page (e.g. 404/405 from Nginx/Laravel)
        if (errStr.trim().toLowerCase().startsWith('<!doctype html') ||
            errStr.toLowerCase().contains('<html')) {
          return '${statusCode != null ? '[$statusCode] ' : ''}Server returned an HTML error page. Endpoint might be incorrect or unavailable.';
        }
        return '${statusCode != null ? '[$statusCode] ' : ''}$errStr';
      }
      return 'Unknown Error';
    }

    String? errType;
    String? errMessage;
    String? errCode;

    // 1. Direct "message" at root (HordeAI, MistralAI)
    if (rawError.containsKey('message') && rawError['message'] is String) {
      errMessage = rawError['message'];
    }

    // 2. "detail" at root (Chutes)
    if (rawError.containsKey('detail') && rawError['detail'] is String) {
      errMessage ??= rawError['detail'];
    }

    // 3. "status" / "error" at root (Nano GPT alternate)
    if (rawError.containsKey('error') && rawError['error'] is String) {
      errMessage ??= rawError['error'];
    }

    // 4. "error" object
    if (rawError.containsKey('error') &&
        rawError['error'] is Map<String, dynamic>) {
      final eObj = rawError['error'] as Map<String, dynamic>;
      if (eObj.containsKey('message') && eObj['message'] is String)
        errMessage ??= eObj['message'];
      if (eObj.containsKey('type') && eObj['type'] is String)
        errType ??= eObj['type'];
      if (eObj.containsKey('code')) errCode ??= eObj['code'].toString();
    }

    // 5. OpenRouter: {error: {code, message}} via response object
    if (rawError.containsKey('response') &&
        rawError['response'] is Map<String, dynamic>) {
      final resObj = rawError['response'] as Map<String, dynamic>;
      if (resObj.containsKey('error') &&
          resObj['error'] is Map<String, dynamic>) {
        final eObj = resObj['error'] as Map<String, dynamic>;
        if (eObj.containsKey('message') && eObj['message'] is String)
          errMessage ??= eObj['message'];
        if (eObj.containsKey('code')) errCode ??= eObj['code'].toString();
      }
    }

    // Assign fallback types/codes from root
    if (rawError.containsKey('error_type') && rawError['error_type'] is String)
      errType ??= rawError['error_type'];
    if (rawError.containsKey('type') &&
        rawError['type'] is String &&
        rawError['type'] != 'error')
      errType ??= rawError['type'];
    if (rawError.containsKey('code') && rawError['code'] is String)
      errCode ??= rawError['code'];
    if (rawError.containsKey('rc') && rawError['rc'] is String)
      errCode ??= rawError['rc'];

    // If we managed to parse something:
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

    // Fallback: Dump JSON
    try {
      final encoder = const JsonEncoder.withIndent('  ');
      return '${statusCode != null ? '[$statusCode]\\n' : ''}```json\\n${encoder.convert(rawError)}\\n```';
    } catch (_) {
      return '${statusCode != null ? '[$statusCode]\\n' : ''}$rawError';
    }
  }

  void _showStudentBio() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        decoration: BoxDecoration(
          color: _surfaceBackground(context),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey[300],
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
                        color: Colors.grey[600],
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
                                color: Colors.grey[600],
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

                            // Helper to find regex
                            String? findMatch(String pattern) {
                              final regExp = RegExp(
                                pattern,
                                caseSensitive: false,
                                multiLine: true,
                              );
                              final match = regExp.firstMatch(personality);
                              if (match != null && match.groupCount >= 1) {
                                // Extract and strip formatting like quotes or asterisks if any
                                String val = match.group(1)!.trim();
                                val = val
                                    .replaceAll(
                                      RegExp('^["\'*]+|["\'*]+\$'),
                                      '',
                                    )
                                    .trim();
                                if (val.endsWith(','))
                                  val = val.substring(0, val.length - 1).trim();
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
                                findMatch(r'Age\s*[:\-]\s*(.+)$') ??
                                '*Unknown*';
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
                                    width: 100,
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
                                        color: _isDarkMode(context)
                                            ? Colors.grey[300]
                                            : Colors.grey[800],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageOptions(int index, String content) {
    final bool isLastMessage = index == _messages.length - 1;
    final String role = _messages[index]['role'] ?? '';
    // Can regenerate if it's the last message and it's NOT from the user
    final bool canRegenerate =
        isLastMessage && (role == 'assistant' || role == 'system');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (canRegenerate) ...[
              // Regenerate Response option
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE3F2FD),
                  child: Icon(Icons.refresh_rounded, color: Color(0xFF1976D2)),
                ),
                title: const Text(
                  'Regenerate Response',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Retry getting a new answer from the AI',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _regenerateResponse();
                },
              ),
              const Divider(height: 1),
            ],
            // Rewind option
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(
                  Icons.fast_rewind_rounded,
                  color: Color(0xFFE65100),
                ),
              ),
              title: Text(
                tr('chat_rewind_title'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                tr('chat_rewind_subtitle'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                // Keep messages 0..index (inclusive), remove everything after
                final trimmed = _messages.sublist(0, index + 1);

                _safeSetState(() {
                  _messages = trimmed;
                  _summaries.removeWhere((key, value) => key >= trimmed.length);
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
            // Copy option
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFF0F5FF),
                child: Icon(Icons.copy_rounded, color: Color(0xFF135ACF)),
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
            // Edit option
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.edit_rounded, color: Color(0xFF2E7D32)),
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
        // TXT format
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
      final fileName = 'BlueTalk_Chat_${safeName}_$dateStr.$format';

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

  /// Returns the best available Download directory across Android versions.
  /// - Android ≤10: WRITE_EXTERNAL_STORAGE granted → uses external /Download
  /// - Android 11+: permission always denied → falls back to getDownloadsDirectory()
  /// - Ultimate fallback: app documents directory
  Future<Directory> _getDownloadDir() async {
    Directory? baseDir;
    if (Platform.isAndroid) {
      // Construction for public Download folder on Android
      baseDir = Directory('/storage/emulated/0/Download/BlueTalk');
    } else {
      baseDir = await getDownloadsDirectory();
      if (baseDir != null) {
        baseDir = Directory('${baseDir.path}/BlueTalk');
      }
    }

    if (baseDir != null && !await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    return baseDir ?? await getApplicationDocumentsDirectory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _pageBackground(context),
        elevation: 0,
        leadingWidth: 40,
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
                          widget.bot['name'],
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
                            child: Text('🎂', style: TextStyle(fontSize: 14)),
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
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '${widget.bot['bond_hearts'] ?? 0}',
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
              if (value == 'export_txt') {
                await _exportChat('txt');
              } else if (value == 'export_json') {
                await _exportChat('json');
              } else if (value == 're_summary') {
                _safeSetState(() => _summaries.clear());
                await _localChatService.saveSummaries(
                  widget.bot['id'],
                  _summaries,
                );
                _generateSummaries();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Re-generating summaries...')),
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
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'export_txt',
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: Colors.black54,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('Export as TXT'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'export_json',
                child: Row(
                  children: [
                    Icon(
                      Icons.data_object_outlined,
                      color: Colors.black54,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('Export as JSON'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 're_summary',
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.black54,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text('Re-Summary'),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr('chat_delete_confirm'),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        color: _pageBackground(context),
        child: Column(
          children: [
            if (_isSummarizing && _summaryProgress >= 0.0)
              LinearProgressIndicator(
                value: _summaryProgress,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF135ACF),
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
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              msg['content'],
                              style: const TextStyle(
                                color: Colors.red,
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
                              content,
                              timestamp,
                              index,
                              visibleParts: msg['visible_parts'] as int?,
                              isTypingNext: msg['is_typing_next'] == true,
                            );

                      return GestureDetector(
                        onLongPress: () => _showMessageOptions(index, content),
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
                        backgroundColor: const Color(0xFF135ACF),
                        onPressed: _scrollToBottom,
                        child: const Icon(
                          Icons.arrow_downward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
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
      _isDarkMode(context) ? Colors.black : Colors.white;

  Color _surfaceBackground(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF0D0D0D) : Colors.white;

  Color _surfaceAltBackground(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF141414) : const Color(0xFFF0F5FF);

  Color _titleColor(BuildContext context) =>
      _isDarkMode(context) ? Colors.white : const Color(0xFF4A5568);

  Color _subtitleColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFFA0AEC0) : const Color(0xFF4A5568);

  TextStyle _bondCountHeaderStyle(BuildContext context) {
    return TextStyle(
      color: _isDarkMode(context)
          ? const Color(0xFF79A9F1)
          : const Color(0xFF135ACF),
      fontWeight: FontWeight.w800,
      fontSize: 12,
      shadows: const [
        Shadow(color: Colors.white, offset: Offset(1, 0)),
        Shadow(color: Colors.white, offset: Offset(-1, 0)),
        Shadow(color: Colors.white, offset: Offset(0, 1)),
        Shadow(color: Colors.white, offset: Offset(0, -1)),
      ],
    );
  }

  Color _botBubbleBackground(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF1A1A1A) : const Color(0xFF414D66);

  Color _fieldBorderColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF2A2A2A) : Colors.grey.shade300;

  Color _hintColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF7A869A) : Colors.grey.shade400;

  String _formatMessageTime(DateTime? dt) {
    if (dt == null) return "";
    return '${DateFormat('MMMM d').format(dt)} at ${DateFormat('h:mm a').format(dt)}';
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.bot['name'],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _titleColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _botBubbleBackground(context),
                  borderRadius: BorderRadius.only(
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
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF5A8DEE),
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
                      data: content,
                      selectable: false,
                      extensionSet: md.ExtensionSet(
                        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                        <md.InlineSyntax>[
                          md.EmojiSyntax(),
                          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                        ],
                      ),
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: Colors.white, fontSize: 12),
                        strong: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        em: const TextStyle(
                          color: Color(0xDBDBDBDB),
                          fontStyle: FontStyle.italic,
                        ),
                        listBullet: const TextStyle(color: Colors.white),
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
    String content,
    DateTime? timestamp,
    int index, {
    int? visibleParts,
    bool isTypingNext = false,
  }) {
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
            backgroundColor: _parseColor(widget.bot['color']),
            backgroundImage: widget.bot['image_url'] != null
                ? NetworkImage(widget.bot['image_url'])
                : null,
            child: widget.bot['image_url'] == null
                ? Text(
                    widget.bot['name'][0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
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
                      widget.bot['name'],
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
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
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
                            data: part,
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
                              p: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1.3,
                              ),
                              strong: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              em: const TextStyle(
                                color: Color(0xDBDBDBDB),
                                fontStyle: FontStyle.italic,
                              ),
                              code: const TextStyle(
                                color: Color(0xFFB8D8F8),
                                backgroundColor: Colors.black26,
                                fontSize: 13,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              listBullet: const TextStyle(color: Colors.white),
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
            style: TextStyle(
              color: _isDarkMode(context) ? Colors.white : Colors.black87,
              fontSize: 13,
            ),
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

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: _surfaceBackground(context),
        border: Border(top: BorderSide(color: _fieldBorderColor(context))),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _safeSetState(
                    () => _isSystemNoteOpen = !_isSystemNoteOpen,
                  ),
                  child: Icon(
                    _isSystemNoteOpen
                        ? Icons.sticky_note_2
                        : Icons.sticky_note_2_outlined,
                    color: _isSystemNoteOpen
                        ? const Color(0xFF135ACF)
                        : _subtitleColor(context),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _surfaceBackground(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _fieldBorderColor(context)),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '${tr('tab_chat')} ${widget.bot['name']}',
                        hintStyle: TextStyle(
                          color: _hintColor(context),
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) {
                        if (!_isTypingEffectActive) _sendMessage();
                      },
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _isTypingEffectActive ? null : _sendMessage,
                  child: Icon(
                    Icons.send_rounded,
                    color: _isTypingEffectActive
                        ? _subtitleColor(context)
                        : const Color(0xFF135ACF),
                    size: 28,
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
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.white70,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
