import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../utils/chat_theme_helpers.dart';

class StudentBioSheet extends StatelessWidget {
  final Map<String, dynamic> bot;
  final bool isDesktop;

  const StudentBioSheet({
    super.key,
    required this.bot,
    this.isDesktop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: surfaceBackground(context),
        borderRadius: isDesktop
            ? BorderRadius.circular(24)
            : BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          if (!isDesktop)
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildAvatar(context),
                  const SizedBox(height: 16),
                  _buildName(context),
                  _buildBirthday(context),
                  const SizedBox(height: 12),
                  _buildDescription(context),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildPersonalitySection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 60,
      backgroundColor: parseColor(bot['color']),
      backgroundImage: bot['image_url'] != null
          ? NetworkImage(bot['image_url'])
          : null,
      child: bot['image_url'] == null
          ? Text(
              bot['name'][0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }

  Widget _buildName(BuildContext context) {
    return Text(
      bot['name'],
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: titleColor(context),
      ),
    );
  }

  Widget _buildBirthday(BuildContext context) {
    final birthdayStr = bot['birthday'];
    if (birthdayStr == null || birthdayStr == '') return const SizedBox.shrink();
    try {
      final birthday = DateTime.parse(birthdayStr.toString());
      final now = DateTime.now();
      if (birthday.month == now.month && birthday.day == now.day) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            tr('bio_birthday_today'),
            style: TextStyle(
              color: Colors.pinkAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
    } catch (_) {}
    return const SizedBox.shrink();
  }

  Widget _buildDescription(BuildContext context) {
    return Text(
      bot['description'] ?? tr('bio_no_description'),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        color: subtitleColor(context),
        fontStyle: FontStyle.italic,
      ),
    );
  }

  Widget _buildPersonalitySection(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('personality_title_label'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildPersonalityContent(context),
        ],
      ),
    );
  }

  Widget _buildPersonalityContent(BuildContext context) {
    final pData = bot['personality'] ?? '';
    if (pData.trim().isEmpty) {
      return Text(
        tr('bio_no_personality'),
        style: TextStyle(
          fontSize: 15,
          color: subtitleColor(context),
        ),
      );
    }

    final attrs = _parseBioAttributes(pData.toString());

    return Column(
      children: [
        _buildBioRow(context, 'Nickname', attrs['Nickname']!),
        _buildBioRow(context, 'Age', attrs['Age']!),
        _buildBioRow(context, 'Nationality', attrs['Nationality']!),
        _buildBioRow(context, 'Height', attrs['Height']!),
        _buildBioRow(context, 'Weight', attrs['Weight']!),
        _buildBioRow(context, 'Like', attrs['Like']!),
        _buildBioRow(context, 'Dislike', attrs['Dislike']!),
      ],
    );
  }

  Map<String, String> _parseBioAttributes(String personality) {
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
      final regExp = RegExp(pattern, caseSensitive: false, multiLine: true);
      final match = regExp.firstMatch(personality);
      if (match != null && match.groupCount >= 1) {
        String val = match.group(1)!.trim();
        val = val.replaceAll(RegExp('^["\'*]+|["\'*]+\$'), '').trim();
        if (val.endsWith(',')) {
          val = val.substring(0, val.length - 1).trim();
        }
        return val;
      }
      return null;
    }

    result['Nickname'] = findMatch(r'(?:Nickname|Alias(?:es)?)\s*[:\-]\s*(.+)$') ?? '*Unknown*';
    result['Age'] = findMatch(r'Age\s*[:\-]\s*(.+)$') ?? '*Unknown*';
    result['Nationality'] = findMatch(r'(?:Nationality|Country)\s*[:\-]\s*(.+)$') ?? '*Unknown*';
    result['Height'] = findMatch(r'Height\s*[:\-]\s*(.+)$') ?? '*Unknown*';
    result['Weight'] = findMatch(r'Weight\s*[:\-]\s*(.+)$') ?? '*Unknown*';
    result['Like'] = findMatch(r'Like(?:s)?\s*[:\-]\s*(.+)$') ?? '*Unknown*';
    result['Dislike'] = findMatch(r'Dislike(?:s)?\s*[:\-]\s*(.+)$') ?? '*Unknown*';

    return result;
  }

  Widget _buildBioRow(BuildContext context, String label, String value) {
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
                color: subtitleColor(context),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: titleColor(context),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
