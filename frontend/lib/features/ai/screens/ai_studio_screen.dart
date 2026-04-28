import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AiStudioScreen extends StatefulWidget {
  const AiStudioScreen({super.key});

  @override
  State<AiStudioScreen> createState() => _AiStudioScreenState();
}

class _AiStudioScreenState extends State<AiStudioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.primary, AppTheme.secondary],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text('AI Studio'),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Caption'),
            Tab(text: 'Hashtags'),
            Tab(text: 'Hooks'),
            Tab(text: 'Ideas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _CaptionTab(),
          _HashtagTab(),
          _HookTab(),
          _IdeasTab(),
        ],
      ),
    );
  }
}

class _CaptionTab extends StatefulWidget {
  const _CaptionTab();

  @override
  State<_CaptionTab> createState() => _CaptionTabState();
}

class _CaptionTabState extends State<_CaptionTab> {
  final _topicCtrl = TextEditingController();
  String _tone = 'casual';
  String _length = 'medium';
  String? _result;
  bool _loading = false;

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _topicCtrl,
            decoration: const InputDecoration(
              labelText: 'What is your post about?',
              hintText: 'e.g. new product launch, morning routine',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          const Text('Tone', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['casual', 'excited', 'professional', 'funny', 'inspirational']
                .map(
                  (tone) => ChoiceChip(
                    label: Text(tone),
                    selected: _tone == tone,
                    onSelected: (_) => setState(() => _tone = tone),
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Length', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['short', 'medium', 'long']
                .map(
                  (length) => ChoiceChip(
                    label: Text(length),
                    selected: _length == length,
                    onSelected: (_) => setState(() => _length = length),
                    selectedColor: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_loading ? 'Generating...' : 'Generate Caption'),
            ),
          ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.05),
                    AppTheme.secondary.withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Generated Caption',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  Text(
                    _result!,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generate() async {
    if (_topicCtrl.text.isEmpty) {
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _result =
          "Something exciting is on the way. We've been working behind the "
          "scenes to build something worth sharing. Stay tuned for the full "
          "launch and let us know what you want to see first.";
    });
  }
}

class _HashtagTab extends StatefulWidget {
  const _HashtagTab();

  @override
  State<_HashtagTab> createState() => _HashtagTabState();
}

class _HashtagTabState extends State<_HashtagTab> {
  final _nicheCtrl = TextEditingController();
  final _topicCtrl = TextEditingController();
  List<String> _hashtags = [];
  bool _loading = false;

  @override
  void dispose() {
    _nicheCtrl.dispose();
    _topicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nicheCtrl,
            decoration: const InputDecoration(
              labelText: 'Your niche',
              hintText: 'e.g. fitness, fashion, tech',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _topicCtrl,
            decoration: const InputDecoration(
              labelText: 'Post topic',
              hintText: 'e.g. morning workout routine',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: const Icon(Icons.tag, size: 18),
              label: Text(_loading ? 'Generating...' : 'Generate Hashtags'),
            ),
          ),
          if (_hashtags.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Text(
                  'Generated Hashtags',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy All', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _hashtags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _hashtags = [];
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _hashtags = [
        '#FitnessMotivation',
        '#MorningWorkout',
        '#FitLife',
        '#GymLife',
        '#WorkoutRoutine',
        '#HealthyLifestyle',
        '#FitnessJourney',
        '#MorningRun',
        '#FitFam',
        '#ExerciseDaily',
      ];
    });
  }
}

class _HookTab extends StatefulWidget {
  const _HookTab();

  @override
  State<_HookTab> createState() => _HookTabState();
}

class _HookTabState extends State<_HookTab> {
  final _topicCtrl = TextEditingController();
  List<Map<String, String>> _hooks = [];
  bool _loading = false;

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Generate scroll-stopping hooks for your content',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _topicCtrl,
            decoration: const InputDecoration(
              labelText: 'Post topic',
              hintText: 'e.g. how I made INR 1L in 30 days',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: const Icon(Icons.whatshot, size: 18),
              label: Text(_loading ? 'Generating...' : 'Generate Viral Hooks'),
            ),
          ),
          ..._hooks.map(
            (hook) => Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      hook['type']!,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hook['text']!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Use this',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _hooks = [];
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _hooks = [
        {
          'type': 'CURIOSITY',
          'text':
              'Nobody talks about this simple change that helped me grow 10K followers in 30 days.',
        },
        {
          'type': 'VALUE',
          'text':
              'Five things I wish I knew before starting my social media journey.',
        },
        {
          'type': 'STORY',
          'text':
              'I was ready to quit, then one strategy changed everything for me.',
        },
        {
          'type': 'CONTROVERSY',
          'text':
              'Unpopular opinion: posting every day can hurt your growth.',
        },
        {
          'type': 'FOMO',
          'text':
              'Everyone in my niche is trying this format and the results are hard to ignore.',
        },
      ];
    });
  }
}

class _IdeasTab extends StatefulWidget {
  const _IdeasTab();

  @override
  State<_IdeasTab> createState() => _IdeasTabState();
}

class _IdeasTabState extends State<_IdeasTab> {
  final _nicheCtrl = TextEditingController();
  List<Map<String, String>> _ideas = [];
  bool _loading = false;

  @override
  void dispose() {
    _nicheCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nicheCtrl,
            decoration: const InputDecoration(
              labelText: 'Your niche',
              hintText: 'e.g. dropshipping, fitness, cooking',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: const Icon(Icons.lightbulb_outline, size: 18),
              label: Text(_loading ? 'Generating...' : 'Get Content Ideas'),
            ),
          ),
          ..._ideas.map(
            (idea) => Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          idea['title']!,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          idea['format']!,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppTheme.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    idea['why']!,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _ideas = [];
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) {
      return;
    }

    setState(() {
      _loading = false;
      _ideas = [
        {
          'title': 'Day in my life as a creator in your niche',
          'format': 'Reel',
          'why': 'Personal content usually earns more saves and replies.',
        },
        {
          'title': 'Top five mistakes beginners make',
          'format': 'Carousel',
          'why': 'Educational carousels are highly shareable.',
        },
        {
          'title': 'Before and after transformation',
          'format': 'Post',
          'why': 'This format is easy to produce and performs well.',
        },
        {
          'title': 'React to viral content in your niche',
          'format': 'Reel',
          'why': 'Trending audio plus reaction content creates momentum.',
        },
        {
          'title': 'Answer your most common DMs publicly',
          'format': 'Story',
          'why': 'This builds trust and gives followers fast value.',
        },
      ];
    });
  }
}
