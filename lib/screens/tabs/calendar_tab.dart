import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/bot_service.dart';
import '../../services/localization_service.dart';

enum CalendarSegment { calendar, birthday, event }

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key});

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab>
    with AutomaticKeepAliveClientMixin {
  final BotService _botService = BotService();
  CalendarFormat _calendarFormat = CalendarFormat.month;
  CalendarSegment _segment = CalendarSegment.calendar;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<dynamic> _allBots = [];
  bool _isLoading = true;
  String _query = '';
  final Set<String> _filters = {'birthday', 'event'};
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadBots();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBots() async {
    final bots = await _botService.getCalendarBots();
    if (mounted) {
      setState(() {
        _allBots = bots;
        _isLoading = false;
      });
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _allBots.where((bot) {
      if (bot['birthday'] == null) return false;
      try {
        final birthday = DateTime.parse(bot['birthday']);
        return birthday.month == day.month && birthday.day == day.day;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  List<dynamic> get _filteredForList {
    var list = _getEventsForDay(_selectedDay ?? _focusedDay);
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((b) => (b['name'] as String?)?.toLowerCase().contains(q) ?? false).toList();
    }
    // tag filter: birthday saja yang ada; 'event' placeholder untuk future
    if (!_filters.contains('birthday')) return [];
    return list;
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _query = v.trim());
    });
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return CustomScrollView(
      slivers: [
        // Segmented — always visible, first content under AppBar (no duplicate SliverAppBar).
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<CalendarSegment>(
              segments: [
                ButtonSegment(value: CalendarSegment.calendar, label: Text(tr('calendar_segment_calendar')), icon: const Icon(Icons.calendar_month_outlined, size: 18)),
                ButtonSegment(value: CalendarSegment.birthday, label: Text(tr('calendar_segment_birthday')), icon: const Icon(Icons.cake_outlined, size: 18)),
                ButtonSegment(value: CalendarSegment.event, label: Text(tr('calendar_segment_event')), icon: const Icon(Icons.event_outlined, size: 18)),
              ],
              selected: {_segment},
              onSelectionChanged: (s) => setState(() => _segment = s.first),
              showSelectedIcon: true,
            ),
          ),
        ),
        // Search + Filter — satukan dalam 1 sliver, sembunyi di mode calendar.
        if (_segment != CalendarSegment.calendar)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                children: [
                  SearchBar(
                    controller: _searchController,
                    hintText: tr('calendar_search_hint'),
                    leading: const Icon(Icons.search_rounded),
                    trailing: _query.isEmpty
                        ? null
                        : [
                            IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          ],
                    onChanged: _onSearchChanged,
                    elevation: const WidgetStatePropertyAll(0),
                    backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.surfaceContainerHighest),
                    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChip(
                          label: Text(tr('calendar_filter_birthday')),
                          selected: _filters.contains('birthday'),
                          onSelected: (v) => setState(() => v ? _filters.add('birthday') : _filters.remove('birthday')),
                        ),
                        FilterChip(
                          label: Text(tr('calendar_filter_event')),
                          selected: _filters.contains('event'),
                          onSelected: (v) => setState(() => v ? _filters.add('event') : _filters.remove('event')),
                        ),
                        FilterChip(
                          label: Text(tr('calendar_filter_other')),
                          selected: _filters.contains('other'),
                          onSelected: (v) => setState(() => v ? _filters.add('other') : _filters.remove('other')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_segment == CalendarSegment.calendar)
          SliverToBoxAdapter(child: _buildCalendarM3())
        else
          _buildSliverEventList(),
      ],
    );
  }

  Widget _buildCalendarM3() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Card.filled(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) => setState(() => _calendarFormat = format),
                eventLoader: _getEventsForDay,
                calendarStyle: CalendarStyle(
                  defaultTextStyle: tt.bodyMedium?.copyWith(color: cs.onSurface) ?? TextStyle(color: cs.onSurface),
                  weekendTextStyle: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant) ?? TextStyle(color: cs.onSurfaceVariant),
                  outsideTextStyle: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant.withValues(alpha: 0.6)) ?? TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                  todayDecoration: BoxDecoration(color: cs.secondaryContainer, shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                  todayTextStyle: TextStyle(color: cs.onSecondaryContainer, fontWeight: FontWeight.bold),
                  selectedTextStyle: TextStyle(color: cs.onPrimary, fontWeight: FontWeight.bold),
                  markerDecoration: BoxDecoration(color: cs.error, shape: BoxShape.circle),
                  markerSize: 6,
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekdayStyle: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant) ?? TextStyle(color: cs.onSurfaceVariant),
                  weekendStyle: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant) ?? TextStyle(color: cs.onSurfaceVariant),
                ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle: tt.titleMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold) ?? TextStyle(color: cs.primary, fontWeight: FontWeight.bold, fontSize: 18),
                  leftChevronIcon: Icon(Icons.chevron_left_rounded, color: cs.onSurface),
                  rightChevronIcon: Icon(Icons.chevron_right_rounded, color: cs.onSurface),
                  leftChevronPadding: const EdgeInsets.all(8),
                  rightChevronPadding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(height: 8),
              // reuse filtered list for calendar mode too
              ...(_filteredForList.isEmpty
                  ? [_emptyState()]
                  : _filteredForList.map((bot) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _eventCard(bot),
                      ))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverEventList() {
    final events = _filteredForList;
    if (events.isEmpty) {
      return SliverFillRemaining(hasScrollBody: false, child: _emptyState());
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      sliver: SliverList.builder(
        itemCount: events.length,
        itemBuilder: (context, index) => Padding(
          padding: EdgeInsets.only(bottom: index == events.length - 1 ? 0 : 12),
          child: _eventCard(events[index]),
        ),
      ),
    );
  }

  Widget _eventCard(dynamic bot) {
    final cs = Theme.of(context).colorScheme;
    return Card.filled(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(radius: 28, backgroundImage: CachedNetworkImageProvider((bot['thumb_url'] ?? bot['image_url']).toString())),
        title: Text(bot['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cake_rounded, size: 14, color: cs.error),
            const SizedBox(width: 4),
            Text(tr('tab_calendar_birthday_label'), style: TextStyle(color: cs.error, fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        trailing: IconButton.filledTonal(
          icon: Icon(Icons.chat_bubble_outline_rounded, color: cs.primary),
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _emptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available_rounded, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(tr('calendar_empty'), textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _query = '';
                  _filters
                    ..clear()
                    ..addAll(['birthday', 'event']);
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr('calendar_empty_action')),
            ),
          ],
        ),
      ),
    );
  }
}
