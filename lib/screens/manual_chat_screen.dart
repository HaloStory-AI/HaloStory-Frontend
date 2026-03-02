import 'package:flutter/material.dart';
import '../services/local_create_service.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:intl/intl.dart';

class ManualChatScreen extends StatefulWidget {
  final Map<String, dynamic> bot;

  const ManualChatScreen({super.key, required this.bot});

  @override
  State<ManualChatScreen> createState() => _ManualChatScreenState();
}

class _ManualChatScreenState extends State<ManualChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final LocalCreateService _localCreateService = LocalCreateService();
  
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await _localCreateService.loadDialogue(widget.bot['id']);
    if (data != null && data['messages'] != null) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(data['messages']);
      });
      _scrollToBottom();
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

  Future<void> _addMessage(String role) async {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text.trim();
    _messageController.clear();

    final timestamp = DateTime.now().toIso8601String();
    setState(() {
      _messages.add({'role': role, 'content': content, 'timestamp': timestamp});
    });
    _scrollToBottom();

    await _localCreateService.saveDialogue(
      widget.bot['id'], 
      _messages, 
      widget.bot
    );
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
                const Text('Manual Creator Mode', style: TextStyle(fontSize: 10, color: Colors.orange)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.grey),
            onPressed: () async {
              await _localCreateService.deleteDialogue(widget.bot['id']);
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
                  final timestamp = msg['timestamp'] != null ? DateTime.parse(msg['timestamp']) : null;

                  if (isUser) {
                    return _buildUserBubble(msg['content'], timestamp);
                  } else {
                    return _buildBotBubble(msg['content'], timestamp);
                  }
                },
              ),
            ),
            _buildManualInputArea(),
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
                    color: Color(0xFF414D66),
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

  Widget _buildManualInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type manual dialogue...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              maxLines: null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addMessage('assistant'),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Penerima'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _addMessage('user'),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Pengirim'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF135ACF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
