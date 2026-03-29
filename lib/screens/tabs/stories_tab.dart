import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../widgets/skeleton_loader.dart';
import '../../services/story_service.dart';
import '../../services/localization_service.dart';
import '../story_view_screen.dart';

class StoriesTab extends StatefulWidget {
  const StoriesTab({super.key});

  @override
  State<StoriesTab> createState() => _StoriesTabState();
}

class _StoriesTabState extends State<StoriesTab> {
  final StoryService _storyService = StoryService();
  bool _isLoading = true;
  bool _isReloading = false;
  List<Map<String, dynamic>> _stories = [];
  Timer? _cooldownTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _startCooldownListener();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldownListener() {
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final seconds = _storyService.getReloadCooldownSeconds();
      if (mounted && seconds != _remainingSeconds) {
        setState(() {
          _remainingSeconds = seconds;
        });
      }
    });
  }

  Future<void> _loadData({bool force = false}) async {
    if (force) {
      setState(() => _isReloading = true);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      final stories = await _storyService.getStories(forceRefresh: force);

      // Check seen status for each
      List<Map<String, dynamic>> enrichedStories = [];
      for (var s in stories) {
        final seen = await _storyService.isSeen(s['id'].toString());
        enrichedStories.add({...s, 'isSeen': seen});
      }

      if (mounted) {
        setState(() {
          _stories = enrichedStories;
          _isLoading = false;
          _isReloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isReloading = false;
        });
      }
    }
  }

  List<String> _getGroupedBots() {
    final List<String> botIds = [];
    for (var s in _stories) {
      if (!botIds.contains(s['bot_id'])) {
        botIds.add(s['bot_id']);
      }
    }
    return botIds;
  }

  String _formatCooldown(int seconds) {
    int mins = seconds ~/ 60;
    int secs = seconds % 60;
    return "$mins:${secs.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {

    return SafeArea(
      top: false,
      child: Column(
      children: [
        // --- HEADER & RELOAD ---
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr('tab_stories'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),
              TextButton(
                onPressed: (_isReloading || _remainingSeconds > 0)
                    ? null
                    : () => _loadData(force: true),
                style: TextButton.styleFrom(
                  backgroundColor: (_isReloading || _remainingSeconds > 0)
                      ? Colors.grey[200]
                      : const Color(0xFFF0F0F0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isReloading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF135ACF),
                        ),
                      ),
                    if (_isReloading) const SizedBox(width: 8),
                    Text(
                      _remainingSeconds > 0
                          ? '${tr('btn_reload_in')} ${_formatCooldown(_remainingSeconds)}'
                          : _isReloading
                          ? tr('loading')
                          : tr('btn_reload_stories'),
                      style: TextStyle(
                        color: (_isReloading || _remainingSeconds > 0)
                            ? Colors.grey
                            : Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- STORIES LIST (VERTICAL) ---
        Expanded(
          child: _isLoading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: 8,
                  itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Row(
                      children: [
                        const SkeletonWidget(width: 70, height: 70, borderRadius: 35),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SkeletonWidget(width: 120, height: 16),
                              const SizedBox(height: 8),
                              SkeletonWidget(
                                width: double.infinity,
                                height: 12,
                                borderRadius: 4,
                                color: Colors.grey[100],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _stories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off, 
                           size: 64, 
                           color: Colors.grey.withAlpha(77)),
                      const SizedBox(height: 16),
                      Text(
                        tr('no_bots_found'),
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _getGroupedBots().length,
                  itemBuilder: (context, index) {
                    final groupedBots = _getGroupedBots();
                    final botId = groupedBots[index];
                    final botStories = _stories
                        .where((s) => s['bot_id'] == botId)
                        .toList();
                    final latestStory = botStories.last;
                    final bool hasUnseen = botStories.any(
                      (s) => !(s['isSeen'] ?? false),
                    );

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      leading: SizedBox(
                        width: 72,
                        height: 72,
                        child: CustomPaint(
                          painter: StoryRingPainter(stories: botStories),
                          child: Center(
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: latestStory['bot_avatar'] != null
                                  ? NetworkImage(latestStory['bot_avatar'])
                                  : null,
                              child: latestStory['bot_avatar'] == null
                                  ? Text(
                                      latestStory['bot_name'][0].toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 18, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      title: Text(
                        latestStory['bot_name'],
                        style: TextStyle(
                          fontWeight: hasUnseen ? FontWeight.bold : FontWeight.w600,
                          fontSize: 17,
                        ),
                      ),
                      subtitle: Text(
                        latestStory['caption'] ?? (latestStory['content'] ?? 'New story!'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      trailing: Text(
                        '${botStories.length} updates',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        int targetIndex = botStories.indexWhere(
                          (s) => !(s['isSeen'] ?? false),
                        );
                        if (targetIndex == -1) targetIndex = 0;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StoryViewScreen(
                              stories: botStories,
                              initialIndex: targetIndex,
                            ),
                          ),
                        ).then((_) => _loadData());
                      },
                    );
                  },
                ),
        ),
      ],
      ),
    );
  }
}

/// Menggambar lingkaran segmen (WhatsApp-style) di sekeliling avatar.
/// Setiap segmen = 1 story. Biru = belum dilihat, abu = sudah dilihat.
class StoryRingPainter extends CustomPainter {
  final List<Map<String, dynamic>> stories;

  static const Color _unseenColor = Color(0xFF135ACF);
  static const Color _seenColor = Color(0xFFCCCCCC);
  static const double _strokeWidth = 3.0;
  // Gap antar segmen dalam derajat
  static const double _gapDeg = 6.0;

  const StoryRingPainter({required this.stories});

  @override
  void paint(Canvas canvas, Size size) {
    final int count = stories.length;
    if (count == 0) return;

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius = (size.width / 2) - (_strokeWidth / 2);
    final Rect rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    // Kalau hanya 1 story, gambar lingkaran penuh (tanpa gap)
    if (count == 1) {
      final bool seen = stories[0]['isSeen'] ?? false;
      final paint = Paint()
        ..color = seen ? _seenColor : _unseenColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      canvas.drawCircle(Offset(cx, cy), radius, paint);
      return;
    }

    // Mulai dari atas (-90 derajat)
    final double gapRad = _gapDeg * math.pi / 180;
    final double totalGap = gapRad * count;
    final double segRad = (2 * math.pi - totalGap) / count;

    for (int i = 0; i < count; i++) {
      final bool seen = stories[i]['isSeen'] ?? false;
      final paint = Paint()
        ..color = seen ? _seenColor : _unseenColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true;

      // Posisi awal tiap segmen
      final double startAngle =
          -math.pi / 2 + i * (segRad + gapRad) + gapRad / 2;

      canvas.drawArc(rect, startAngle, segRad, false, paint);
    }
  }

  @override
  bool shouldRepaint(StoryRingPainter oldDelegate) {
    // Repaint kalau ada perubahan status seen
    if (oldDelegate.stories.length != stories.length) return true;
    for (int i = 0; i < stories.length; i++) {
      if (oldDelegate.stories[i]['isSeen'] != stories[i]['isSeen']) return true;
    }
    return false;
  }
}
