import 'package:flutter/material.dart';

class ChatTab extends StatefulWidget {
  const ChatTab({super.key});

  @override
  State<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends State<ChatTab> {
  final List<Map<String, dynamic>> _activeChats = [];

  // Data bots from backend (simulated for now based on exploration)
  final List<Map<String, dynamic>> _availableBots = [
    {
      'id': 'Kei',
      'name': 'Kei Chan',
      'description': 'Tsundere AI',
      'avatar': 'K',
      'color': Colors.purple,
    },
    {
      'id': 'Tendou_Arisu',
      'name': 'Tendou Arisu',
      'description': 'Gamer AI',
      'avatar': 'A',
      'color': Colors.blue,
    },
  ];

  final List<String> _providers = [
    'Groq (System)',
    'Groq (Self)',
    'OpenAI',
    'Open Router',
    'Gemini',
    'Anthropic',
    'xAI',
  ];

  String _selectedProvider = 'Groq (System)';

  void _showAddChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Create New Dialogue',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF135ACF),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a contact to start a new chat session. The AI engine will use your global default settings.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Select Contact / Bot',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: _availableBots.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final bot = _availableBots[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: bot['color'],
                        child: Text(
                          bot['avatar'],
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(bot['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(bot['description']),
                      trailing: const Icon(Icons.add_circle_outline, color: Color(0xFF135ACF)),
                      onTap: () {
                        setState(() {
                          _activeChats.add({
                            ...bot,
                            'provider': 'Global Default', // Moved to settings
                            'lastMessage': 'Hello! Let\'s chat.',
                            'time': 'Just now',
                          });
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Maintain background from HomeScreen
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddChatSheet,
        backgroundColor: const Color(0xFF135ACF),
        child: const Icon(Icons.add_comment_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_activeChats.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 100,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            const Text(
              'No Active Chats',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Start a new conversation with AI bots.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _showAddChatSheet,
              icon: const Icon(Icons.add),
              label: const Text('New Chat'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(200, 50),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _activeChats.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        indent: 80,
        endIndent: 16,
        color: Color(0xFFE0E0E0),
      ),
      itemBuilder: (context, index) {
        final chat = _activeChats[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: chat['color'],
            child: Text(
              chat['avatar'],
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
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
              Text(
                chat['lastMessage'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF135ACF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  chat['provider'],
                  style: const TextStyle(fontSize: 10, color: Color(0xFF135ACF), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          onTap: () {
            // Navigate to actual chat screen
          },
        );
      },
    );
  }
}
