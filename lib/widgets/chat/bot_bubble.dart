import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../../utils/chat_theme_helpers.dart';
import '../../utils/chat_resolver.dart';

class BotBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  final DateTime? timestamp;
  final int visibleParts;
  final bool isTypingNext;
  final List<Map<String, dynamic>> groupMembers;
  final Map<String, dynamic> bot;

  const BotBubble({
    super.key,
    required this.msg,
    this.timestamp,
    this.visibleParts = 0,
    this.isTypingNext = false,
    required this.groupMembers,
    required this.bot,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = msg['content']?.toString() ?? '';
    final parts = content
        .split('\n\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return const SizedBox.shrink();

    final partsToRender = visibleParts > 0
        ? parts.take(visibleParts).toList()
        : parts;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: resolveBotColor(msg['bot_id'], groupMembers, bot),
            backgroundImage: resolveBotAvatar(msg['bot_id'], groupMembers, bot) != null
                ? NetworkImage(resolveBotAvatar(msg['bot_id'], groupMembers, bot)!)
                : null,
            child: resolveBotAvatar(msg['bot_id'], groupMembers, bot) == null
                ? Text(
                    (resolveBotName(msg['bot_id'], groupMembers, bot) ?? bot['name'])[0]
                        .toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      resolveBotName(msg['bot_id'], groupMembers, bot) ?? bot['name'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: titleColor(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (timestamp != null)
                      Text(
                        formatMessageTime(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                ...partsToRender.asMap().entries.map((entry) {
                  int idx = entry.key;
                  String part = entry.value;
                  bool isFirst = idx == 0;

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: idx == partsToRender.length - 1 ? 0 : 4,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: botBubbleBackground(context),
                        borderRadius: BorderRadius.only(
                          topLeft: isFirst
                              ? const Radius.circular(2)
                              : const Radius.circular(12),
                          topRight: const Radius.circular(12),
                          bottomLeft: const Radius.circular(12),
                          bottomRight: const Radius.circular(12),
                        ),
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.65,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarkdownBody(
                            data: part,
                            selectable: false,
                            extensionSet: md.ExtensionSet(
                              md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                              <md.InlineSyntax>[
                                md.EmojiSyntax(),
                                ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                              ],
                            ),
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 14,
                                height: 1.4,
                              ),
                              strong: TextStyle(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                              em: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.86),
                                fontStyle: FontStyle.italic,
                              ),
                              code: TextStyle(
                                color: colorScheme.primary,
                                backgroundColor: colorScheme.surfaceContainer,
                                fontSize: 14,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              listBullet: TextStyle(
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (isTypingNext)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: botBubbleBackground(context),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
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
                  ),
              ],
            ),
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
