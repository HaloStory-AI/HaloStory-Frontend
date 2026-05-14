import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../utils/chat_theme_helpers.dart';
import '../../widgets/skeleton_loader.dart';

class BondStatsSheet extends StatelessWidget {
  final Map<String, dynamic>? bondData;
  final Map<String, dynamic> bot;
  final String bondStatus;
  final String bondRelationship;
  final bool isDesktop;

  const BondStatsSheet({
    super.key,
    this.bondData,
    required this.bot,
    required this.bondStatus,
    required this.bondRelationship,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    final hearts = bondData?['bond_hearts'] ?? bot['bond_hearts'] ?? 0;
    final xp = bondData?['xp'] ?? 0;
    final xpInto = bondData?['xp_into_level'] ?? 0;
    final xpPer = bondData?['xp_per_level'] ?? 5;
    final bd = bondData;
    final progress = bd != null
        ? ((bd['progress_percent'] as num?) ?? 0) / 100.0
        : 0.0;

    return Container(
      padding: EdgeInsets.fromLTRB(24, isDesktop ? 32 : 16, 24, 32),
      decoration: BoxDecoration(
        color: surfaceBackground(context),
        borderRadius: isDesktop
            ? BorderRadius.circular(24)
            : BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isDesktop)
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: parseColor(bot['color']),
                backgroundImage: bot['image_url'] != null
                    ? NetworkImage(bot['image_url'])
                    : null,
                child: bot['image_url'] == null
                    ? Text(
                        (bot['name'] as String)[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bot['name']?.toString() ?? '',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: titleColor(context),
                    ),
                  ),
                  Text(
                    '${tr('bond_total_xp')} $xp',
                    style: TextStyle(
                      fontSize: 13,
                      color: subtitleColor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: relationshipColor(bondStatus).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: relationshipColor(bondStatus).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      bondRelationship.isNotEmpty
                          ? bondRelationship
                          : (bondData?['relationship_label'] ?? tr('bond_relationship_stranger')),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: relationshipColor(bondStatus),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.favorite,
                    color: Color(0xFFFBB6CE),
                    size: 72,
                  ),
                  Text(
                    '$hearts',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('bond_level_label'),
                    style: TextStyle(
                      fontSize: 13,
                      color: subtitleColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${tr('bond_level_value')} $hearts',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${tr('bond_progress_label')} ${hearts + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: subtitleColor(context),
                    ),
                  ),
                  Text(
                    '$xpInto / $xpPer ${tr('bond_xp_unit')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: subtitleColor(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 12,
                  backgroundColor: Colors.pink.shade50,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFFFB6F9D),
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

class GroupBondStats extends StatelessWidget {
  final List<Map<String, dynamic>> groupMembers;

  const GroupBondStats({super.key, required this.groupMembers});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            tr('bond_group_levels_title'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: groupMembers.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final member = groupMembers[index];
                final hearts = member['bond_hearts'] ?? 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: parseColor(member['color']),
                    backgroundImage: member['image_url'] != null
                        ? NetworkImage(member['image_url'])
                        : (member['avatar'] != null
                              ? NetworkImage(member['avatar'])
                              : null),
                    child:
                        (member['image_url'] == null &&
                            member['avatar'] == null)
                        ? Text(
                            (member['name'] as String)[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          )
                        : null,
                  ),
                  title: Text(
                    member['name'] ?? tr('bond_unknown_member'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: titleColor(context),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.favorite,
                        color: Color(0xFFFBB6CE),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$hearts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class GroupBondSkeleton extends StatelessWidget {
  const GroupBondSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceBackground(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SkeletonWidget(width: 160, height: 20),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: 4,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const SkeletonWidget(
                        width: 40,
                        height: 40,
                        borderRadius: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonWidget(width: 120, height: 14),
                            SizedBox(height: 8),
                            SkeletonWidget(width: 80, height: 12),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const SkeletonWidget(width: 40, height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
