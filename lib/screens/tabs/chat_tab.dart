import 'package:flutter/material.dart';

class ChatTab extends StatelessWidget {
  const ChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy chat data based on the image provided
    final List<Map<String, dynamic>> chatData = [
      {
        'name': 'Samehadaku Official',
        'message': 'Champignon no Majo Episode 9...',
        'time': '04:08',
        'unread': '104',
        'icon': 'S',
        'isImage': false,
        'color': Colors.red,
      },
      {
        'name': 'Kei-chan',
        'message': 'Hah... Jadi kau pikir aku akan langsung be...',
        'time': 'Thu',
        'unread': '',
        'imageUrl': 'https://i.pravatar.cc/150?u=kei-chan',
        'isImage': true,
      },
      {
        'name': 'Foho Meyra Ningsih',
        'message': 'Foho Meyra Ningsih joined Telegram',
        'time': 'Wed',
        'unread': '1',
        'icon': 'FN',
        'isImage': false,
        'color': Colors.orange,
      },
      // Adding extra dummy data to demonstrate vertical scroll
      {
        'name': 'BlueTalk Support',
        'message': 'Welcome to the future of chatting!',
        'time': 'Mon',
        'unread': '',
        'icon': 'BT',
        'isImage': false,
        'color': const Color(0xFF135ACF),
      },
      {
        'name': 'Group Chat',
        'message': 'Alice: Check out the new design!',
        'time': '12:45',
        'unread': '5',
        'icon': 'G',
        'isImage': false,
        'color': Colors.green,
      },
    ];

    return ListView.separated(
      itemCount: chatData.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        indent: 80,
        endIndent: 16,
        color: Color(0xFFE0E0E0),
      ),
      itemBuilder: (context, index) {
        final chat = chatData[index];
        return InkWell(
          onTap: () {
            // Handle chat click
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar Column
                Stack(
                  children: [
                    Container(
                      width: 55,
                      height: 55,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: chat['isImage'] ? Colors.transparent : chat['color'],
                        image: chat['isImage'] 
                          ? DecorationImage(
                              image: NetworkImage(chat['imageUrl']),
                              fit: BoxFit.cover,
                            )
                          : null,
                      ),
                      child: chat['isImage'] 
                        ? null 
                        : Center(
                            child: Text(
                              chat['icon'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                    ),
                    if (chat['name'] == 'Samehadaku Official')
                       Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFF135ACF),
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '1M+',
                              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                  ],
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
                              chat['name'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF212121),
                              ),
                            ),
                          ),
                          Text(
                            chat['time'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              chat['message'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                          if (chat['unread'].isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF135ACF).withOpacity(0.8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                chat['unread'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
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
