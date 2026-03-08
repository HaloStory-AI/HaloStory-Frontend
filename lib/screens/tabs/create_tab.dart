import 'package:flutter/material.dart';
import '../../services/local_create_service.dart';
import '../../services/bot_service.dart';
import '../manual_chat_screen.dart';

import '../../widgets/skeleton_loader.dart';

class CreateTab extends StatefulWidget {
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
  String _sortBy = 'Newest';
  bool _sortAscending = false;

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

    // Sort the list based on state
    if (_sortBy == 'Newest') {
      loaded.sort(
        (a, b) => (a['lastModified'] as DateTime).compareTo(
          b['lastModified'] as DateTime,
        ),
      );
    } else if (_sortBy == 'Name') {
      loaded.sort(
        (a, b) => (a['name'] as String).toLowerCase().compareTo(
          (b['name'] as String).toLowerCase(),
        ),
      );
    }

    if (!_sortAscending) {
      loaded = loaded.reversed.toList();
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
    _initData(force: true); // Force refresh bots when opening selection sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredBots = _availableBots.where((bot) {
              final name = (bot['name'] ?? '').toString().toLowerCase();
              final id = (bot['bot_id'] ?? bot['id'] ?? '')
                  .toString()
                  .toLowerCase();
              final query = searchQuery.toLowerCase();
              return name.contains(query) || id.contains(query);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Buat Kisah Manual',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (value) {
                            setModalState(() {
                              searchQuery = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Cariin murid kesayanganku...',
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.orange,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _isLoading && _availableBots.isEmpty
                        ? const ChatListSkeleton()
                        : (filteredBots.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_search_rounded,
                                        size: 64,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'lah... gaada?',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filteredBots.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final bot = filteredBots[index];
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: _parseColor(
                                          bot['color'],
                                        ),
                                        backgroundImage:
                                            bot['image_url'] != null
                                            ? NetworkImage(bot['image_url'])
                                            : null,
                                        child: bot['image_url'] == null
                                            ? Text(
                                                bot['name'][0].toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                ),
                                              )
                                            : null,
                                      ),
                                      title: Text(
                                        bot['name'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: const Text(
                                        'New Manual Session',
                                      ),
                                      trailing: const Icon(
                                        Icons.edit_note,
                                        color: Colors.orange,
                                      ),
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ManualChatScreen(bot: bot),
                                          ),
                                        ).then((_) => _initData());
                                      },
                                    );
                                  },
                                )),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        heroTag: 'create_fab',
        onPressed: _showAddDialogueSheet,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    // Header List Manual Chats (Duplikat dari chat_tab)
    final headerWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          Text(
            'Manual Chats (${_activeDialogues.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _initData();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Newest', child: Text('Newest')),
              const PopupMenuItem(value: 'Name', child: Text('Name')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _sortBy,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {
              setState(() {
                _sortAscending = !_sortAscending;
                _initData();
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                _sortAscending
                    ? Icons.keyboard_double_arrow_up_rounded
                    : Icons.keyboard_double_arrow_down_rounded,
                size: 20,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );

    if (_isLoading && _activeDialogues.isEmpty) {
      return Column(
        children: [
          headerWidget,
          const Divider(height: 1),
          const Expanded(child: ChatListSkeleton()),
        ],
      );
    }

    if (_activeDialogues.isEmpty) {
      return Column(
        children: [
          headerWidget,
          const Divider(height: 1),
          Expanded(
            child: ListView(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_note_rounded,
                        size: 100,
                        color: Colors.grey[200],
                      ),
                      const Text(
                        'Lah... gaada?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'buatlah MyKisah Sendiri :v.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _showAddDialogueSheet,
                        icon: const Icon(Icons.add),
                        label: const Text('Buat Dialog'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        headerWidget,
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: _activeDialogues.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 80, endIndent: 16),
            itemBuilder: (context, index) {
              final item = _activeDialogues[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _parseColor(item['color']),
                  backgroundImage: item['image_url'] != null
                      ? NetworkImage(item['image_url'])
                      : null,
                  child: item['image_url'] == null
                      ? Text(
                          item['name'][0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                title: Text(
                  item['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  item['lastMessage'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManualChatScreen(bot: item),
                    ),
                  ).then((_) => _initData());
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
