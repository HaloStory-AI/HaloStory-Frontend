import 'package:flutter/material.dart';
import '../../widgets/skeleton_loader.dart';
import '../../services/story_service.dart';
import '../story_view_screen.dart';

class StoriesTab extends StatefulWidget {
  const StoriesTab({super.key});

  @override
  State<StoriesTab> createState() => _StoriesTabState();
}

class _StoriesTabState extends State<StoriesTab> {
  final StoryService _storyService = StoryService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _stories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final stories = await _storyService.getStories();
      
      // Check seen status for each
      List<Map<String, dynamic>> enrichedStories = [];
      for (var s in stories) {
        final seen = await _storyService.isSeen(s['id']);
        enrichedStories.add({...s, 'isSeen': seen});
      }

      if (mounted) {
        setState(() {
          _stories = enrichedStories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dummy channels data
    final List<Map<String, String>> channels = [
      {'name': 'MoutoSubs', 'message': 'Mari bangkit Dari kuburan', 'date': '12/31/25', 'icon': 'MS', 'pinned': 'true'},
      {'name': 'BlueTalk Changelog', 'message': 'Fixed minor bugs in UI and logic.', 'date': '02/27/26', 'icon': 'CL', 'pinned': 'true'},
      {'name': 'Creator Info', 'message': 'New features coming next week! Stay tuned.', 'date': '02/25/26', 'icon': 'CI', 'pinned': 'false'},
    ];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- STORIES SECTION (HORIZONTAL) ---
          const SizedBox(height: 16),
          _isLoading
              ? SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: 4,
                    itemBuilder: (_, __) => Container(
                      width: 110,
                      margin: const EdgeInsets.only(right: 12),
                      child: const SkeletonWidget(width: 110, height: 180, borderRadius: 16),
                    ),
                  ),
                )
              : _stories.isEmpty 
                ? const SizedBox.shrink()
                : SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _stories.length,
                    itemBuilder: (context, index) {
                      final story = _stories[index];
                      final isSeen = story['isSeen'] ?? false;
                      
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoryViewScreen(
                                stories: _stories,
                                initialIndex: index,
                              ),
                            ),
                          ).then((_) => _loadData()); // Reload to update seen status
                        },
                        child: Container(
                          width: 110,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            image: DecorationImage(
                              image: NetworkImage(story['image_url']),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.black.withOpacity(0.3),
                                BlendMode.darken,
                              ),
                            ),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: isSeen ? Colors.grey : const Color(0xFF135ACF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundImage: story['bot_avatar'] != null 
                                        ? NetworkImage(story['bot_avatar']) 
                                        : null,
                                    child: story['bot_avatar'] == null 
                                        ? Text(story['bot_name'][0].toUpperCase()) 
                                        : null,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                left: 8,
                                right: 8,
                                child: Text(
                                  story['bot_name'],
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

          // --- CHANNELS SECTION (VERTICAL) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Channels',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF0F0F0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Explore', style: TextStyle(color: Colors.black87)),
                ),
              ],
            ),
          ),

          _isLoading
              ? const ChatListSkeleton()
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: channels.length,
                  itemBuilder: (context, index) {
                    final channel = channels[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFBDC3C7),
                        child: Text(
                          channel['icon']!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        channel['name']!,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.check, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                channel['message']!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            channel['date']!,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          if (channel['pinned'] == 'true')
                            const Icon(Icons.push_pin, size: 16, color: Colors.grey),
                        ],
                      ),
                      onTap: () {},
                    );
                  },
                ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
