import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AutomationScreen extends StatelessWidget {
  const AutomationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Automation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _ProBanner(),
            SizedBox(height: 20),
            _SectionTitle('Auto Reply'),
            SizedBox(height: 12),
            _AutomationCard(
              title: 'Comment Auto Reply',
              subtitle: 'Reply to comments with keywords automatically',
              icon: Icons.comment_outlined,
              color: AppTheme.primary,
              isActive: true,
            ),
            _AutomationCard(
              title: 'DM Auto Responder',
              subtitle: 'Send instant replies to new DMs',
              icon: Icons.message_outlined,
              color: AppTheme.secondary,
              isActive: false,
            ),
            SizedBox(height: 20),
            _SectionTitle('Smart Posting'),
            SizedBox(height: 12),
            _AutomationCard(
              title: 'Auto Repost Top Content',
              subtitle: 'Automatically repost your best performing posts',
              icon: Icons.repeat_rounded,
              color: AppTheme.accent,
              isActive: true,
            ),
            _AutomationCard(
              title: 'Blog -> Social Post',
              subtitle: 'Auto-post when a new blog article is published',
              icon: Icons.rss_feed,
              color: AppTheme.warning,
              isActive: false,
            ),
            SizedBox(height: 20),
            _SectionTitle('Triggers'),
            SizedBox(height: 12),
            _AutomationCard(
              title: 'Engagement Threshold',
              subtitle: 'Post when engagement drops below target',
              icon: Icons.trending_down,
              color: Colors.orange,
              isActive: false,
            ),
            _AutomationCard(
              title: 'Trending Alert Post',
              subtitle: 'Create a post when a topic trends in your niche',
              icon: Icons.whatshot,
              color: Colors.red,
              isActive: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProBanner extends StatelessWidget {
  const _ProBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, Color(0xFF9C88FF)],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.bolt, color: Colors.white),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Automation is a Pro feature',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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

class _AutomationCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isActive;

  const _AutomationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isActive,
  });

  @override
  State<_AutomationCard> createState() => _AutomationCardState();
}

class _AutomationCardState extends State<_AutomationCard> {
  late bool _active;

  @override
  void initState() {
    super.initState();
    _active = widget.isActive;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _active
              ? widget.color.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, color: widget.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  widget.subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: _active,
            onChanged: (value) => setState(() => _active = value),
            activeThumbColor: widget.color,
          ),
        ],
      ),
    );
  }
}
