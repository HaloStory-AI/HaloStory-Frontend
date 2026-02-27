import 'dart:async';
import 'package:flutter/material.dart';
import '../services/story_service.dart';
import 'package:url_launcher/url_launcher.dart';

class StoryViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;

  const StoryViewScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  late int _currentIndex;
  final StoryService _storyService = StoryService();
  double _progress = 0.0;
  Timer? _timer;
  static const int _storyDurationSeconds = 5;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _startTimer();
    _markSeen();
  }

  void _startTimer() {
    _timer?.cancel();
    _progress = 0.0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      setState(() {
        _progress += 0.05 / _storyDurationSeconds;
        if (_progress >= 1.0) {
          _nextStory();
        }
      });
    });
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _startTimer();
        _markSeen();
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _startTimer();
        _markSeen();
      });
    }
  }

  void _markSeen() {
    final storyId = widget.stories[_currentIndex]['id'];
    _storyService.markAsSeen(storyId);
  }

  Future<void> _downloadImage() async {
    final url = widget.stories[_currentIndex]['image_url'];
    if (await canLaunchUrl(Uri.parse(url))) {
      // In web/debug browser, many cross-origin policies prevent direct download via code
      // Opening in new tab is the safest way to "save"
       await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Opening image in browser for download...'))
       );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Image
          Center(
            child: InteractiveViewer(
              child: Image.network(
                story['image_url'],
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                },
              ),
            ),
          ),

          // Progress Bars
          Positioned(
            top: 50,
            left: 10,
            right: 10,
            child: Row(
              children: List.generate(
                widget.stories.length,
                (index) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: LinearProgressIndicator(
                      value: index == _currentIndex
                          ? _progress
                          : (index < _currentIndex ? 1.0 : 0.0),
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      minHeight: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Header (Avatar & Name)
          Positioned(
            top: 70,
            left: 20,
            right: 20,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: story['bot_avatar'] != null ? NetworkImage(story['bot_avatar']) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story['bot_name'],
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Text(
                        'Safebooru Status',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tap Areas
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _prevStory,
                  onLongPress: () => _timer?.cancel(),
                  onLongPressUp: () => _startTimer(),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _nextStory,
                  onLongPress: () => _timer?.cancel(),
                  onLongPressUp: () => _startTimer(),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),

          // Bottom Action
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.keyboard_arrow_up, color: Colors.white),
                  TextButton.icon(
                    onPressed: _downloadImage,
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Save to Gallery', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
