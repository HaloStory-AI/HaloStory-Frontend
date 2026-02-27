import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/local_chat_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
      _isLoading = true;
    });
    _scrollToBottom();

    // Prepare messages for AI (Role-based)
    List<Map<String, String>> aiMessages = [];
    
    // Add system instruction if available
    final systemInstruction = widget.bot['system_instruction'];
    if (systemInstruction != null && (systemInstruction as String).isNotEmpty) {
      aiMessages.add({
        'role': 'system',
        'content': systemInstruction,
      });
    }

    aiMessages.addAll(_messages.map((m) => {
      'role': m['role'] as String,
      'content': m['content'] as String,
    }));

    // Get model from settings or use default
    final prefs = await SharedPreferences.getInstance();
    String model = prefs.getString('model_${widget.provider}') ?? 'llama-3.3-70b-versatile'; 

    final response = await _aiService.sendMessage(
      provider: widget.provider,
      model: model,
      messages: aiMessages,
    );

    setState(() {
      _isLoading = false;
      if (response != null && response['choices'] != null) {
        final aiContent = response['choices'][0]['message']['content'];
        _messages.add({'role': 'assistant', 'content': aiContent});
      } else {
        _messages.add({
          'role': 'system', 
          'content': 'Error: Failed to get response from ${widget.provider}.'
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
            Text(
              widget.bot['name'],
              style: const TextStyle(color: Color(0xFF4A5568), fontSize: 18, fontWeight: FontWeight.bold),
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

                  if (isUser) {
                    return _buildUserBubble(msg['content']);
                  } else {
                    return _buildBotBubble(msg['content']);
                  }
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: LinearProgressIndicator(),
              ),
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

  Widget _buildUserBubble(String content) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
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
            child: Text(
              content,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotBubble(String content) {
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
                Text(
                  widget.bot['name'], 
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)
                ),
                const SizedBox(height: 4),
                ...parts.asMap().entries.map((entry) {
                  int i = entry.key;
                  String part = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF414D66), // Dark grey-blue from image
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(i == 0 ? 0 : 12),
                        topRight: const Radius.circular(12),
                        bottomLeft: const Radius.circular(12),
                        bottomRight: const Radius.circular(12),
                      ),
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                      child: Text(
                        part,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  );
                }).toList(),
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
