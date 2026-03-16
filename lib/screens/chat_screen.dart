import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../services/ai_service.dart';
import '../services/local_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:intl/intl.dart';

import '../services/localization_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadHistory();
    if (widget.provider == 'System' && !_hasShownSystemAiWarning) {
      _showSystemAiWarning();
      _hasShownSystemAiWarning = true;
    }
  }

  void _showSystemAiWarning() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
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
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF135ACF),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                tr('system_notice_content'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4A5568),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF0F5FF),
                  foregroundColor: const Color(0xFF135ACF),
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
    setState(() {
      _messages = history;
    });
    _scrollToBottom();

    // Jika ada pesan awal (dari reply story), kirim langsung
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _messageController.text = widget.initialMessage!;
      _sendMessage();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isLoading) return;

    final userMessage = _messageController.text.trim();
    _messageController.clear();

    final timestamp = DateTime.now().toIso8601String();
    setState(() {
      _messages.add({
        'role': 'user',
        'content': userMessage,
        'timestamp': timestamp,
      });
      _isLoading = true;
    });
    _scrollToBottom();

    // Bug Fix 1: Remove trailing system error messages before sending
    // If the last message was a system error, we should not include it in the retry
    while (_messages.isNotEmpty && _messages.last['role'] == 'system') {
      _messages.removeLast();
    }

    // Prepare messages for AI (Role-based)
    // We no longer inject system instruction here; the backend builds it from latest_sys.md
    // Filter out any messages with null content (old corrupted saves) before sending
    List<Map<String, String>> aiMessages = _messages
        .where((m) => m['content'] != null)
        .map(
          (m) => {
            'role': m['role'] as String,
            'content': m['content'] as String,
          },
        )
        .toList();

    // Get language from settings or use default
    final prefs = await SharedPreferences.getInstance();
    String language = prefs.getString('app_language') ?? 'Indonesian';
    final response = await _aiService.sendMessage(
      provider: widget.provider,
      messages: aiMessages,
      botId: widget.bot['id'],
      language: language,
    );

    setState(() {
      _isLoading = false;
      final aiTimestamp = DateTime.now().toIso8601String();
      if (response != null && response['choices'] != null) {
        final aiContent = response['choices'][0]['message']['content'];
        // Guard: backend should never return null here after sanitization,
        // but defend on the client side too.
        if (aiContent != null && (aiContent as String).isNotEmpty) {
          _messages.add({
            'role': 'assistant',
            'content': aiContent,
            'timestamp': aiTimestamp,
          });
        } else {
          // Treat null/empty AI content as an error
          String errorMsg =
              'Error: Failed to get response from ${widget.provider}.';
          if (widget.provider == 'System') {
            errorMsg = tr('error_busy');
          }
          _messages.add({
            'role': 'system',
            'content': errorMsg,
            'timestamp': aiTimestamp,
          });
        }
      } else {
        String errorMsg =
            'Error: Failed to get response from ${widget.provider}.';
        if (widget.provider == 'System') {
          errorMsg = tr('error_busy');
        }
        _messages.add({
          'role': 'system',
          'content': errorMsg,
          'timestamp': aiTimestamp,
        });
      }
    });

    // Save to local storage
    await _localChatService.saveChat(widget.bot['id'], _messages);
    _scrollToBottom();
  }

  void _showMessageOptions(int index, String content) {
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
                setState(() => _messages = trimmed);
                await _localChatService.saveChat(widget.bot['id'], _messages);
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
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 40,
        title: Row(
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
                      style: const TextStyle(color: Colors.white, fontSize: 14),
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
                        style: const TextStyle(
                          color: Color(0xFF4A5568),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
            Container(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Color(0xFFFBB6CE),
                    size: 38,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${widget.bot['bond_hearts'] ?? 0}',
                      style: const TextStyle(
                        color: Color(0xFF135ACF),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (value) async {
              if (value == 'export_txt') {
                await _exportChat('txt');
              } else if (value == 'export_json') {
                await _exportChat('json');
              } else if (value == 'delete') {
                await _localChatService.deleteChat(widget.bot['id']);
                setState(() => _messages = []);
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
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_sweep_outlined,
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
        color: Colors.white,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
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
                      ? _buildUserBubble(content, timestamp)
                      : _buildBotBubble(content, timestamp);

                  return GestureDetector(
                    onLongPress: () => _showMessageOptions(index, content),
                    child: bubble,
                  );
                },
              ),
            ),
            if (_isLoading) _buildTypingIndicator(),
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

  String _formatMessageTime(DateTime? dt) {
    if (dt == null) return "";
    return DateFormat('MMMM d').format(dt) +
        " at " +
        DateFormat('h:mm a').format(dt);
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
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF414D66),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(0),
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

  Widget _buildUserBubble(String content, DateTime? timestamp) {
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
                child: MarkdownBody(
                  data: content,
                  selectable: false, // Matikan agar tidak bentrok dengan context menu (Regenerate/Rewind)
                  extensionSet: md.ExtensionSet(
                    md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                    <md.InlineSyntax>[
                      md.EmojiSyntax(),
                      ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                    ],
                  ),
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(color: Colors.white, fontSize: 15),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotBubble(String content, DateTime? timestamp) {
    // Split content by double newlines to create separate chat bubbles
    final parts = content
        .split('\n\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return const SizedBox.shrink();

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
                // Display Name and Timestamp only once for the whole group
                Row(
                  children: [
                    Text(
                      widget.bot['name'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4A5568),
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
                // Build a bubble for each part
                ...parts.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String part = entry.value;
                  bool isFirst = idx == 0;

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: idx == parts.length - 1 ? 0 : 4,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFF414D66,
                        ), // Dark grey-blue based on reference
                        borderRadius: BorderRadius.only(
                          topLeft: isFirst
                              ? const Radius.circular(2)
                              : const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: const Radius.circular(12),
                          bottomRight: const Radius.circular(12),
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.65,
                        ),
                        child: MarkdownBody(
                          data: part,
                          selectable: false, // Sama seperti di bubble user
                          extensionSet: md.ExtensionSet(
                            md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                            <md.InlineSyntax>[
                              md.EmojiSyntax(),
                              ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                            ],
                          ),
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
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
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            listBullet: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
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
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '${tr('tab_chat')} ${widget.bot['name']}',
                        hintStyle: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: const Icon(
                    Icons.send_rounded,
                    color: Colors.grey,
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
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
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
