import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../accounts/models/social_account.dart';

// ── Firestore posts stream provider ──────────────────────────
final scheduledPostsProvider = StreamProvider<List<_PostEvent>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('posts')
      .where('uid', isEqualTo: uid)
      .where('status', isEqualTo: 'scheduled')
      .orderBy('scheduled_at')
      .snapshots()
      .map((snap) => snap.docs.map((doc) {
            final data = doc.data();
            final ts = data['scheduled_at'];
            DateTime? scheduledAt;
            if (ts is Timestamp) scheduledAt = ts.toDate();

            return _PostEvent(
              id: doc.id,
              caption: data['caption'] as String? ?? '',
              platforms: List<String>.from(data['platforms'] ?? []),
              scheduledAt: scheduledAt,
              mediaType: data['media_type'] as String? ?? 'image',
              status: data['status'] as String? ?? 'scheduled',
            );
          }).toList());
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  CalendarFormat _format = CalendarFormat.month;

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(scheduledPostsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Content Calendar',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.go('/create'),
            tooltip: 'Schedule Post',
          ),
        ],
      ),
      body: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (posts) {
          // Group posts by date
          final Map<DateTime, List<_PostEvent>> eventMap = {};
          for (final post in posts) {
            if (post.scheduledAt != null) {
              final day = _dayOnly(post.scheduledAt!);
              eventMap.putIfAbsent(day, () => []).add(post);
            }
          }

          final selectedPosts = _selected != null
              ? (eventMap[_dayOnly(_selected!)] ?? [])
              : [];

          return Column(children: [
            // ── Calendar ─────────────────────────────────
            TableCalendar<_PostEvent>(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2027, 12, 31),
              focusedDay: _focused,
              calendarFormat: _format,
              selectedDayPredicate: (day) => isSameDay(_selected, day),
              eventLoader: (day) => eventMap[_dayOnly(day)] ?? [],
              onDaySelected: (selected, focused) =>
                  setState(() {
                    _selected = selected;
                    _focused = focused;
                  }),
              onFormatChanged: (f) => setState(() => _format = f),
              calendarBuilders: CalendarBuilders(
                markerBuilder: (ctx, day, events) {
                  if (events.isEmpty) return null;
                  return Positioned(
                    bottom: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: events.take(3).map((e) {
                        final p = (e as _PostEvent).platforms.isNotEmpty
                            ? e.platforms.first
                            : 'instagram';
                        return Container(
                          width: 5, height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: BoxDecoration(
                            color: _platformColor(p),
                            shape: BoxShape.circle,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: const BoxDecoration(
                    color: AppTheme.primary, shape: BoxShape.circle),
                todayDecoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                outsideDaysVisible: false,
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: true,
                titleCentered: true,
                formatButtonShowsNext: false,
              ),
            ),

            const Divider(height: 1),

            // ── Post count for selected day ───────────────
            if (_selected != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(children: [
                  Text(
                    '${_selected!.day}/${_selected!.month}/${_selected!.year}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${selectedPosts.length} post${selectedPosts.length != 1 ? 's' : ''}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),

            // ── Posts list ────────────────────────────────
            Expanded(
              child: selectedPosts.isEmpty
                  ? _EmptyDay(
                      hasDate: _selected != null,
                      onSchedule: () => context.go('/create'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: selectedPosts.length,
                      itemBuilder: (_, i) =>
                          _PostCard(post: selectedPosts[i] as _PostEvent),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Post Card ─────────────────────────────────────────────────
class _PostCard extends StatelessWidget {
  final _PostEvent post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    final time = post.scheduledAt != null
        ? '${post.scheduledAt!.hour.toString().padLeft(2, '0')}:${post.scheduledAt!.minute.toString().padLeft(2, '0')}'
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        // Time indicator
        Container(
          width: 4, height: 52,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),

        // Media icon
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            post.mediaType == 'video'
                ? Icons.videocam_rounded
                : Icons.image_rounded,
            color: AppTheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),

        // Content
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.caption.isNotEmpty
                      ? post.caption
                      : 'No caption',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.schedule_rounded,
                      size: 11, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey)),
                  const SizedBox(width: 10),
                  // Platform dots
                  ...post.platforms.take(4).map((p) => Container(
                        width: 14, height: 14,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          color: _platformColor(p).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            p[0].toUpperCase(),
                            style: TextStyle(
                                fontSize: 7,
                                color: _platformColor(p),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      )),
                ]),
              ]),
        ),

        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _statusColor(post.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            post.status,
            style: TextStyle(
                fontSize: 10,
                color: _statusColor(post.status),
                fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }
}

// ── Empty Day ─────────────────────────────────────────────────
class _EmptyDay extends StatelessWidget {
  final bool hasDate;
  final VoidCallback onSchedule;

  const _EmptyDay({required this.hasDate, required this.onSchedule});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.calendar_today_outlined,
            size: 44, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(
          hasDate ? 'No posts scheduled' : 'Select a date',
          style: TextStyle(
              fontWeight: FontWeight.w600, color: Colors.grey[500]),
        ),
        if (hasDate) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onSchedule,
            icon: const Icon(Icons.add, size: 14),
            label: const Text('Schedule Post',
                style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────
Color _platformColor(String platform) {
  switch (platform) {
    case 'instagram': return const Color(0xFFE1306C);
    case 'facebook':  return const Color(0xFF1877F2);
    case 'twitter':   return Colors.black;
    case 'linkedin':  return const Color(0xFF0A66C2);
    case 'youtube':   return const Color(0xFFFF0000);
    default:          return AppTheme.primary;
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'scheduled':  return Colors.blue;
    case 'published':  return Colors.green;
    case 'failed':     return Colors.red;
    case 'draft':      return Colors.grey;
    default:           return Colors.grey;
  }
}

// ── Post Event Model ──────────────────────────────────────────
class _PostEvent {
  final String id;
  final String caption;
  final List<String> platforms;
  final DateTime? scheduledAt;
  final String mediaType;
  final String status;

  const _PostEvent({
    required this.id,
    required this.caption,
    required this.platforms,
    required this.scheduledAt,
    required this.mediaType,
    required this.status,
  });
}
