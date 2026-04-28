import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../../../core/theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _captionCtrl = TextEditingController();
  final Set<String> _selectedPlatforms = {'instagram'};
  DateTime? _scheduledAt;
  bool _aiMode = false;
  int _step = 0;

  // Media state
  final List<XFile> _mediaFiles = [];
  bool _isVideo = false;

  final _platforms = [
    _PlatformOption('instagram', 'Instagram', Icons.camera_alt,  const Color(0xFFE1306C)),
    _PlatformOption('facebook',  'Facebook',  Icons.facebook,    const Color(0xFF1877F2)),
    _PlatformOption('twitter',   'Twitter/X', Icons.close,       Colors.black),
    _PlatformOption('linkedin',  'LinkedIn',  Icons.work,        const Color(0xFF0A66C2)),
    _PlatformOption('youtube',   'YouTube',   Icons.play_circle, const Color(0xFFFF0000)),
  ];

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          if (_step > 0)
            TextButton(
              onPressed: () => setState(() => _step--),
              child: const Text('Back'),
            ),
        ],
      ),
      body: Column(
        children: [
          _StepIndicator(current: _step),
          Expanded(
            child: IndexedStack(
              index: _step,
              children: [
                _ContentStep(
                  captionCtrl: _captionCtrl,
                  aiMode: _aiMode,
                  onAiToggle: (v) => setState(() => _aiMode = v),
                  mediaFiles: _mediaFiles,
                  isVideo: _isVideo,
                  onPickImage: _pickImage,
                  onPickVideo: _pickVideo,
                  onPickCamera: _pickCamera,
                  onRemoveMedia: (i) => setState(() {
                    _mediaFiles.removeAt(i);
                    if (_mediaFiles.isEmpty) {
                      _isVideo = false;
                    }
                  }),
                ),
                _PlatformStep(
                  platforms: _platforms,
                  selected: _selectedPlatforms,
                  onToggle: (p) => setState(() {
                    _selectedPlatforms.contains(p)
                        ? _selectedPlatforms.remove(p)
                        : _selectedPlatforms.add(p);
                  }),
                ),
                _ScheduleStep(
                  scheduledAt: _scheduledAt,
                  onDateSelected: (d) => setState(() => _scheduledAt = d),
                ),
              ],
            ),
          ),
          _BottomBar(step: _step, onNext: _next, onPublish: _publish),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isNotEmpty) {
      setState(() {
        if (_isVideo) {
          _mediaFiles.clear();
        }
        _mediaFiles.addAll(files);
        _isVideo = false;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 10),
    );
    if (file != null) {
      setState(() {
        _mediaFiles
          ..clear()
          ..add(file);
        _isVideo = true;
      });
    }
  }

  Future<void> _pickCamera() async {
    // Show choice: photo or video
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.photo_camera, color: AppTheme.primary),
            title: const Text('Take Photo'),
            onTap: () => Navigator.pop(context, 'photo'),
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: AppTheme.primary),
            title: const Text('Record Video'),
            onTap: () => Navigator.pop(context, 'video'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );

    if (choice == null) return;
    final picker = ImagePicker();

    if (choice == 'photo') {
      final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (file != null) setState(() { _mediaFiles.add(file); _isVideo = false; });
    } else {
      final file = await picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 10),
      );
      if (file != null) {
        setState(() { _mediaFiles..clear()..add(file); _isVideo = true; });
      }
    }
  }

  void _next() { if (_step < 2) setState(() => _step++); }

  Future<void> _publish() async {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_scheduledAt != null ? 'Post scheduled! ✅' : 'Post published! 🚀'),
      backgroundColor: AppTheme.secondary,
    ));
    context.go('/dashboard');
  }
}

// ── Step Indicator ────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    final steps = ['Content', 'Platforms', 'Schedule'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive   = i == current;
          final isComplete = i < current;
          return Expanded(
            child: Row(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: isComplete
                      ? AppTheme.secondary
                      : isActive
                          ? AppTheme.primary
                          : Colors.grey.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isComplete
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : Text('${i + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          )),
                ),
              ),
              const SizedBox(width: 6),
              Text(steps[i],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? AppTheme.primary : Colors.grey,
                  )),
              if (i < steps.length - 1) ...[
                const SizedBox(width: 6),
                Expanded(child: Container(height: 1, color: Colors.grey.withValues(alpha: 0.3))),
              ],
            ]),
          );
        }),
      ),
    );
  }
}

// ── Content Step ──────────────────────────────────────────────
class _ContentStep extends StatelessWidget {
  final TextEditingController captionCtrl;
  final bool aiMode;
  final ValueChanged<bool> onAiToggle;
  final List<XFile> mediaFiles;
  final bool isVideo;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onPickCamera;
  final ValueChanged<int> onRemoveMedia;

  const _ContentStep({
    required this.captionCtrl,
    required this.aiMode,
    required this.onAiToggle,
    required this.mediaFiles,
    required this.isVideo,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onPickCamera,
    required this.onRemoveMedia,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Media Section ─────────────────────────────────────
        if (mediaFiles.isEmpty)
          _MediaPickerEmpty(
            onPickImage: onPickImage,
            onPickVideo: onPickVideo,
            onPickCamera: onPickCamera,
          )
        else
          _MediaPreview(
            files: mediaFiles,
            isVideo: isVideo,
            onRemove: onRemoveMedia,
            onAdd: onPickImage,
          ),

        const SizedBox(height: 16),

        // ── Caption ───────────────────────────────────────────
        Row(children: [
          const Text('Caption', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          const Text('AI Generate', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Switch(value: aiMode, onChanged: onAiToggle, activeThumbColor: AppTheme.primary),
        ]),
        const SizedBox(height: 8),

        if (aiMode)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.primary.withValues(alpha: 0.1),
                AppTheme.secondary.withValues(alpha: 0.1),
              ]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: [
              const TextField(
                decoration: InputDecoration(
                  hintText: 'Describe your post topic...',
                  border: InputBorder.none,
                  filled: false,
                ),
                maxLines: 2,
              ),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Generate'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                ),
              ]),
            ]),
          )
        else
          TextField(
            controller: captionCtrl,
            maxLines: 5,
            maxLength: 2200,
            decoration: const InputDecoration(
              hintText: 'Write your caption...',
              alignLabelWithHint: true,
            ),
          ),

        const SizedBox(height: 16),

        // ── Hashtags ──────────────────────────────────────────
        Row(children: [
          const Text('Hashtags', style: TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.auto_awesome, size: 14),
            label: const Text('AI Suggest', style: TextStyle(fontSize: 12)),
          ),
        ]),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: <Widget>[
            ...['#socialmedia', '#content', '#marketing'].map((tag) => Chip(
              label: Text(tag, style: const TextStyle(fontSize: 12)),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () {},
            )),
            ActionChip(
              label: const Text('+ Add', style: TextStyle(fontSize: 12)),
              onPressed: () {},
            ),
          ],
        ),
      ]),
    );
  }
}

// ── Empty Media Picker ────────────────────────────────────────
class _MediaPickerEmpty extends StatelessWidget {
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final VoidCallback onPickCamera;

  const _MediaPickerEmpty({
    required this.onPickImage,
    required this.onPickVideo,
    required this.onPickCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Main tap area
      GestureDetector(
        onTap: onPickImage,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.25),
              style: BorderStyle.solid,
            ),
          ),
          child: const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_photo_alternate_outlined, size: 44, color: AppTheme.primary),
              SizedBox(height: 8),
              Text('Tap to add photos',
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w500)),
              SizedBox(height: 4),
              Text('or use buttons below',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Action buttons row
      Row(children: [
        Expanded(
          child: _MediaButton(
            icon: Icons.photo_library_outlined,
            label: 'Gallery',
            color: AppTheme.primary,
            onTap: onPickImage,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MediaButton(
            icon: Icons.videocam_outlined,
            label: 'Video',
            color: AppTheme.secondary,
            onTap: onPickVideo,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MediaButton(
            icon: Icons.camera_alt_outlined,
            label: 'Camera',
            color: AppTheme.accent,
            onTap: onPickCamera,
          ),
        ),
      ]),
    ]);
  }
}

class _MediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MediaButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ── Media Preview Grid ────────────────────────────────────────
class _MediaPreview extends StatelessWidget {
  final List<XFile> files;
  final bool isVideo;
  final ValueChanged<int> onRemove;
  final VoidCallback onAdd;

  const _MediaPreview({
    required this.files,
    required this.isVideo,
    required this.onRemove,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // First media large preview
      Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: isVideo
              ? _VideoThumb(file: files.first)
              : Image.file(
                  File(files.first.path),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
        ),
        // Remove button
        Positioned(
          top: 8, right: 8,
          child: GestureDetector(
            onTap: () => onRemove(0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
        if (isVideo)
          const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white, size: 48),
          ),
      ]),

      // Additional images row
      if (!isVideo && files.length > 1) ...[
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: files.length - 1 + 1, // +1 for add button
            itemBuilder: (ctx, i) {
              if (i == files.length - 1) {
                return GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 72, height: 72,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.add, color: AppTheme.primary),
                  ),
                );
              }
              return Stack(children: [
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(files[i + 1].path),
                      width: 72, height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  top: 2, right: 10,
                  child: GestureDetector(
                    onTap: () => onRemove(i + 1),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 12),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
      ],

      const SizedBox(height: 8),
      // Media info + change button
      Row(children: [
        Icon(
          isVideo ? Icons.videocam : Icons.photo_library,
          size: 14,
          color: Colors.grey,
        ),
        const SizedBox(width: 4),
        Text(
          isVideo ? '1 video selected' : '${files.length} photo${files.length > 1 ? 's' : ''} selected',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Spacer(),
        TextButton(
          onPressed: onAdd,
          child: const Text('+ Add more', style: TextStyle(fontSize: 12)),
        ),
      ]),
    ]);
  }
}

// ── Video Thumbnail ───────────────────────────────────────────
class _VideoThumb extends StatefulWidget {
  final XFile file;
  const _VideoThumb({required this.file});

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  late VideoPlayerController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.file.path))
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Container(
        height: 200,
        color: Colors.black12,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return SizedBox(
      height: 200,
      child: AspectRatio(
        aspectRatio: _ctrl.value.aspectRatio,
        child: VideoPlayer(_ctrl),
      ),
    );
  }
}

// ── Platform Step ─────────────────────────────────────────────
class _PlatformStep extends StatelessWidget {
  final List<_PlatformOption> platforms;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _PlatformStep({
    required this.platforms,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Select platforms to post on',
            style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        ...platforms.map((p) {
          final isSelected = selected.contains(p.id);
          return GestureDetector(
            onTap: () => onToggle(p.id),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? p.color.withValues(alpha: 0.1)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? p.color : Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: Row(children: [
                Icon(p.icon, color: p.color, size: 28),
                const SizedBox(width: 12),
                Text(p.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 15)),
                const Spacer(),
                if (isSelected)
                  Icon(Icons.check_circle, color: p.color)
                else
                  const Icon(Icons.circle_outlined, color: Colors.grey),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ── Schedule Step ─────────────────────────────────────────────
class _ScheduleStep extends StatelessWidget {
  final DateTime? scheduledAt;
  final ValueChanged<DateTime?> onDateSelected;

  const _ScheduleStep({
    required this.scheduledAt,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('When to post?', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 16),
        _ScheduleOption(
          title: 'Post Now',
          subtitle: 'Publish immediately',
          icon: Icons.send_rounded,
          color: AppTheme.secondary,
          isSelected: scheduledAt == null,
          onTap: () => onDateSelected(null),
        ),
        const SizedBox(height: 12),
        _ScheduleOption(
          title: 'Schedule',
          subtitle: scheduledAt != null
              ? '${scheduledAt!.day}/${scheduledAt!.month}/${scheduledAt!.year} at ${scheduledAt!.hour}:00'
              : 'Pick date & time',
          icon: Icons.schedule,
          color: AppTheme.primary,
          isSelected: scheduledAt != null,
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(hours: 1)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null && context.mounted) {
              final time = await showTimePicker(
                  context: context, initialTime: TimeOfDay.now());
              if (time != null) {
                onDateSelected(DateTime(
                    date.year, date.month, date.day, time.hour, time.minute));
              }
            }
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppTheme.primary.withValues(alpha: 0.1),
              AppTheme.secondary.withValues(alpha: 0.1),
            ]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AI Recommendation',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text('Best time: Tuesday 9:00 AM (based on your audience)',
                    style: TextStyle(fontSize: 11, color: Colors.grey)),
              ]),
            ),
            TextButton(
                onPressed: () {},
                child: const Text('Use', style: TextStyle(fontSize: 12))),
          ]),
        ),
      ]),
    );
  }
}

class _ScheduleOption extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScheduleOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? color : Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const Spacer(),
          if (isSelected) Icon(Icons.check_circle, color: color),
        ]),
      ),
    );
  }
}

// ── Bottom Bar ────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final int step;
  final VoidCallback onNext;
  final VoidCallback onPublish;

  const _BottomBar({
    required this.step,
    required this.onNext,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: step < 2 ? onNext : onPublish,
          child: Text(
            step == 0
                ? 'Choose Platforms →'
                : step == 1
                    ? 'Set Schedule →'
                    : '🚀 Publish Post',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ── Data Models ───────────────────────────────────────────────
class _PlatformOption {
  final String id, name;
  final IconData icon;
  final Color color;
  const _PlatformOption(this.id, this.name, this.icon, this.color);
}
