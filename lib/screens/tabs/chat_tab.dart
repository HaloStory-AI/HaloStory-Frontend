import 'package:flutter/material.dart';
import '../../services/local_chat_service.dart';
import '../../services/bot_service.dart';
import '../chat_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../../widgets/skeleton_loader.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final LocalChatService _localChatService = LocalChatService();
  final BotService _botService = BotService();
  List<Map<String, dynamic>> _activeChats = [];
  List<Map<String, dynamic>> _availableBots = [];
  bool _isLoadingBots = true;
  bool _isLoadingChats = true;

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

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData({bool force = false}) async {
    setState(() {
      _isLoadingBots = true;
      _isLoadingChats = true;
    });

    // 1. Load bots first (Now very fast because of SharedPreferences cache in BotService)
    await _loadAvailableBots(force: force);
    
    // 2. Then load chats, so we can match them with the bot avatars/colors
    await _loadActiveChats();
  }

  Future<void> _handleRefresh() async {
    await _initData(force: true);
  }

  Future<void> _loadAvailableBots({bool force = false}) async {
    final bots = await _botService.getBots(forceRefresh: force);
    if (mounted) {
      setState(() {
        _availableBots = bots;
        _isLoadingBots = false;
      });
    }
  }

  Future<void> _loadActiveChats() async {
    final chatMetadata = await _localChatService.getAllChatMetadata();
    
    // Sort metadata by lastModified descending
    chatMetadata.sort((a, b) => (b['lastModified'] as DateTime).compareTo(a['lastModified'] as DateTime));

    List<Map<String, dynamic>> loadedChats = [];
    
    for (var meta in chatMetadata) {
      final id = meta['id'];
      final history = await _localChatService.loadChat(id);
      
      final bot = _availableBots.firstWhere(
        (b) => b['id'] == id, 
        orElse: () => {
          'id': id,
          'name': id,
          'avatar': null,
          'color': '0xFF607D8B',
        }
      );
      
      if (history.isNotEmpty) {
        loadedChats.add({
          ...bot,
          'lastMessage': history.last['content'],
          'time': _formatDateTime(meta['lastModified']), 
          'provider': 'Global Config',
          'lastModified': meta['lastModified'],
        });
      }
    }
    
    if (mounted) {
      setState(() {
        _activeChats = loadedChats;
        _isLoadingChats = false;
      });
    }
  }

  void _showAddChatSheet() {
    // Refresh bots from API to ensure new contacts appear
    // We don't await this so the sheet opens immediately with cached data
    _loadAvailableBots(force: true); 

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder( // Use StatefulBuilder for inner updates if needed
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Dialogue',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF135ACF),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Select a contact to start a new chat session. The AI engine will use your global default settings.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Select Contact / Bot',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoadingBots 
                      ? const ChatListSkeleton() 
                      : ListView.separated(
                        itemCount: _availableBots.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final bot = _availableBots[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _parseColor(bot['color']),
                              backgroundImage: bot['image_url'] != null ? NetworkImage(bot['image_url']) : null,
                              child: bot['image_url'] == null 
                                ? Text(
                                    (bot['name'] as String).isNotEmpty ? (bot['name'] as String)[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  )
                                : null,
                            ),
                            title: Text(bot['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(bot['description']),
                            trailing: const Icon(Icons.add_circle_outline, color: Color(0xFF135ACF)),
                            onTap: () async {
                              Navigator.pop(context);
                              final prefs = await SharedPreferences.getInstance();
                              final provider = prefs.getString('default_provider') ?? 'Groq (System)';
                              
                              if (!mounted) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatDetailScreen(bot: bot, provider: provider),
                                ),
                              ).then((_) => _loadActiveChats());
                            },
                          );
                        },
                      ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddChatSheet,
        backgroundColor: const Color(0xFF135ACF),
        child: const Icon(Icons.add_comment_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        // Visual Header from Image
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Colors.white,
          child: Row(
            children: [
              Text(
                'Chats (${_activeChats.length})', 
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: const Row(
                  children: [
                    Text('Newest', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF135ACF)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: const Icon(Icons.format_list_bulleted_rounded, size: 20, color: Color(0xFF135ACF)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoadingChats && _activeChats.isEmpty
              ? const ChatListSkeleton()
              : _activeChats.isEmpty 
                  ? _buildEmptyState() 
                  : _buildChatList(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return ListView( // Wrap in ListView to enable RefreshIndicator
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, size: 100, color: Colors.grey[300]),
              const SizedBox(height: 24),
              const Text('No Active Chats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('Start a new conversation with AI bots.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _showAddChatSheet,
                icon: const Icon(Icons.add),
                label: const Text('New Chat'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChatList() {
    final combinedChats = [..._activeChats]; // For now just active chats
    
    return ListView.separated(
      itemCount: combinedChats.length,
      padding: const EdgeInsets.symmetric(vertical: 0),
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        indent: 80,
        endIndent: 16,
        color: Color(0xFFE0E0E0),
      ),
      itemBuilder: (context, index) {
        final chat = combinedChats[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _parseColor(chat['color']),
            backgroundImage: chat['image_url'] != null ? NetworkImage(chat['image_url']) : null,
            child: chat['image_url'] == null 
              ? Text(
                  (chat['name'] as String).isNotEmpty ? (chat['name'] as String)[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                )
              : null,
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(chat['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(chat['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(chat['lastMessage'], maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
          onTap: () async {
            final prefs = await SharedPreferences.getInstance();
            final provider = prefs.getString('default_provider') ?? 'Groq (System)';
            
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(bot: chat, provider: provider),
              ),
            ).then((_) => _loadActiveChats());
          },
        );
      },
    );
  }
}
