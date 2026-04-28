import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good morning',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.normal),
            ),
            Text(
              'AutoPost AI',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
          ),
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primary,
            child: Text(
              'U',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => Future<void>.delayed(const Duration(seconds: 1)),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _TrialBanner(),
              SizedBox(height: 16),
              _StatsRow(),
              SizedBox(height: 20),
              _SectionTitle('Quick Actions'),
              SizedBox(height: 12),
              _QuickActions(),
              SizedBox(height: 20),
              _SectionTitle('Connected Accounts'),
              SizedBox(height: 12),
              _ConnectedAccounts(),
              SizedBox(height: 20),
              _UpcomingPostsSection(),
              SizedBox(height: 20),
              _SectionTitle('AI Content Ideas'),
              SizedBox(height: 12),
              _AiSuggestions(),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}

class _TrialBanner extends StatelessWidget {
  const _TrialBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, Color(0xFF9C88FF)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pro Trial Active',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '5 days remaining - Upgrade to keep Pro features',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => context.go('/plans'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text(
              'Upgrade',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final stats = [
      _Stat('Posts', '24', Icons.article_outlined, AppTheme.primary),
      _Stat('Reach', '12.4K', Icons.people_outline, AppTheme.secondary),
      _Stat('Engagement', '4.2%', Icons.favorite_outline, AppTheme.accent),
      _Stat('Scheduled', '8', Icons.schedule, AppTheme.warning),
    ];

    return Row(
      children: stats
          .map(
            (stat) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: stat.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(stat.icon, color: stat.color, size: 20),
                    const SizedBox(height: 6),
                    Text(
                      stat.value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: stat.color,
                      ),
                    ),
                    Text(
                      stat.label,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Stat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Stat(this.label, this.value, this.icon, this.color);
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _Action('New Post', Icons.add_circle_outline, AppTheme.primary, '/create'),
      _Action('AI Studio', Icons.auto_awesome, AppTheme.secondary, '/ai-studio'),
      _Action('Calendar', Icons.calendar_month, AppTheme.accent, '/calendar'),
      _Action('Analytics', Icons.bar_chart, AppTheme.warning, '/analytics'),
    ];

    return Row(
      children: actions
          .map(
            (action) => Expanded(
              child: GestureDetector(
                onTap: () => context.go(action.path),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: action.color.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Icon(action.icon, color: action.color, size: 24),
                      const SizedBox(height: 6),
                      Text(
                        action.label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _Action {
  final String label;
  final IconData icon;
  final Color color;
  final String path;

  const _Action(this.label, this.icon, this.color, this.path);
}

class _ConnectedAccounts extends StatelessWidget {
  const _ConnectedAccounts();

  @override
  Widget build(BuildContext context) {
    final platforms = [
      _Platform(Icons.camera_alt, const Color(0xFFE1306C)),
      _Platform(Icons.facebook, const Color(0xFF1877F2)),
      _Platform(Icons.close, Colors.black),
      _Platform(Icons.work, const Color(0xFF0A66C2)),
      _Platform(Icons.play_circle, const Color(0xFFFF0000)),
    ];

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: platforms.length + 1,
        itemBuilder: (context, index) {
          if (index == platforms.length) {
            return GestureDetector(
              onTap: () => context.go('/settings'),
              child: Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.add, color: Colors.grey),
              ),
            );
          }

          final platform = platforms[index];
          return Container(
            width: 64,
            height: 64,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: platform.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(platform.icon, color: platform.color, size: 28),
          );
        },
      ),
    );
  }
}

class _Platform {
  final IconData icon;
  final Color color;

  const _Platform(this.icon, this.color);
}

class _UpcomingPostsSection extends StatelessWidget {
  const _UpcomingPostsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle('Upcoming Posts'),
            TextButton(
              onPressed: () => context.go('/calendar'),
              child: const Text('See all'),
            ),
          ],
        ),
        const _UpcomingPosts(),
      ],
    );
  }
}

class _UpcomingPosts extends StatelessWidget {
  const _UpcomingPosts();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Post ${index + 1}: Sample caption text...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          'Tomorrow at ${9 + index}:00 AM',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiSuggestions extends StatelessWidget {
  const _AiSuggestions();

  @override
  Widget build(BuildContext context) {
    final ideas = [
      'Behind-the-scenes content performs 3x better this week',
      '"Day in my life" reels are trending in your niche',
      'Post a poll - engagement is up 40% on Tuesdays',
    ];

    return Column(
      children: ideas
          .map(
            (idea) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.05),
                    AppTheme.secondary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(idea, style: const TextStyle(fontSize: 13)),
                  ),
                  TextButton(
                    onPressed: () => context.go('/ai-studio'),
                    child: const Text(
                      'Use',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
