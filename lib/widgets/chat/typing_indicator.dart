import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dot_animation.dart';

class TypingIndicator extends StatelessWidget {
  final String botName;
  final String? botAvatarUrl;
  final Color botColor;
  final Color titleColor;
  final Color bubbleBgColor;

  const TypingIndicator({
    super.key,
    required this.botName,
    this.botAvatarUrl,
    required this.botColor,
    required this.titleColor,
    required this.bubbleBgColor,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: botColor,
            backgroundImage:
                botAvatarUrl != null ? CachedNetworkImageProvider(botAvatarUrl!) : null,
            child: botAvatarUrl == null
                ? Text(
                    botName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                botName,
                style: (textTheme.titleSmall ?? const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)).copyWith(color: titleColor),
              ),
              const SizedBox(height: 4),
              Card(
                color: bubbleBgColor,
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DotAnim(delay: 0),
                      SizedBox(width: 4),
                      DotAnim(delay: 0.2),
                      SizedBox(width: 4),
                      DotAnim(delay: 0.4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
