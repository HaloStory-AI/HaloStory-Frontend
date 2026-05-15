import 'package:flutter/material.dart';
import '../../utils/chat_theme_helpers.dart';
import '../../utils/chat_resolver.dart';

class TypingIndicator extends StatelessWidget {
  final List<Map<String, dynamic>> messages;
  final bool isLoading;
  final String? activeBotId;
  final String? selectedBotId;
  final List<Map<String, dynamic>> groupMembers;
  final Map<String, dynamic> bot;

  const TypingIndicator({
    super.key,
    required this.messages,
    required this.isLoading,
    this.activeBotId,
    this.selectedBotId,
    required this.groupMembers,
    required this.bot,
  });

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? typingMsg;
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m['role'] == 'assistant' && m['is_typing_next'] == true) {
        typingMsg = m;
        break;
      }
    }

    final effectiveBotId = typingMsg != null
        ? typingMsg['bot_id']?.toString()
        : (isLoading ? activeBotId : selectedBotId);

    final displayName = resolveBotName(effectiveBotId, groupMembers, bot) ?? bot['name'];
    final avatarUrl = resolveBotAvatar(effectiveBotId, groupMembers, bot);
    final bgColor = resolveBotColor(effectiveBotId, groupMembers, bot);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: bgColor,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? Text(
                    displayName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: titleColor(context),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: botBubbleBackground(context),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(2),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DotAnim(delay: 0),
                    SizedBox(width: 4),
                    _DotAnim(delay: 0.2),
                    SizedBox(width: 4),
                    _DotAnim(delay: 0.4),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DotAnim extends StatefulWidget {
  final double delay;
  const _DotAnim({required this.delay});

  @override
  State<_DotAnim> createState() => _DotAnimState();
}

class _DotAnimState extends State<_DotAnim>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: (widget.delay * 1000).toInt()), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Opacity(
        opacity: _animation.value,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.grey.shade500,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
