import 'package:flutter/material.dart';

class CreateTab extends StatelessWidget {
  const CreateTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy dialogue data based on the chat tab structure but for creating own dialogues
    final List<Map<String, dynamic>> dialogueData = [
      {
        'name': 'Samehadaku Official',
        'message': 'Champignon no Majo Episode 9...',
        'time': '04:08',
        'icon': 'S',
        'isImage': false,
        'color': Colors.red,
      },
      {
        'name': 'Kei-chan',
        'message': 'Hah... Jadi kau pikir aku akan langsung be...',
        'time': 'Thu',
        'imageUrl': 'https://i.pravatar.cc/150?u=kei-chan',
        'isImage': true,
      },
      {
        'name': 'Foho Meyra Ningsih',
        'message': 'Foho Meyra Ningsih joined Telegram',
        'time': 'Wed',
        'icon': 'FN',
        'isImage': false,
        'color': Colors.orange,
      },
      {
        'name': 'BlueTalk Support',
        'message': 'Welcome to the future of chatting!',
        'time': 'Mon',
        'icon': 'BT',
        'isImage': false,
        'color': const Color(0xFF135ACF),
      },
      {
        'name': 'Group Chat',
        'message': 'Alice: Check out the new design!',
        'time': '12:45',
        'icon': 'G',
        'isImage': false,
        'color': Colors.green,
      },
    ];

    return ListView.separated(
      itemCount: dialogueData.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        indent: 80,
        endIndent: 16,
        color: Color(0xFFE0E0E0),
      ),
      itemBuilder: (context, index) {
        final item = dialogueData[index];
        return InkWell(
          onTap: () {
            // Logic for creating/editing this dialogue
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar Column
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item['isImage'] ? Colors.transparent : item['color'],
                    image: item['isImage'] 
                      ? DecorationImage(
                          image: NetworkImage(item['imageUrl']),
                          fit: BoxFit.cover,
                        )
                      : null,
                  ),
                  child: item['isImage'] 
                    ? null 
                    : Center(
                        child: Text(
                          item['icon'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                ),
                const SizedBox(width: 16),
                // Text Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              item['name'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                            ),
                          ),
                          Text(
                            item['time'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['message'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
