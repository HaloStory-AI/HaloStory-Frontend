class ChatMetadata {
  final String id;
  final DateTime lastModified;
  final bool isGroup;
  final String? name;
  final String? description;
  final String? imageUrl;
  final String? color;
  final String? provider;

  const ChatMetadata({
    required this.id,
    required this.lastModified,
    this.isGroup = false,
    this.name,
    this.description,
    this.imageUrl,
    this.color,
    this.provider,
  });

  Map<String, dynamic> toLegacyMap() => {
    'id': id,
    'lastModified': lastModified,
    'time': _formatTime(lastModified),
    'isPinned': false,
    'isGroup': isGroup,
    if (name != null) 'name': name,
    if (description != null) 'description': description,
    if (imageUrl != null) 'image_url': imageUrl,
    if (color != null) 'color': color,
    if (provider != null) 'provider': provider,
  };

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);

    if (date == today) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (dt.year == now.year && dt.month == now.month) {
      return '${dt.day} ${_months[dt.month - 1]}';
    } else {
      return '${dt.day}/${dt.month}/${dt.year % 100}';
    }
  }

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];
}
