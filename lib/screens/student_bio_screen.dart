import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../widgets/chat/edit_group_info_dialog.dart';
import 'select_contact_screen.dart';

class StudentBioScreen extends StatefulWidget {
  final Map<String, dynamic> bot;
  final bool isGroup;
  final List<Map<String, dynamic>> groupMembers;
  final String groupName;
  final String groupBio;
  final String botId;

  final bool isPanel;
  final void Function(Widget child, String title)? onOpenPanel4;
  final VoidCallback? onClosePanel;

  final VoidCallback? onGroupInfoChanged;
  final void Function(int index)? onKickMember;
  final void Function(List<Map<String, dynamic>> bots)? onAddMembers;
  final void Function(String name, String bio)? onEditGroupInfo;

  const StudentBioScreen({
    super.key,
    required this.bot,
    required this.isGroup,
    required this.groupMembers,
    required this.groupName,
    required this.groupBio,
    required this.botId,
    this.isPanel = false,
    this.onOpenPanel4,
    this.onClosePanel,
    this.onGroupInfoChanged,
    this.onKickMember,
    this.onAddMembers,
    this.onEditGroupInfo,
  });

  @override
  State<StudentBioScreen> createState() => _StudentBioScreenState();
}

class _StudentBioScreenState extends State<StudentBioScreen> {
  String? _translatedDescription;
  bool _isTranslating = false;
  late List<Map<String, dynamic>> _localMembers;
  late String _localGroupName;
  late String _localGroupBio;

  // Bond state
  Map<String, dynamic>? _bondData;
  bool _isBondLoading = true;
  bool _bondDisabled = false;

  // Bio data (fetched from /v1/bot-bio)
  String? _bioDescription;
  Map<String, String>? _personalityAttrs;
  bool _isBioLoading = true;

  @override
  void initState() {
    super.initState();
    _localMembers = List<Map<String, dynamic>>.from(widget.groupMembers);
    _localGroupName = widget.groupName;
    _localGroupBio = widget.groupBio;
    _loadBondSetting();
    _loadBondData();
    if (!widget.isGroup) _fetchBotBio();
  }

  Future<void> _loadBondSetting() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _bondDisabled = prefs.getBool('bond_disabled') ?? false;
      });
    }
  }

  String get _appLanguageCode => LocalizationService().currentLocale;

  String get _resolvedDescription {
    if (_bioDescription != null && _bioDescription!.isNotEmpty) return _bioDescription!;
    final desc = widget.bot['description']?.toString();
    if (desc != null && desc.isNotEmpty) return desc;
    return widget.bot['bio']?.toString() ?? '';
  }

  Color _parseColor(dynamic color) {
    if (color == null) return Colors.blueGrey;
    if (color is Color) return color;
    if (color is String) {
      try {
        return Color(int.parse(color));
      } catch (_) {
        return Colors.blueGrey;
      }
    }
    return Colors.blueGrey;
  }

  bool _isBirthday(dynamic birthdayStr) {
    if (birthdayStr == null || birthdayStr == '') return false;
    try {
      final birthday = DateTime.parse(birthdayStr.toString());
      final now = DateTime.now();
      return birthday.month == now.month && birthday.day == now.day;
    } catch (_) {
      return false;
    }
  }

  Future<void> _fetchBotBio() async {
    final authService = AuthService();
    final token = await authService.getToken();
    if (token == null || !mounted) return;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/v1/bot-bio/${widget.botId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        setState(() {
          _bioDescription = data['description']?.toString();
          if (data['personality'] is Map) {
            _personalityAttrs = (data['personality'] as Map)
                .map((k, v) => MapEntry(k.toString(), v.toString()));
          }
          _isBioLoading = false;
        });
      } else {
        if (mounted) setState(() => _isBioLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isBioLoading = false);
    }
  }


  Color _relationshipColor(String status) {
    return switch (status) {
      'enemy' => Colors.red.shade400,
      'married' => Colors.purple.shade400,
      'lover' => const Color(0xFFFB6F9D),
      'rejected' => Colors.grey.shade500,
      'stuck' => Colors.orange.shade400,
      _ => Colors.blue.shade400,
    };
  }

  Future<void> _loadBondData() async {
    if (widget.isGroup) {
      await _fetchAllGroupBondStats();
    } else {
      await _fetchBondStats();
    }
  }

  Future<void> _fetchBondStats() async {
    final authService = AuthService();
    final token = await authService.getToken();
    if (token == null || !mounted) return;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/bots/bond/${widget.botId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _bondData = jsonDecode(response.body);
          _isBondLoading = false;
        });
      } else {
        if (mounted) setState(() => _isBondLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isBondLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchBondStatsFor(String botId) async {
    final authService = AuthService();
    final token = await authService.getToken();
    if (token == null || !mounted) return null;

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.baseUrl}/bots/bond/$botId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _fetchAllGroupBondStats() async {
    if (_localMembers.isEmpty) {
      if (mounted) setState(() => _isBondLoading = false);
      return;
    }
    try {
      final List<Map<String, dynamic>> updated = [];
      for (final member in _localMembers) {
        final memberId =
            member['bot_id']?.toString() ?? member['id']?.toString();
        if (memberId == null) {
          updated.add(member);
          continue;
        }
        final data = await _fetchBondStatsFor(memberId);
        if (data != null) {
          updated.add({
            ...member,
            'bond_hearts': data['bond_hearts'] ?? member['bond_hearts'],
            'xp': data['xp'] ?? member['xp'],
            'xp_into_level': data['xp_into_level'] ?? member['xp_into_level'],
            'progress_percent':
                data['progress_percent'] ?? member['progress_percent'],
          });
        } else {
          updated.add(member);
        }
      }

      if (mounted) {
        setState(() {
          _localMembers = List<Map<String, dynamic>>.from(updated);
          _isBondLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isBondLoading = false);
    }
  }

  Future<void> _translateText(String text) async {
    final targetLang = _appLanguageCode;
    if (targetLang == 'en') return;

    final encoded = Uri.encodeComponent(text);
    try {
      final response = await http.get(
        Uri.parse(
          'https://translate.googleapis.com/translate_a/single'
          '?client=gtx&sl=en&tl=$targetLang&dt=t&q=$encoded',
        ),
      );
      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as List;
        if (mounted) {
          setState(() {
            _translatedDescription = decoded[0][0][0] as String;
            _isTranslating = false;
          });
        }
      } else {
        if (mounted) setState(() => _isTranslating = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<void> _confirmKickMember(int index) async {
    final member = _localMembers[index];
    final name = member['name'] ?? 'Unknown';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('group_confirm_kick_title')),
        content: Text(
          tr('group_confirm_kick_body').replaceAll('{name}', name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('group_kick_confirm_no')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('group_kick_confirm_yes')),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      widget.onKickMember?.call(index);
      setState(() {
        _localMembers.removeAt(index);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('group_member_removed'))),
        );
      }
    }
  }

  void _onMembersSelected(List<Map<String, dynamic>> result) {
    if (result.isEmpty) return;
    final currentIds = _localMembers
        .map((m) => m['bot_id']?.toString() ?? m['id']?.toString())
        .toSet();

    final newMembers = <Map<String, dynamic>>[];
    for (final bot in result) {
      final botId = bot['id'].toString();
      if (!currentIds.contains(botId)) {
        newMembers.add({
          'bot_id': botId,
          'id': botId,
          'name': bot['name'] ?? 'Unknown',
          'image_url': bot['image_url'],
          'avatar': bot['avatar'],
          'color': bot['color'],
        });
      }
    }

    if (newMembers.isNotEmpty) {
      widget.onAddMembers?.call(newMembers);
      if (mounted) {
        setState(() {
          _localMembers.addAll(newMembers);
        });
      }
    }

    widget.onClosePanel?.call();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('group_member_added'))),
      );
    }
  }

  Future<void> _navigateToAddMember() async {
    final existingIds = _localMembers
        .map((m) => m['bot_id']?.toString() ?? m['id']?.toString())
        .whereType<String>()
        .toSet();

    if (widget.onOpenPanel4 != null) {
      widget.onOpenPanel4!(
        SelectContactScreen(
          mode: SelectContactMode.addToGroup,
          existingMemberIds: existingIds,
          isPanel: true,
          onPanelDone: _onMembersSelected,
          onContactSelected: (_) {},
          onCancel: () {},
        ),
        tr('group_add_member'),
      );
      return;
    }

    final result = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (context) => SelectContactScreen(
          mode: SelectContactMode.addToGroup,
          existingMemberIds: existingIds,
          onContactSelected: (_) {},
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      final currentIds = _localMembers
          .map((m) => m['bot_id']?.toString() ?? m['id']?.toString())
          .toSet();

      final newMembers = <Map<String, dynamic>>[];
      for (final bot in result) {
        final botId = bot['id'].toString();
        if (!currentIds.contains(botId)) {
          newMembers.add({
            'bot_id': botId,
            'id': botId,
            'name': bot['name'] ?? 'Unknown',
            'image_url': bot['image_url'],
            'avatar': bot['avatar'],
            'color': bot['color'],
          });
        }
      }

      if (newMembers.isNotEmpty) {
        widget.onAddMembers?.call(newMembers);
        setState(() {
          _localMembers.addAll(newMembers);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('group_member_added'))),
        );
      }
    }
  }

  Future<void> _showEditGroupInfoDialog() async {
    final result = await showEditGroupInfoDialog(
      context: context,
      initialName: _localGroupName.isNotEmpty
          ? _localGroupName
          : widget.bot['name'] ?? '',
      initialBio: _localGroupBio,
    );
    if (result == null) return;
    widget.onEditGroupInfo?.call(result.name, result.bio);
    setState(() {
      _localGroupName = result.name;
      _localGroupBio = result.bio;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        widget.isGroup
            ? (_localGroupName.isNotEmpty ? _localGroupName : widget.bot['name'])
            : widget.bot['name'];

    final description = _translatedDescription ?? _resolvedDescription;

    return Scaffold(
      appBar: widget.isPanel
          ? null
          : AppBar(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              title: Text(
                displayName,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconTheme: IconThemeData(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              actions: [
                if (widget.isGroup)
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded),
                    onPressed: _showEditGroupInfoDialog,
                    tooltip: 'Edit Group Info',
                  ),
              ],
            ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 60,
              backgroundColor: _parseColor(widget.bot['color']),
              backgroundImage: widget.bot['image_url'] != null
                  ? NetworkImage(widget.bot['image_url'])
                  : null,
              child: widget.bot['image_url'] == null
                  ? Text(
                      displayName[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (_isBirthday(widget.bot['birthday']))
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  '🎂 Birthday Today!',
                  style: TextStyle(
                    color: Colors.pinkAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                description.isNotEmpty ? description : tr('bio_no_description'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            if (!widget.isGroup &&
                description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _translatedDescription == null
                    ? OutlinedButton.icon(
                        onPressed: _isTranslating
                            ? null
                            : () async {
                                setState(() => _isTranslating = true);
                                await _translateText(description);
                              },
                        icon: _isTranslating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.translate, size: 18),
                        label: Text(
                          _isTranslating
                              ? tr('system_notice_btn')
                              : 'Translate',
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          foregroundColor:
                              Theme.of(context).colorScheme.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      )
                    : TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _translatedDescription = null;
                          });
                        },
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Show Original'),
                      ),
              ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            if (widget.isGroup)
              _buildGroupMembersSection()
            else ...[
              if (!_isBondLoading)
                _bondDisabled
                    ? _buildBondDisabledPlaceholder()
                    : _buildSingleBondCard(),
              if (!_isBondLoading) const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr('personality_title_label'),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildPersonalitySection(),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleBondCard() {
    final hearts = _bondData?['bond_hearts'] ?? widget.bot['bond_hearts'] ?? 0;
    final xpInto = _bondData?['xp_into_level'] ?? 0;
    final xpPer = _bondData?['xp_per_level'] ?? 5;
    final progress = _bondData != null
        ? ((_bondData!['progress_percent'] as num?) ?? 0) / 100.0
        : 0.0;
    final bondStatus = _bondData?['bond_status'] ?? 'normal';
    final relationship =
        _bondData?['relationship_label'] ?? 'Orang Asing';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.favorite,
                      color: Color(0xFFFBB6CE),
                      size: 48,
                    ),
                    Text(
                      '$hearts',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lv. $hearts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _relationshipColor(bondStatus)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _relationshipColor(bondStatus)
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          relationship,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _relationshipColor(bondStatus),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress to Lv. ${hearts + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$xpInto / $xpPer XP',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.pink.shade50,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFFFB6F9D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBondDisabledPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.favorite_border,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tr('bond_disabled_placeholder'),
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalitySection() {
    if (_isBioLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_personalityAttrs == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          tr('bio_no_personality'),
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: _personalityAttrs!.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGroupMembersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              tr('group_members_title'),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          if (_bondDisabled)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tr('bond_disabled_placeholder'),
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          if (_localMembers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  tr('group_no_members'),
                  style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            ..._localMembers.asMap().entries.map((entry) {
              final index = entry.key;
              final member = entry.value;
              final memberName = member['name'] ?? 'Unknown';
              final memberColor = _parseColor(member['color']);
              final memberAvatar = member['image_url'] ?? member['avatar'];
              final hearts = member['bond_hearts'] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: memberColor,
                      backgroundImage: memberAvatar != null
                          ? NetworkImage(memberAvatar)
                          : null,
                      child: memberAvatar == null
                          ? Text(
                              memberName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        memberName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (!_isBondLoading && !_bondDisabled)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.favorite,
                              color: Color(0xFFFBB6CE),
                              size: 16,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '$hearts',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: Theme.of(context).colorScheme.error,
                        size: 22,
                      ),
                      onPressed: () => _confirmKickMember(index),
                      tooltip: tr('group_kick_member'),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _navigateToAddMember,
              icon: const Icon(Icons.person_add),
              label: Text(tr('group_add_member')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
