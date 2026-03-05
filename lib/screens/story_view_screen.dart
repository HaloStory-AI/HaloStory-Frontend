import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../services/story_service.dart';

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
  bool _isSaving = false;
  bool _isLoadingMedia = true;
  
  VideoPlayerController? _videoController;
  File? _localFile;
  bool _isVideo = false;

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
    
    if (!mounted) return;
    setState(() {
      _isLoadingMedia = true;
      _progress = 0.0;
      _localFile = null;
    });

    final url = widget.stories[_currentIndex]['image_url'] as String;
    _isVideo = url.toLowerCase().endsWith('.mp4') || 
               url.toLowerCase().endsWith('.mov') || 
               url.toLowerCase().endsWith('.avi');

    // 1. Get from Local Cache (.statustemp)
    final file = await _storyService.getLocalMedia(url);
    
    if (!mounted) return;
    
    if (file != null) {
      _localFile = file;
      if (_isVideo) {
        _videoController = VideoPlayerController.file(file);
        await _videoController!.initialize();
        if (mounted) {
          setState(() {
            _isLoadingMedia = false;
          });
          _videoController!.play();
          _startVideoTimer();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingMedia = false;
          });
          _startImageTimer();
        }
      }
    } else {
      // Fallback to Network if cache fails
      if (_isVideo) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
        await _videoController!.initialize();
        if (mounted) {
          setState(() {
            _isLoadingMedia = false;
          });
          _videoController!.play();
          _startVideoTimer();
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingMedia = false;
          });
          _startImageTimer();
        }
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
      if (_videoController == null || !_videoController!.value.isInitialized) return;
      
      if (mounted) {
        setState(() {
          final duration = _videoController!.value.duration.inMilliseconds;
          final position = _videoController!.value.position.inMilliseconds;
          _progress = position / duration;
          
          if (_progress >= 0.99 || (_videoController!.value.position >= _videoController!.value.duration)) {
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
      Navigator.pop(context);
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

  Future<void> _saveToGallery() async {
    if (_isSaving) return;
    final url = widget.stories[_currentIndex]['image_url'] as String;

    PermissionStatus status;
    if (kIsWeb) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (Platform.isAndroid) {
        status = await Permission.photos.request();
        if (!status.isGranted) status = await Permission.storage.request();
    } else {
        status = await Permission.photos.request();
    }

    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Permission required to save.')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);
    _timer?.cancel();
    _videoController?.pause();

    try {
      bool? success;
      // Optimization: If local file exists, use it instead of URL to avoid slow Backblaze download
      final String? cachedPath = await _storyService.getCachedPath(url);
      final String source = cachedPath ?? url;

      if (_isVideo) {
          success = await GallerySaver.saveVideo(source, albumName: 'BlueTalk', toDcim: true);
      } else {
          success = await GallerySaver.saveImage(source, albumName: 'BlueTalk', toDcim: true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success == true ? '✅ Saved to gallery!' : '❌ Failed to save.')),
        );
      }
    } catch (e) {
      print("DEBUG: Save error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ An error occurred while saving.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

    return Scaffold(
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
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      'Loading Sensei\'s memory...',
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                    ),
                  ],
                )
              : _isVideo 
                  ? (_videoController != null && _videoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : const CircularProgressIndicator(color: Colors.white))
                  : InteractiveViewer(
                      child: (!kIsWeb && _localFile != null)
                        ? Image.file(_localFile!, fit: BoxFit.contain)
                        : Image.network(story['image_url'], fit: BoxFit.contain),
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
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
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
                  backgroundImage: story['bot_avatar'] != null ? NetworkImage(story['bot_avatar']) : null,
                  child: story['bot_avatar'] == null 
                    ? Text(story['bot_name'][0].toUpperCase(), style: const TextStyle(color: Colors.white))
                    : null,
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
                      Text(
                        _formatTimestamp(story['created_at']),
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
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

          // DOWNLOAD BUTTON
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : IconButton(
                      onPressed: _saveToGallery,
                      icon: const Icon(Icons.download_for_offline, color: Colors.white, size: 40),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
