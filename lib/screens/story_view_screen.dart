import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/story_service.dart';
import '../services/ai_service.dart';
import '../services/localization_service.dart';
import '../services/bot_service.dart';
import 'chat_screen.dart';

class StoryViewScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final int initialIndex;
  final VoidCallback? onClose;
  final Function(Map<String, dynamic> bot, String message)? onReply;

  const StoryViewScreen({
    super.key,
    required this.stories,
    required this.initialIndex,
    this.onClose,
    this.onReply,
  });

  @override
  State<StoryViewScreen> createState() => _StoryViewScreenState();
}

class _StoryViewScreenState extends State<StoryViewScreen> {
  late int _currentIndex;
  final StoryService _storyService = StoryService();
  final BotService _botService = BotService();

  double _progress = 0.0;
  Timer? _timer;
  bool _isOpeningWeb = false;
  bool _isLoadingMedia = true;
  double _downloadProgress = 0.0;

  VideoPlayerController? _videoController;
  File? _localFile;
  bool _isVideo = false;

  // Load-generation counter: prevents stale async results from overriding
  // a newer story load when the user skips while media is still downloading.
  int _loadGen = 0;

  static const int _imageDurationSeconds = 5;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadMedia();
    _markSeen();
  }

  Future<void> _loadMedia() async {
    _timer?.cancel();
    _videoController?.dispose();
    _videoController = null;

    // Increment generation and capture — any awaited result from a previous
    // call belonging to an older generation will be discarded.
    final int myGen = ++_loadGen;

    if (!mounted) return;
    setState(() {
      _isLoadingMedia = true;
      _progress = 0.0;
      _localFile = null;
    });

    final url = widget.stories[_currentIndex]['image_url'] as String;
    _isVideo =
        url.toLowerCase().endsWith('.mp4') ||
        url.toLowerCase().endsWith('.mov') ||
        url.toLowerCase().endsWith('.avi');

    // 1. Stream download progress — bail out if generation changed
    await for (final progress in _storyService.getMediaDownloadProgress(url)) {
      if (!mounted || _loadGen != myGen) return; // stale — user already skipped
      if (progress < 0 && progress != -2.0)
        break; // Error (-1.0), but -2.0 is indeterminate

      setState(() {
        // -2.0 means indeterminate (server didn't provide content length)
        _downloadProgress = progress == -2.0 ? 0.0 : progress;
      });

      if (progress >= 1.0) break;
    }

    if (!mounted || _loadGen != myGen) return; // stale check after stream

    // 2. Get local cached file
    final file = await _storyService.getLocalMedia(url);

    if (!mounted || _loadGen != myGen) return; // stale check after await

    if (file != null) {
      _localFile = file;
      if (_isVideo) {
        _videoController = VideoPlayerController.file(file);
        await _videoController!.initialize();
        if (!mounted || _loadGen != myGen) return; // stale check after init
        setState(() => _isLoadingMedia = false);
        _videoController!.play();
        _startVideoTimer();
      } else {
        // Decode image into Flutter's memory cache first so it renders
        // immediately — prevents timer running before image is visible.
        await precacheImage(FileImage(file), context);
        if (!mounted || _loadGen != myGen) return;
        setState(() => _isLoadingMedia = false);
        _startImageTimer();
      }
    } else {
      // Fallback to network
      if (_isVideo) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
        await _videoController!.initialize();
        if (!mounted || _loadGen != myGen) return; // stale check after init
        setState(() => _isLoadingMedia = false);
        _videoController!.play();
        _startVideoTimer();
      } else {
        setState(() => _isLoadingMedia = false);
        _startImageTimer();
      }
    }

    // Prefetch next 3 stories
    _prefetchMedia();
  }

  void _prefetchMedia() {
    for (int i = 1; i <= 3; i++) {
      int nextIdx = _currentIndex + i;
      if (nextIdx < widget.stories.length) {
        final nextUrl = widget.stories[nextIdx]['image_url'] as String;
        // Just trigger the download/cache in the background, don't await
        _storyService.getMediaDownloadProgress(nextUrl).drain().then((_) {
          _storyService.getLocalMedia(nextUrl).then((file) {
            if (file != null && !nextUrl.toLowerCase().endsWith('.mp4')) {
              // For images, also precache to memory
              if (mounted) {
                precacheImage(FileImage(file), context);
              }
            }
          });
        });
      }
    }
  }

  void _startImageTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (mounted) {
        setState(() {
          _progress += 0.05 / _imageDurationSeconds;
          if (_progress >= 1.0) {
            _nextStory();
          }
        });
      }
    });
  }

  void _startVideoTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_videoController == null || !_videoController!.value.isInitialized)
        return;

      if (mounted) {
        setState(() {
          final duration = _videoController!.value.duration.inMilliseconds;
          final position = _videoController!.value.position.inMilliseconds;
          _progress = position / duration;

          if (_progress >= 0.99 ||
              (_videoController!.value.position >=
                  _videoController!.value.duration)) {
            _timer?.cancel();
            _nextStory();
          }
        });
      }
    });
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';

      final today = DateTime(now.year, now.month, now.day);
      final date = DateTime(dt.year, dt.month, dt.day);

      if (date == today) {
        return 'Today, ${DateFormat('HH:mm').format(dt)}';
      } else if (date == today.subtract(const Duration(days: 1))) {
        return 'Yesterday, ${DateFormat('HH:mm').format(dt)}';
      } else {
        return DateFormat('d MMM, HH:mm').format(dt);
      }
    } catch (e) {
      return 'Recently';
    }
  }

  void _nextStory() {
    if (_currentIndex < widget.stories.length - 1) {
      setState(() {
        _currentIndex++;
        _loadMedia();
        _markSeen();
      });
    } else {
      _closeStory();
    }
  }

  void _prevStory() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _loadMedia();
        _markSeen();
      });
    } else {
      // Restart current
      _loadMedia();
    }
  }

  void _markSeen() {
    final storyId = widget.stories[_currentIndex]['id'].toString();
    _storyService.markAsSeen(storyId);
  }

  void _closeStory() {
    _timer?.cancel();
    _videoController?.pause();
    if (mounted) {
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.of(context, rootNavigator: false).pop();
      }
    }
  }

  /// Buka chat dengan karakter ini, dengan pesan preset konteks dari story.
  Future<void> _openReplyChat() async {
    _timer?.cancel();
    _videoController?.pause();

    final story = widget.stories[_currentIndex];
    final botId = story['bot_id'] as String;
    final botName = story['bot_name'] as String;

    // Fetch full bot data
    final allBots = await _botService.getBots();
    final bot = allBots.firstWhere(
      (b) => b['id'] == botId,
      orElse: () => {
        'id': botId,
        'name': botName,
        'image_url': story['bot_avatar'],
        'color': '0xFF135ACF',
        'description': '',
      },
    );

    if (!mounted) return;

    // Show reply bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _ReplySheet(
        botName: botName,
        onSend: (message) async {
          Navigator.pop(sheetCtx);

          final prefs = await SharedPreferences.getInstance();
          final provider = AIService.normalizeProvider(
            prefs.getString('default_provider'),
          );

          if (!mounted) return;

          // Pastikan bot sudah terdaftar
          _botService.recruitBot(botId);

          if (widget.onReply != null) {
             widget.onReply!(bot, message);
          } else {
            // Tutup story view lalu buka chat
            Navigator.of(context, rootNavigator: false).pop();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatDetailScreen(
                  bot: bot,
                  provider: provider,
                  initialMessage: message,
                ),
              ),
            );
          }
        },
      ),
    ).then((_) {
      // Resume timer jika user dismiss sheet tanpa mengirim
      if (mounted && !_isLoadingMedia) {
        if (_isVideo) {
          _videoController?.play();
          _startVideoTimer();
        } else {
          _startImageTimer();
        }
      }
    });
  }

  Future<void> _openOnWeb() async {
    if (_isOpeningWeb) return;
    final url = widget.stories[_currentIndex]['image_url'] as String;

    setState(() => _isOpeningWeb = true);
    _timer?.cancel();
    if (_isVideo) _videoController?.pause();

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('chat_export_web_error')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error opening browser.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isOpeningWeb = false);
      if (_isVideo) {
        _videoController?.play();
        _startVideoTimer();
      } else {
        _startImageTimer();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.stories[_currentIndex];

    final content = Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // BLURRED BACKGROUND (Glassmorphism Effect)
          Positioned.fill(
            child: _localFile != null && !_isVideo
                ? Image.file(_localFile!, fit: BoxFit.cover)
                : (story['bot_avatar'] != null
                      ? Image.network(story['bot_avatar'], fit: BoxFit.cover)
                      : Container(color: Colors.black)),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(color: Colors.black.withOpacity(0.4)),
            ),
          ),

          // MAIN MEDIA CONTENT
          Center(
            child: _isLoadingMedia
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 150,
                        child: LinearProgressIndicator(
                          value: _downloadProgress,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _downloadProgress == 0.0
                            ? 'Loading Sensei\'s memory...'
                            : 'Loading Sensei\'s memory... ${(_downloadProgress * 100).toInt()}%',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : _isVideo
                ? (_videoController != null &&
                          _videoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : const CircularProgressIndicator(color: Colors.white))
                : InteractiveViewer(
                    child: (!kIsWeb && _localFile != null)
                        ? Image.file(_localFile!, fit: BoxFit.contain)
                        : Image.network(
                            story['image_url'],
                            fit: BoxFit.contain,
                          ),
                  ),
          ),

          // PROGRESS BARS (WhatsApp Style)
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
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                      minHeight: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // HEADER
          Positioned(
            top: 70,
            left: 20,
            right: 20,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white24,
                  backgroundImage: story['bot_avatar'] != null
                      ? NetworkImage(story['bot_avatar'])
                      : null,
                  child: story['bot_avatar'] == null
                      ? Text(
                          story['bot_name'][0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story['bot_name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatTimestamp(story['created_at']),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _closeStory,
                ),
              ],
            ),
          ),

          // INTERACTION AREAS
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _prevStory,
                  onLongPress: () {
                    _timer?.cancel();
                    _videoController?.pause();
                  },
                  onLongPressUp: () {
                    if (_isVideo) {
                      _videoController?.play();
                      _startVideoTimer();
                    } else {
                      _startImageTimer();
                    }
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _nextStory,
                  onLongPress: () {
                    _timer?.cancel();
                    _videoController?.pause();
                  },
                  onLongPressUp: () {
                    if (_isVideo) {
                      _videoController?.play();
                      _startVideoTimer();
                    } else {
                      _startImageTimer();
                    }
                  },
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),

          // BOTTOM ACTIONS: Download + Reply
          Positioned(
            bottom: 0,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Download button
                    _isOpeningWeb
                        ? const CircularProgressIndicator(color: Colors.white)
                        : _BottomActionButton(
                            icon: Icons.open_in_browser_outlined,
                            label: tr('tab_stories_open_web'),
                            onTap: _openOnWeb,
                          ),
                    const SizedBox(width: 24),
                    // Reply button
                    _BottomActionButton(
                      icon: Icons.reply_rounded,
                      label: tr('tab_stories_reply'),
                      onTap: _openReplyChat,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.onClose != null) {
      return content;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closeStory();
      },
      child: content,
    );
  }
}

/// Tombol aksi kecil di bawah story (download / reply)
class _BottomActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38, width: 1.5),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet untuk mengetik pesan balasan ke karakter dari story.
class _ReplySheet extends StatefulWidget {
  final String botName;
  final Future<void> Function(String message) onSend;

  const _ReplySheet({required this.botName, required this.onSend});

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  final TextEditingController _ctrl = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    await widget.onSend(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1E2A3A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${tr('tab_stories_reply')} ${widget.botName}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    style: const TextStyle(
                      color: Color(0xFF1E2A3A),
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: '${tr('chat_manual_hint')}...',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 15,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _handleSend,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Color(0xFF135ACF),
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
