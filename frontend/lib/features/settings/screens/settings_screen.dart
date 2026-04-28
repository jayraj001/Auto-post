import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../auth/services/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile section
          _SectionHeader('Profile'),
          ListTile(
            leading: const CircleAvatar(backgroundColor: AppTheme.primary,
              child: Text('U', style: TextStyle(color: Colors.white))),
            title: const Text('User Name'),
            subtitle: const Text('user@example.com'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          _SectionHeader('Connected Accounts'),
          _AccountTile('Instagram', Icons.camera_alt,  const Color(0xFFE1306C), true),
          _AccountTile('Facebook',  Icons.facebook,    const Color(0xFF1877F2), true),
          _AccountTile('Twitter/X', Icons.close,       Colors.black,            false),
          _AccountTile('LinkedIn',  Icons.work,        const Color(0xFF0A66C2), false),
          _AccountTile('YouTube',   Icons.play_circle, const Color(0xFFFF0000), false),

          _SectionHeader('Subscription'),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.star, color: AppTheme.primary, size: 20),
            ),
            title: const Text('Current Plan: Free'),
            subtitle: const Text('Upgrade to unlock all features'),
            trailing: ElevatedButton(
              onPressed: () => context.go('/plans'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
              child: const Text('Upgrade', style: TextStyle(fontSize: 12)),
            ),
          ),

          _SectionHeader('Referral'),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.card_giftcard, color: Colors.green, size: 20),
            ),
            title: const Text('Refer & Earn'),
            subtitle: const Text('Get 1 month free for each referral'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          _SectionHeader('Preferences'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode'),
            value: themeMode == ThemeMode.dark,
            onChanged: (v) => ref.read(themeModeProvider.notifier).state =
              v ? ThemeMode.dark : ThemeMode.light,
            activeThumbColor: AppTheme.primary,
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Language'),
            trailing: const Text('English', style: TextStyle(color: Colors.grey)),
            onTap: () {},
          ),

          _SectionHeader('Support'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help Center'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
                // Router redirect handles navigation to /login automatically
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
              child: const Text('Sign Out'),
            ),
          ),
          const SizedBox(height: 24),
          const Center(child: Text('AutoPost AI v1.0.0', style: TextStyle(color: Colors.grey, fontSize: 12))),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
        color: Colors.grey, letterSpacing: 0.5)),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;
  final bool connected;

  const _AccountTile(this.name, this.icon, this.color, this.connected);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(name),
      trailing: connected
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            const Text('Connected', style: TextStyle(fontSize: 12, color: Colors.green)),
          ])
        : TextButton(
            onPressed: () {},
            child: const Text('Connect', style: TextStyle(fontSize: 12)),
          ),
    );
  }
}
