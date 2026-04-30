import 'package:flutter/material.dart';
import '../models/social_account.dart';

class OAuthSheet extends StatelessWidget {
  final SocialPlatform platform;
  const OAuthSheet({super.key, required this.platform});

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(platform.color);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(platformIcon(platform), color: color, size: 32),
          ),
          const SizedBox(height: 16),
          Text('Connect ${platform.label}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'You\'ll be redirected to ${platform.label} to authorize AutoPost AI.\n\nWe only request posting permissions — we never access your password.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.lock_outline, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tokens are encrypted and stored securely. You can disconnect anytime.',
                  style: TextStyle(fontSize: 11, color: Colors.green),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context, false);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'OAuth for ${platform.label} — configure app credentials in .env to enable'),
                  duration: const Duration(seconds: 4),
                ));
              },
              icon: Icon(platformIcon(platform), size: 18),
              label: Text('Continue with ${platform.label}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

Color _hexColor(String hex) =>
    Color(int.parse('FF$hex', radix: 16));

IconData platformIcon(SocialPlatform p) {
  switch (p) {
    case SocialPlatform.instagram: return Icons.camera_alt_rounded;
    case SocialPlatform.facebook:  return Icons.facebook_rounded;
    case SocialPlatform.twitter:   return Icons.close;
    case SocialPlatform.linkedin:  return Icons.work_rounded;
    case SocialPlatform.youtube:   return Icons.play_circle_fill_rounded;
  }
}
