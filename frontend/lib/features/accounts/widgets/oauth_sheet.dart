import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../models/social_account.dart';
import '../services/oauth_service.dart';
import '../services/accounts_service.dart';

class OAuthSheet extends ConsumerStatefulWidget {
  final SocialPlatform platform;
  const OAuthSheet({super.key, required this.platform});

  @override
  ConsumerState<OAuthSheet> createState() => _OAuthSheetState();
}

class _OAuthSheetState extends ConsumerState<OAuthSheet> {
  bool _loading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(widget.platform.color);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Platform icon
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(platformIcon(widget.platform), color: color, size: 32),
          ),
          const SizedBox(height: 16),

          Text('Connect ${widget.platform.label}',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'You\'ll be redirected to ${widget.platform.label} to authorize AutoPost AI.\n\nWe only request posting permissions — we never access your password.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: Colors.grey[500], height: 1.5),
          ),
          const SizedBox(height: 12),

          // Security note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.green.withValues(alpha: 0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.lock_outline, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Tokens are encrypted and stored securely. Disconnect anytime.',
                  style: TextStyle(fontSize: 11, color: Colors.green),
                ),
              ),
            ]),
          ),

          // Error banner
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.red)),
                ),
              ]),
            ),
          ],

          // Dev: show OAuth URL
          if (AppConfig.isDev) ...[
            const SizedBox(height: 8),
            Text(
              'OAuth: ${AppConfig.apiBaseUrl}${widget.platform.oauthPath}',
              style: TextStyle(fontSize: 9, color: Colors.grey[400]),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 20),

          // Loading state
          if (_loading) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              'Waiting for ${widget.platform.label} authorization...',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ] else ...[
            // Connect button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _connect,
                icon: Icon(platformIcon(widget.platform), size: 18),
                label: Text(
                  'Continue with ${widget.platform.label}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
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
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _connect() async {
    setState(() { _loading = true; _error = null; });

    try {
      final result = await ref
          .read(oauthServiceProvider)
          .connect(widget.platform);

      if (!mounted) return;

      if (result.success) {
        // Refresh accounts list
        ref.invalidate(accountsProvider);

        Navigator.pop(context, true);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${widget.platform.label} connected'
            '${result.username != null ? ' (@${result.username})' : ''}! ✅',
          ),
          backgroundColor: Colors.green,
        ));
      } else {
        setState(() {
          _loading = false;
          _error = result.error ?? 'Connection failed. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unexpected error: $e';
      });
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────
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
