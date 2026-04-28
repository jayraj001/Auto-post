import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  CalendarFormat _format = CalendarFormat.month;

  // Mock scheduled posts
  late final Map<DateTime, List<_ScheduledPost>> _events = {
    _dayOnly(DateTime.now().add(const Duration(days: 1))): [
      _ScheduledPost('Morning motivation post', '09:00', ['instagram', 'facebook']),
    ],
    _dayOnly(DateTime.now().add(const Duration(days: 2))): [
      _ScheduledPost('Product showcase', '11:00', ['instagram']),
      _ScheduledPost('LinkedIn article', '14:00', ['linkedin']),
    ],
    _dayOnly(DateTime.now().add(const Duration(days: 4))): [
      _ScheduledPost('Weekend special offer', '10:00', ['instagram', 'facebook', 'twitter']),
    ],
  };

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  List<_ScheduledPost> _getEvents(DateTime day) {
    return _events[_dayOnly(day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final selectedPosts = _selected != null ? _getEvents(_selected!) : [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.go('/create'),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar<_ScheduledPost>(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2027, 12, 31),
            focusedDay: _focused,
            calendarFormat: _format,
            selectedDayPredicate: (day) => isSameDay(_selected, day),
            eventLoader: _getEvents,
            onDaySelected: (selected, focused) {
              setState(() { _selected = selected; _focused = focused; });
            },
            onFormatChanged: (f) => setState(() => _format = f),
            calendarStyle: CalendarStyle(
              markerDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: selectedPosts.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.calendar_today, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text(
                      _selected == null ? 'Select a date to view posts' : 'No posts scheduled',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (_selected != null) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/create'),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Schedule Post'),
                      ),
                    ],
                  ]),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: selectedPosts.length,
                  itemBuilder: (ctx, i) {
                    final post = selectedPosts[i];
                    return _PostCard(post: post);
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final _ScheduledPost post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final platformColors = {
      'instagram': const Color(0xFFE1306C),
      'facebook': const Color(0xFF1877F2),
      'twitter': Colors.black,
      'linkedin': const Color(0xFF0A66C2),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          width: 4, height: 50,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(post.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.schedule, size: 12, color: Colors.grey),
            const SizedBox(width: 4),
            Text(post.time, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 12),
            ...post.platforms.map((p) => Container(
              margin: const EdgeInsets.only(right: 4),
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: platformColors[p]?.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(p[0].toUpperCase(),
                style: TextStyle(fontSize: 8, color: platformColors[p], fontWeight: FontWeight.bold))),
            )),
          ]),
        ])),
        PopupMenuButton(
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
      ]),
    );
  }
}

class _ScheduledPost {
  final String title, time;
  final List<String> platforms;
  const _ScheduledPost(this.title, this.time, this.platforms);
}
