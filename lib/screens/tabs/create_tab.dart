import 'package:flutter/material.dart';
import '../../services/local_create_service.dart';
import '../../services/bot_service.dart';
import '../manual_chat_screen.dart';

import '../../widgets/skeleton_loader.dart';

class      CreateTab extends StatefulWidget {
  const CreateTab({super.key});

  @override
  State<CreateTab> createState() => _CreateTabState();
}

class _CreateTabState extends State<CreateTab> {
  final LocalCreateService _localCreateService = LocalCreateService();
  final BotService _botService = BotService();
  List<Map<String, dynamic>> _activeDialogues = [];
  List<Map<String, dynamic>> _availableBots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData({bool force = false}) async {
    // Parallel load
    final results = await Future.wait([
      _botService.getBots(forceRefresh: force),
      _localCreateService.getAllDialoguesMetadata(),
    ]);

    final bots = results[0] as List<Map<String, dynamic>>;
    final metadata = results[1] as List<Map<String, dynamic>>;
    
    // Sort by recentness
    metadata.sort((a, b) => (b['lastModified'] as DateTime).compareTo(a['lastModified'] as DateTime));

    List<Map<String, dynamic>> loaded = [];
    for (var meta in metadata) {
      final id = meta['id'];
      final fullData = await _localCreateService.loadDialogue(id);
      if (fullData != null) {
        final messages = List<Map<String, dynamic>>.from(fullData['messages']);
        final botMeta = Map<String, dynamic>.from(fullData['metadata']);
        
        if (messages.isNotEmpty) {
          loaded.add({
            ...botMeta,
            'lastMessage': messages.last['content'],
            'lastModified': meta['lastModified'],
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _availableBots = bots;
        _activeDialogues = loaded;
        _isLoading = false;
      });
    }
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

  void _showAddDialogueSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Manual Dialogue Creator', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                  SizedBox(height: 8),
                  Text('Create a conversation manually. No AI will respond here; you control both sides.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            Expanded(
              child: _isLoading && _availableBots.isEmpty
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
                          ? Text(bot['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white))
                          : null,
                      ),
                      title: Text(bot['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('New Manual Session'),
                      trailing: const Icon(Icons.edit_note, color: Colors.orange),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => ManualChatScreen(bot: bot)),
                        ).then((_) => _initData());
                      },
                    );
                  },
                ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => _initData(force: true),
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialogueSheet,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _activeDialogues.isEmpty) {
      return const ChatListSkeleton();
    }

    if (_activeDialogues.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.edit_note_rounded, size: 100, color: Colors.grey[200]),
                const Text('No Manual Dialogues', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('Create your own stories manually.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _showAddDialogueSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Dialogue'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      itemCount: _activeDialogues.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 80, endIndent: 16),
      itemBuilder: (context, index) {
        final item = _activeDialogues[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _parseColor(item['color']),
            backgroundImage: item['image_url'] != null ? NetworkImage(item['image_url']) : null,
            child: item['image_url'] == null ? Text(item['name'][0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
          ),
          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(item['lastMessage'], maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ManualChatScreen(bot: item)),
            ).then((_) => _initData());
          },
        );
      },
    );
  }
}
