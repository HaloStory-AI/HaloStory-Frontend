import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/local_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:intl/intl.dart';

class ChatDetailScreen extends StatefulWidget {
  final Map<String, dynamic> bot;
  final String provider;

  const ChatDetailScreen({super.key, required this.bot, required this.provider});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AIService _aiService = AIService();
  final LocalChatService _localChatService = LocalChatService();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
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
      _messages.add({'role': 'user', 'content': userMessage, 'timestamp': timestamp});
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
    List<Map<String, String>> aiMessages = _messages.map((m) => {
      'role': m['role'] as String,
      'content': m['content'] as String,
    }).toList();

    // Get model & language from settings or use default
    final prefs = await SharedPreferences.getInstance();
    String language = prefs.getString('app_language') ?? 'Indonesian';
    
    // Bug Fix 2: Handle Groq (System) model properly
    // If provider is Groq (System), passing an empty model or wrong model causes 422
    // We let the backend handle the model for Groq (System) by sending a placeholder or constant
    String model = prefs.getString('model_${widget.provider}') ?? ''; 
    if (widget.provider == 'Groq (System)' && model.isEmpty) {
      model = 'default'; // Backend knows to use GROQ_SYSTEM_MODEL from .env
    } else if (model.isEmpty) {
      model = 'openai/gpt-oss-20b'; // Standard fallback for others
    }
    final response = await _aiService.sendMessage(
      provider: widget.provider,
      model: model,
      messages: aiMessages,
      botId: widget.bot['id'],
      language: language,
    );

    setState(() {
      _isLoading = false;
      final aiTimestamp = DateTime.now().toIso8601String();
      if (response != null && response['choices'] != null) {
        final aiContent = response['choices'][0]['message']['content'];
        _messages.add({'role': 'assistant', 'content': aiContent, 'timestamp': aiTimestamp});
      } else {
        _messages.add({
          'role': 'system', 
          'content': 'Error: Failed to get response from ${widget.provider}.',
          'timestamp': aiTimestamp
        });
      }
    });

    // Save to local storage
    await _localChatService.saveChat(widget.bot['id'], _messages);
    _scrollToBottom();
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
              backgroundImage: widget.bot['image_url'] != null ? NetworkImage(widget.bot['image_url']) : null,
              child: widget.bot['image_url'] == null 
                ? Text(widget.bot['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14))
                : null,
            ),
            const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.bot['name'],
                      style: const TextStyle(color: Color(0xFF4A5568), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (widget.bot['bond_hearts'] != null && widget.bot['bond_hearts'] > 0)
                      Row(
                        children: List.generate(
                          (widget.bot['bond_hearts'] as num).toInt().clamp(1, 10), 
                          (i) => const Padding(
                            padding: EdgeInsets.only(right: 2),
                            child: Icon(Icons.favorite, color: Colors.pinkAccent, size: 10),
                          )
                        ),
                      ),
                  ],
                ),
                if (_isBirthday(widget.bot['birthday']))
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('🎂', style: TextStyle(fontSize: 14)),
                  ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.grey),
            onPressed: () async {
              await _localChatService.deleteChat(widget.bot['id']);
              setState(() => _messages = []);
            },
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';
                  final isSystem = msg['role'] == 'system';

                  if (isSystem) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(msg['content'], style: const TextStyle(color: Colors.red, fontSize: 12)),
                      ),
                    );
                  }

                  final timestamp = msg['timestamp'] != null ? DateTime.parse(msg['timestamp']) : null;

                  if (isUser) {
                    return _buildUserBubble(msg['content'], timestamp);
                  } else {
                    return _buildBotBubble(msg['content'], timestamp);
                  }
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
      try { return Color(int.parse(color)); } catch (_) { return Colors.blueGrey; }
    }
    return Colors.blueGrey;
  }

  String _formatMessageTime(DateTime? dt) {
    if (dt == null) return "";
    return DateFormat('MMMM d').format(dt) + " at " + DateFormat('h:mm a').format(dt);
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
            backgroundImage: widget.bot['image_url'] != null ? NetworkImage(widget.bot['image_url']) : null,
            child: widget.bot['image_url'] == null 
              ? Text(widget.bot['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))
              : null,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.bot['name'], 
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                child: MarkdownBody(
                  data: content,
                  selectable: true,
                  extensionSet: md.ExtensionSet(
                    md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                    <md.InlineSyntax>[
                      md.EmojiSyntax(),
                      ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes
                    ],
                  ),
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(color: Colors.white, fontSize: 15),
                    strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    em: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
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
    // Split content by newlines to create "divided" messages as requested
    final parts = content.split('\n').where((s) => s.trim().isNotEmpty).toList();
    if (parts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _parseColor(widget.bot['color']),
            backgroundImage: widget.bot['image_url'] != null ? NetworkImage(widget.bot['image_url']) : null,
            child: widget.bot['image_url'] == null 
              ? Text(widget.bot['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))
              : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (timestamp != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      _formatMessageTime(timestamp),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ),
                Text(
                  widget.bot['name'], 
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF414D66), // Dark grey-blue
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(0),
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                    child: MarkdownBody(
                      data: content,
                      selectable: true,
                      extensionSet: md.ExtensionSet(
                        md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                        <md.InlineSyntax>[
                          md.EmojiSyntax(),
                          ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes
                        ],
                      ),
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: Colors.white, fontSize: 15),
                        strong: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        em: const TextStyle(color: Colors.white, fontStyle: FontStyle.italic),
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
                        h1: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        h2: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        h3: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
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

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
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
                    hintText: 'Message ${widget.bot['name']}',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _sendMessage,
              child: const Icon(Icons.send_rounded, color: Colors.grey, size: 28),
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

class _DotAnimState extends State<_DotAnim> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

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
        decoration: const BoxDecoration(color: Colors.white70, shape: BoxShape.circle),
      ),
    );
  }
}
