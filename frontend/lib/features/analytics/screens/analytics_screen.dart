import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _period = '7d';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '7d', label: Text('7D')),
              ButtonSegment(value: '30d', label: Text('30D')),
              ButtonSegment(value: '90d', label: Text('90D')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
            style: ButtonStyle(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Overview cards
          _OverviewCards(),
          const SizedBox(height: 20),

          // Engagement chart
          const Text('Engagement Rate', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _EngagementChart(),
          const SizedBox(height: 20),

          // Follower growth
          const Text('Follower Growth', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _FollowerGrowthChart(),
          const SizedBox(height: 20),

          // Top posts
          const Text('Top Performing Posts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _TopPosts(),
          const SizedBox(height: 20),

          // Platform breakdown
          const Text('Platform Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _PlatformBreakdown(),
        ]),
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric('Total Reach', '48.2K', '+12%', true, AppTheme.primary),
      _Metric('Impressions', '124K', '+8%', true, AppTheme.secondary),
      _Metric('Engagement', '4.8%', '+0.3%', true, AppTheme.accent),
      _Metric('Followers', '12.4K', '+340', true, AppTheme.warning),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: metrics.map((m) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: m.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: m.color.withValues(alpha: 0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(m.label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(m.value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: m.color)),
          Row(children: [
            Icon(m.positive ? Icons.trending_up : Icons.trending_down,
              size: 12, color: m.positive ? Colors.green : Colors.red),
            const SizedBox(width: 4),
            Text(m.change, style: TextStyle(
              fontSize: 11, color: m.positive ? Colors.green : Colors.red, fontWeight: FontWeight.w500)),
          ]),
        ]),
      )).toList(),
    );
  }
}

class _Metric {
  final String label, value, change;
  final bool positive;
  final Color color;
  const _Metric(this.label, this.value, this.change, this.positive, this.color);
}

class _EngagementChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spots = [
      FlSpot(0, 3.2), FlSpot(1, 4.1), FlSpot(2, 3.8), FlSpot(3, 5.2),
      FlSpot(4, 4.8), FlSpot(5, 6.1), FlSpot(6, 4.9),
    ];

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  final index = v.toInt();
                  if (index < 0 || index >= days.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    days[index],
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
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
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowerGrowthChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final data = [120, 180, 150, 220, 280, 310, 290];

    return Container(
      height: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final index = v.toInt();
                  if (index < 0 || index >= days.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    days[index],
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((e) => BarChartGroupData(
            x: e.key,
            barRods: [BarChartRodData(
              toY: e.value.toDouble(),
              color: AppTheme.secondary,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            )],
          )).toList(),
        ),
      ),
    );
  }
}

class _TopPosts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (i) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.image, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Post caption preview ${i + 1}...', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
            const SizedBox(height: 4),
            Row(children: [
              _MiniStat(Icons.favorite, '${(i + 1) * 234}'),
              const SizedBox(width: 12),
              _MiniStat(Icons.comment, '${(i + 1) * 45}'),
              const SizedBox(width: 12),
              _MiniStat(Icons.share, '${(i + 1) * 12}'),
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${(5 - i).toStringAsFixed(1)}%',
              style: const TextStyle(color: AppTheme.secondary, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ]),
      )),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  const _MiniStat(this.icon, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Colors.grey),
      const SizedBox(width: 3),
      Text(value, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]);
  }
}

class _PlatformBreakdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final platforms = [
      _PlatformStat('Instagram', 0.45, const Color(0xFFE1306C)),
      _PlatformStat('Facebook', 0.25, const Color(0xFF1877F2)),
      _PlatformStat('Twitter/X', 0.20, Colors.black),
      _PlatformStat('LinkedIn', 0.10, const Color(0xFF0A66C2)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: platforms.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(p.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const Spacer(),
              Text('${(p.share * 100).toInt()}%', style: TextStyle(fontSize: 12, color: p.color, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: p.share,
                backgroundColor: p.color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(p.color),
                minHeight: 6,
              ),
            ),
          ]),
        )).toList(),
      ),
    );
  }
}

class _PlatformStat {
  final String name;
  final double share;
  final Color color;
  const _PlatformStat(this.name, this.share, this.color);
}
