import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../utils/chat_helpers.dart';
import '../services/localization_service.dart';

class CallScreen extends StatefulWidget {
  final Map<String, dynamic> bot;
  final VoidCallback? onClose;

  const CallScreen({super.key, required this.bot, this.onClose});

  @override
  State<CallScreen> createState() => CallScreenState();
}

class CallScreenState extends State<CallScreen> {
  static VideoPlayerController? _videoController;
  bool _isConnecting = true;
  bool _isInitialized = false;
  String? _error;
  bool _hasExistingCall = false;
  bool _showPrankText = false;

  @override
  void initState() {
    super.initState();
    if (_videoController != null && _videoController!.value.isInitialized) {
      _hasExistingCall = true;
      _isConnecting = false;
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPrankDialog());
      return;
    }
    _startCall();
  }

  Future<void> _startCall() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() => _isConnecting = false);

    try {
      final response = await http.get(
        Uri.parse(AppConstants.callUrl),
        headers: {
          'Authorization': 'Bearer ${AppConstants.staticToken}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final videoUrl = data['url'] as String?;
        if (videoUrl == null || videoUrl.isEmpty) {
          setState(() => _error = 'No video URL');
          return;
        }
        await _initVideo(videoUrl);
      } else {
        setState(() => _error = 'Failed to get call (${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _initVideo(String url) async {
    try {
      _videoController = VideoPlayerController.network(url);
      await _videoController!.initialize();
      _videoController!.play();
      _videoController!.setLooping(true);
      if (!mounted) return;
      setState(() => _isInitialized = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _showPrankText = true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    if (widget.onClose == null) {
      _videoController?.dispose();
      _videoController = null;
    }
    super.dispose();
  }

  void _showPrankDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('prank_cannot_close')),
        content: const SizedBox.shrink(),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleClose() {
    if (widget.onClose != null) {
      _showPrankDialog();
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.onClose == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && widget.onClose != null) {
          _showPrankDialog();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Video layer
            if (_isInitialized && _videoController != null)
              Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Prank text
            if (_showPrankText)
              Positioned(
                left: 24,
                right: 24,
                bottom: 120,
                child: Column(
                  children: [
                    Text(
                      tr('call_prank_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('call_prank_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      tr('call_prank_desc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),

            // Content
            SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: _handleClose,
                        ),
                        const Spacer(),
                        if (_isConnecting)
                          Text(
                            'Calling...',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Incoming call UI
                  if (_isConnecting) ...[
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: parseColor(widget.bot['color']),
                        border: Border.all(color: Colors.white54, width: 2),
                      ),
                      child: widget.bot['image_url'] != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: CachedNetworkImage(imageUrl: widget.bot['image_url'], fit: BoxFit.cover,
                              ),
                            )
                          : Center(
                              child: Text(
                                widget.bot['name'][0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.bot['name'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Incoming Call...',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 40),
                    IconButton(
                      iconSize: 64,
                      icon: const Icon(Icons.call_end, color: Colors.red),
                      onPressed: _handleClose,
                    ),
                  ],

                  // Video call UI
                  if (!_isConnecting) ...[
                    const Spacer(),
                    if (!_isInitialized && _error == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 100),
                        child: Column(
                          children: [
                            SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Connecting video...',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_isInitialized || _error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: GestureDetector(
                          onTap: _handleClose,
                          child: Container(
                            width: 64,
                            height: 64,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.call_end,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
