import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../constants.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import 'select_contact_screen.dart';

class StudentBioScreen extends StatefulWidget {
  final Map<String, dynamic> bot;
  final bool isGroup;
  final List<Map<String, dynamic>> groupMembers;
  final String groupName;
  final String groupBio;
  final String botId;

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

  @override
  void initState() {
    super.initState();
    _localMembers = List<Map<String, dynamic>>.from(widget.groupMembers);
    _localGroupName = widget.groupName;
    _localGroupBio = widget.groupBio;
    _loadBondData();
  }

  String get _appLanguageCode => LocalizationService().currentLocale;

  String get _resolvedDescription {
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

  Future<void> _navigateToAddMember() async {
    final existingIds = _localMembers
        .map((m) => m['bot_id']?.toString() ?? m['id']?.toString())
        .whereType<String>()
        .toSet();

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
    final nameController = TextEditingController(
      text: _localGroupName.isNotEmpty
          ? _localGroupName
          : widget.bot['name'] ?? '',
    );
    final bioController = TextEditingController(text: _localGroupBio);

    final bool? shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Group Info'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Group name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bioController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Group bio',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) return;

    final newName = nameController.text.trim();
    final newBio = bioController.text.trim();

    if (newName.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group name cannot be empty.')),
      );
      return;
    }

    widget.onEditGroupInfo?.call(newName, newBio);
    setState(() {
      _localGroupName = newName;
      _localGroupBio = newBio;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group info updated.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        widget.isGroup
            ? (_localGroupName.isNotEmpty ? _localGroupName : widget.bot['name'])
            : widget.bot['name'];

    final description = _translatedDescription ?? _resolvedDescription;

    return Scaffold(
      appBar: AppBar(
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
              if (!_isBondLoading) _buildSingleBondCard(),
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

  Widget _buildPersonalitySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Builder(
          builder: (context) {
            final pData = widget.bot['personality'] ?? '';
            if (pData.trim().isEmpty) {
              return Text(
                tr('bio_no_personality'),
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              );
            }

            Map<String, String> parseBioAttributes(String personality) {
              Map<String, String> result = {
                'Nickname': '*Unknown*',
                'Age': '*Unknown*',
                'Nationality': '*Unknown*',
                'Height': '*Unknown*',
                'Weight': '*Unknown*',
                'Like': '*Unknown*',
                'Dislike': '*Unknown*',
              };

              String? findMatch(String pattern) {
                final regExp = RegExp(
                  pattern,
                  caseSensitive: false,
                  multiLine: true,
                );
                final match = regExp.firstMatch(personality);
                if (match != null && match.groupCount >= 1) {
                  String val = match.group(1)!.trim();
                  val = val
                      .replaceAll(RegExp('^["\'*]+|["\'*]+\$'), '')
                      .trim();
                  if (val.endsWith(',')) {
                    val = val.substring(0, val.length - 1).trim();
                  }
                  return val;
                }
                return null;
              }

              result['Nickname'] =
                  findMatch(
                    r'(?:Nickname|Alias(?:es)?)\s*[:\-]\s*(.+)$',
                  ) ??
                  '*Unknown*';
              result['Age'] =
                  findMatch(r'Age\s*[:\-]\s*(.+)$') ?? '*Unknown*';
              result['Nationality'] =
                  findMatch(
                    r'(?:Nationality|Country)\s*[:\-]\s*(.+)$',
                  ) ??
                  '*Unknown*';
              result['Height'] =
                  findMatch(r'Height\s*[:\-]\s*(.+)$') ?? '*Unknown*';
              result['Weight'] =
                  findMatch(r'Weight\s*[:\-]\s*(.+)$') ?? '*Unknown*';
              result['Like'] =
                  findMatch(r'Like(?:s)?\s*[:\-]\s*(.+)$') ?? '*Unknown*';
              result['Dislike'] =
                  findMatch(r'Dislike(?:s)?\s*[:\-]\s*(.+)$') ?? '*Unknown*';

              return result;
            }

            final attrs = parseBioAttributes(pData);

            Widget buildBioRow(String label, String value) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                buildBioRow('Nickname', attrs['Nickname']!),
                buildBioRow('Age', attrs['Age']!),
                buildBioRow('Nationality', attrs['Nationality']!),
                buildBioRow('Height', attrs['Height']!),
                buildBioRow('Weight', attrs['Weight']!),
                buildBioRow('Like', attrs['Like']!),
                buildBioRow('Dislike', attrs['Dislike']!),
              ],
            );
          },
        ),
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
                    if (!_isBondLoading)
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
