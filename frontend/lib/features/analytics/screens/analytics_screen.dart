import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../accounts/models/social_account.dart';
import '../../accounts/services/accounts_service.dart';

// ── Analytics data provider (replace with real API call) ──────
final analyticsProvider = FutureProvider.family<Map<String, dynamic>, String>(
  (ref, period) async {
    // TODO: replace with real API call
    // final res = await ref.read(analyticsServiceProvider).fetch(period);
    await Future.delayed(const Duration(milliseconds: 600));
    return {
      'reach': '—',
      'impressions': '—',
      'engagement': '—',
      'followers': '—',
    };
  },
);

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _period = '7d';
  SocialPlatform? _filterPlatform;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // Period selector
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '7d',  label: Text('7D',  style: TextStyle(fontSize: 11))),
              ButtonSegment(value: '30d', label: Text('30D', style: TextStyle(fontSize: 11))),
              ButtonSegment(value: '90d', label: Text('90D', style: TextStyle(fontSize: 11))),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
            style: const ButtonStyle(
              padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 6)),
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _NoAccountsState(),
        data: (accounts) => accounts.isEmpty
            ? _NoAccountsState()
            : _AnalyticsBody(
                period: _period,
                accounts: accounts,
                filterPlatform: _filterPlatform,
                onPlatformFilter: (p) =>
                    setState(() => _filterPlatform = p),
              ),
      ),
    );
  }
}

// ── Analytics Body ────────────────────────────────────────────
class _AnalyticsBody extends StatelessWidget {
  final String period;
  final List<SocialAccount> accounts;
  final SocialPlatform? filterPlatform;
  final ValueChanged<SocialPlatform?> onPlatformFilter;

  const _AnalyticsBody({
    required this.period,
    required this.accounts,
    required this.filterPlatform,
    required this.onPlatformFilter,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Platform filter chips ──────────────────────────
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'All',
                selected: filterPlatform == null,
                color: AppTheme.primary,
                onTap: () => onPlatformFilter(null),
              ),
              ...accounts.map((a) {
                final color = Color(
                    int.parse('FF${a.platform.color}', radix: 16));
                return _FilterChip(
                  label: a.platform.label.split(' ').first,
                  selected: filterPlatform == a.platform,
                  color: color,
                  onTap: () => onPlatformFilter(a.platform),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Overview metrics ───────────────────────────────
        _SectionTitle('Overview'),
        const SizedBox(height: 12),
        _MetricsGrid(),
        const SizedBox(height: 24),

        // ── Engagement chart ───────────────────────────────
        _SectionTitle('Engagement Rate'),
        const SizedBox(height: 12),
        _EngagementChart(period: period),
        const SizedBox(height: 24),

        // ── Follower growth ────────────────────────────────
        _SectionTitle('Follower Growth'),
        const SizedBox(height: 12),
        _FollowerChart(period: period),
        const SizedBox(height: 24),

        // ── Platform breakdown ─────────────────────────────
        _SectionTitle('Platform Breakdown'),
        const SizedBox(height: 12),
        _PlatformBreakdown(accounts: accounts),
        const SizedBox(height: 24),

        // ── Top posts ──────────────────────────────────────
        _SectionTitle('Top Performing Posts'),
        const SizedBox(height: 12),
        _TopPosts(),
        const SizedBox(height: 24),

        // ── Best time to post ──────────────────────────────
        _SectionTitle('Best Time to Post'),
        const SizedBox(height: 12),
        _BestTimeCard(),
      ]),
    );
  }
}

// ── Metrics Grid ──────────────────────────────────────────────
class _MetricsGrid extends StatelessWidget {
  final _metrics = const [
    _MetricData('Total Reach',   '—', '—', true,  AppTheme.primary),
    _MetricData('Impressions',   '—', '—', true,  AppTheme.secondary),
    _MetricData('Engagement',    '—', '—', true,  AppTheme.accent),
    _MetricData('New Followers', '—', '—', true,  AppTheme.warning),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: _metrics.map((m) => _MetricCard(metric: m)).toList(),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricData metric;
  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: metric.color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(metric.label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(metric.value,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: metric.color)),
            Row(children: [
              Icon(
                metric.positive ? Icons.arrow_upward : Icons.arrow_downward,
                size: 11,
                color: metric.positive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 2),
              Text(metric.change,
                  style: TextStyle(
                      fontSize: 11,
                      color: metric.positive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500)),
              Text(' vs last period',
                  style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ]),
          ]),
        ],
      ),
    );
  }
}

class _MetricData {
  final String label, value, change;
  final bool positive;
  final Color color;
  const _MetricData(this.label, this.value, this.change, this.positive, this.color);
}

// ── Engagement Chart ──────────────────────────────────────────
class _EngagementChart extends StatelessWidget {
  final String period;
  const _EngagementChart({required this.period});

  @override
  Widget build(BuildContext context) {
    // Placeholder spots — replace with real API data
    final spots = [
      FlSpot(0, 0), FlSpot(1, 0), FlSpot(2, 0),
      FlSpot(3, 0), FlSpot(4, 0), FlSpot(5, 0), FlSpot(6, 0),
    ];

    return Container(
      height: 180,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(children: [
        LineChart(LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.withValues(alpha: 0.1),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}%',
                  style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                ),
              ),
            ),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  final i = v.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  return Text(days[i],
                      style: TextStyle(fontSize: 9, color: Colors.grey[500]));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppTheme.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.2),
                    AppTheme.primary.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        )),
        // No data overlay
        Center(
          child: Text('Connect accounts to see data',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ),
      ]),
    );
  }
}

// ── Follower Chart ────────────────────────────────────────────
class _FollowerChart extends StatelessWidget {
  final String period;
  const _FollowerChart({required this.period});

  @override
  Widget build(BuildContext context) {
    final data = List.filled(7, 0);

    return Container(
      height: 150,
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(children: [
        BarChart(BarChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final i = v.toInt();
                  if (i < 0 || i >= days.length) return const SizedBox.shrink();
                  return Text(days[i],
                      style: TextStyle(fontSize: 9, color: Colors.grey[500]));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((e) => BarChartGroupData(
            x: e.key,
            barRods: [BarChartRodData(
              toY: e.value.toDouble() + 0.1,
              color: AppTheme.secondary.withValues(alpha: 0.3),
              width: 14,
              borderRadius: BorderRadius.circular(4),
            )],
          )).toList(),
        )),
        Center(
          child: Text('Connect accounts to see data',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ),
      ]),
    );
  }
}

// ── Platform Breakdown ────────────────────────────────────────
class _PlatformBreakdown extends StatelessWidget {
  final List<SocialAccount> accounts;
  const _PlatformBreakdown({required this.accounts});

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return _EmptyCard('No platforms connected');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: accounts.map((a) {
          final color = Color(int.parse('FF${a.platform.color}', radix: 16));
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_icon(a.platform), color: color, size: 14),
                const SizedBox(width: 6),
                Text(a.platform.label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('—',
                    style: TextStyle(
                        fontSize: 12,
                        color: color,
                        fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 0,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 5,
                ),
              ),
            ]),
          );
        }).toList(),
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

// ── Top Posts ─────────────────────────────────────────────────
class _TopPosts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _EmptyCard('Publish posts to see top performers');
  }
}

// ── Best Time Card ────────────────────────────────────────────
class _BestTimeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppTheme.primary.withValues(alpha: 0.08),
          AppTheme.secondary.withValues(alpha: 0.08),
        ]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.schedule_rounded,
              color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI Best Time Recommendation',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            SizedBox(height: 3),
            Text(
              'Post more content to get personalized timing recommendations',
              style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── No Accounts State ─────────────────────────────────────────
class _NoAccountsState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No data yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Connect your social media accounts\nto start tracking analytics',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_link, size: 16),
            label: const Text('Connect Accounts'),
          ),
        ]),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold));
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: selected ? color : Colors.grey,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: Text(message,
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ),
    );
  }
}
