import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../accounts/models/social_account.dart';
import '../../accounts/services/accounts_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final accountsAsync = ref.watch(accountsProvider);
    final firstName = (user?.displayName ?? 'there').split(' ').first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(accountsProvider),
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────────
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$greeting, $firstName',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.normal)),
                  const Text('AutoPost AI',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {},
                ),
                GestureDetector(
                  onTap: () => context.go('/settings'),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primary,
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? Text(
                            firstName[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Stats ──────────────────────────────────
                  _StatsGrid(),
                  const SizedBox(height: 24),

                  // ── Connected Accounts ─────────────────────
                  _SectionHeader(
                    title: 'Accounts',
                    action: 'Manage',
                    onAction: () => context.go('/settings'),
                  ),
                  const SizedBox(height: 12),
                  accountsAsync.when(
                    loading: () => const _AccountsShimmer(),
                    error: (_, __) => _AddAccountBanner(
                        onTap: () => context.go('/settings')),
                    data: (accounts) => accounts.isEmpty
                        ? _AddAccountBanner(
                            onTap: () => context.go('/settings'))
                        : _AccountsRow(accounts: accounts),
                  ),
                  const SizedBox(height: 24),

                  // ── Quick Actions ──────────────────────────
                  _SectionHeader(title: 'Quick Actions'),
                  const SizedBox(height: 12),
                  _QuickActions(),
                  const SizedBox(height: 24),

                  // ── Upcoming Posts ─────────────────────────
                  _SectionHeader(
                    title: 'Upcoming Posts',
                    action: 'See all',
                    onAction: () => context.go('/calendar'),
                  ),
                  const SizedBox(height: 12),
                  const _UpcomingPosts(),
                  const SizedBox(height: 24),

                  // ── AI Ideas ───────────────────────────────
                  _SectionHeader(title: 'AI Content Ideas'),
                  const SizedBox(height: 12),
                  const _AiIdeas(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────
class _StatsGrid extends StatelessWidget {
  final _stats = const [
    _StatData('Posts', '—', Icons.article_outlined, AppTheme.primary),
    _StatData('Reach', '—', Icons.people_outline, AppTheme.secondary),
    _StatData('Engagement', '—', Icons.favorite_outline, AppTheme.accent),
    _StatData('Scheduled', '—', Icons.schedule_outlined, AppTheme.warning),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: _stats.map((s) => _StatCard(stat: s)).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _StatData stat;
  const _StatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: stat.color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: stat.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(stat.icon, color: stat.color, size: 14),
            ),
            const Spacer(),
            Text('↑ —',
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.green[400],
                    fontWeight: FontWeight.w500)),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(stat.value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: stat.color)),
            Text(stat.label,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ]),
        ],
      ),
    );
  }
}

class _StatData {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatData(this.label, this.value, this.icon, this.color);
}

// ── Accounts Row ──────────────────────────────────────────────
class _AccountsRow extends StatelessWidget {
  final List<SocialAccount> accounts;
  const _AccountsRow({required this.accounts});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...accounts.map((a) {
            final color =
                Color(int.parse('FF${a.platform.color}', radix: 16));
            final isExpired = a.status == AccountStatus.expired;
            return Container(
              width: 60,
              margin: const EdgeInsets.only(right: 10),
              child: Column(children: [
                Stack(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isExpired
                            ? Colors.orange.withValues(alpha: 0.6)
                            : color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(_icon(a.platform), color: color, size: 20),
                  ),
                  if (isExpired)
                    Positioned(
                      top: 0, right: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: const BoxDecoration(
                            color: Colors.orange, shape: BoxShape.circle),
                        child: const Icon(Icons.warning,
                            size: 8, color: Colors.white),
                      ),
                    )
                  else
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 12, height: 12,
                        decoration: const BoxDecoration(
                            color: Colors.green, shape: BoxShape.circle),
                      ),
                    ),
                ]),
                const SizedBox(height: 4),
                Text(a.platform.label.split(' ').first,
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                    overflow: TextOverflow.ellipsis),
              ]),
            );
          }),
          // Add button
          GestureDetector(
            onTap: () => GoRouter.of(context).go('/settings'),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.3),
                    style: BorderStyle.solid),
              ),
              child: Icon(Icons.add, color: Colors.grey[500], size: 20),
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon(SocialPlatform p) {
    switch (p) {
      case SocialPlatform.instagram: return Icons.camera_alt_rounded;
      case SocialPlatform.facebook:  return Icons.facebook_rounded;
      case SocialPlatform.twitter:   return Icons.close;
      case SocialPlatform.linkedin:  return Icons.work_rounded;
      case SocialPlatform.youtube:   return Icons.play_circle_fill_rounded;
    }
  }
}

// ── Add Account Banner ────────────────────────────────────────
class _AddAccountBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AddAccountBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.2),
              style: BorderStyle.solid),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.add_link, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Connect your accounts',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('Link Instagram, Facebook, Twitter & more',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ]),
      ),
    );
  }
}

// ── Accounts Shimmer ──────────────────────────────────────────
class _AccountsShimmer extends StatelessWidget {
  const _AccountsShimmer();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          width: 44, height: 44,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ── Quick Actions ─────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final _actions = const [
    _ActionData('New Post', Icons.add_circle_outline_rounded, AppTheme.primary, '/create'),
    _ActionData('AI Studio', Icons.auto_awesome_rounded, AppTheme.secondary, '/ai-studio'),
    _ActionData('Calendar', Icons.calendar_month_rounded, AppTheme.accent, '/calendar'),
    _ActionData('Analytics', Icons.bar_chart_rounded, AppTheme.warning, '/analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _actions.map((a) => Expanded(
        child: GestureDetector(
          onTap: () => context.go(a.path),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: a.color.withValues(alpha: 0.15)),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: a.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(a.icon, color: a.color, size: 18),
              ),
              const SizedBox(height: 6),
              Text(a.label,
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      )).toList(),
    );
  }
}

class _ActionData {
  final String label, path;
  final IconData icon;
  final Color color;
  const _ActionData(this.label, this.icon, this.color, this.path);
}

// ── Upcoming Posts ────────────────────────────────────────────
class _UpcomingPosts extends StatelessWidget {
  const _UpcomingPosts();

  @override
  Widget build(BuildContext context) {
    // Real data will come from Firestore/API stream
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: [
        Icon(Icons.calendar_today_outlined, size: 36, color: Colors.grey[400]),
        const SizedBox(height: 10),
        Text('No scheduled posts',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: Colors.grey[400])),
        const SizedBox(height: 4),
        Text('Create your first post to see it here',
            style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.go('/create'),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Create Post', style: TextStyle(fontSize: 13)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: AppTheme.primary),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }
}

// ── AI Ideas ──────────────────────────────────────────────────
class _AiIdeas extends StatelessWidget {
  const _AiIdeas();

  static const _ideas = [
    _IdeaData(
        'Behind-the-scenes content performs 3× better this week',
        Icons.video_camera_back_outlined,
        AppTheme.primary),
    _IdeaData(
        '"Day in my life" reels are trending in your niche',
        Icons.trending_up_rounded,
        AppTheme.secondary),
    _IdeaData(
        'Post a poll — engagement is up 40% on Tuesdays',
        Icons.poll_outlined,
        AppTheme.accent),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _ideas.map((idea) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: idea.color.withValues(alpha: 0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: idea.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(idea.icon, color: idea.color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(idea.text,
                style: const TextStyle(fontSize: 12, height: 1.4)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.go('/ai-studio'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: idea.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Use',
                  style: TextStyle(
                      fontSize: 11,
                      color: idea.color,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      )).toList(),
    );
  }
}

class _IdeaData {
  final String text;
  final IconData icon;
  final Color color;
  const _IdeaData(this.text, this.icon, this.color);
}

// ── Section Header ────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(title,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.bold)),
      const Spacer(),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(action!,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600)),
        ),
    ]);
  }
}
