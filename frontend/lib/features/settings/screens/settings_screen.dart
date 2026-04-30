import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_mode_provider.dart';
import '../../auth/services/auth_service.dart';
import '../../accounts/models/social_account.dart';
import '../../accounts/services/accounts_service.dart';
import '../../accounts/screens/accounts_screen.dart';
import '../../accounts/widgets/oauth_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final themeMode = ref.watch(themeModeProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [

          // ── Profile ────────────────────────────────────────
          _Section('Profile'),
          _ProfileTile(user: user),

          // ── Connected Accounts ─────────────────────────────
          _Section('Connected Accounts'),
          accountsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (_, __) => _ErrorTile(
                onRetry: () => ref.invalidate(accountsProvider)),
            data: (accounts) => _AccountsSection(
              accounts: accounts,
              ref: ref,
            ),
          ),
          // Add account button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: OutlinedButton.icon(
              onPressed: () => _showAddAccount(context, ref),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Account'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          // ── Subscription ───────────────────────────────────
          _Section('Subscription'),
          ListTile(
            leading: _IconBox(Icons.star_rounded, AppTheme.warning),
            title: const Text('Current Plan',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Free — 3 posts/day, 2 platforms'),
            trailing: ElevatedButton(
              onPressed: () => context.go('/plans'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Upgrade',
                  style: TextStyle(fontSize: 12, color: Colors.white)),
            ),
          ),

          // ── Referral ───────────────────────────────────────
          _Section('Referral'),
          ListTile(
            leading: _IconBox(Icons.card_giftcard_rounded, Colors.green),
            title: const Text('Refer & Earn',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Get 1 month free per referral'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          // ── Preferences ────────────────────────────────────
          _Section('Preferences'),
          SwitchListTile(
            secondary: _IconBox(Icons.dark_mode_outlined, Colors.indigo),
            title: const Text('Dark Mode'),
            value: themeMode == ThemeMode.dark,
            onChanged: (v) => ref.read(themeModeProvider.notifier).state =
                v ? ThemeMode.dark : ThemeMode.light,
            activeColor: AppTheme.primary,
          ),
          ListTile(
            leading: _IconBox(Icons.notifications_outlined, Colors.orange),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: _IconBox(Icons.language_rounded, Colors.teal),
            title: const Text('Language'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('English',
                  style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              const Icon(Icons.chevron_right),
            ]),
            onTap: () {},
          ),

          // ── Security ───────────────────────────────────────
          _Section('Security'),
          ListTile(
            leading: _IconBox(Icons.lock_outline_rounded, Colors.blue),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: _IconBox(Icons.security_rounded, Colors.purple),
            title: const Text('Two-Factor Authentication'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          // ── Support ────────────────────────────────────────
          _Section('Support'),
          ListTile(
            leading: _IconBox(Icons.help_outline_rounded, Colors.cyan),
            title: const Text('Help Center'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: _IconBox(Icons.privacy_tip_outlined, Colors.grey),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: _IconBox(Icons.description_outlined, Colors.grey),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // ── Sign Out ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
              },
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('AutoPost AI v1.0.0',
                style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showAddAccount(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddAccountSheet(ref: ref),
    );
  }
}

// ── Accounts Section ──────────────────────────────────────────
class _AccountsSection extends StatelessWidget {
  final List<SocialAccount> accounts;
  final WidgetRef ref;

  const _AccountsSection({required this.accounts, required this.ref});

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text('No accounts connected yet.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      );
    }

    return Column(
      children: accounts.map((a) {
        final color = Color(int.parse('FF${a.platform.color}', radix: 16));
        final isExpired = a.status == AccountStatus.expired;

        return ListTile(
          leading: Stack(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon(a.platform), color: color, size: 20),
            ),
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: isExpired ? Colors.orange : Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5),
                ),
              ),
            ),
          ]),
          title: Text(
            a.displayName.isNotEmpty ? a.displayName : a.platform.label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            isExpired ? '⚠ Token expired — reconnect' : '@${a.username}',
            style: TextStyle(
                fontSize: 11,
                color: isExpired ? Colors.orange : Colors.grey[500]),
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (v) async {
              if (v == 'disconnect') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Disconnect'),
                    content: Text(
                        'Remove ${a.platform.label} (@${a.username})?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(
                            foregroundColor: Colors.red),
                        child: const Text('Disconnect'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await ref
                      .read(accountsServiceProvider)
                      .disconnectAccount(a.id);
                  ref.invalidate(accountsProvider);
                }
              }
            },
            itemBuilder: (_) => [
              if (isExpired)
                const PopupMenuItem(
                    value: 'reconnect',
                    child: Text('Reconnect')),
              const PopupMenuItem(
                value: 'disconnect',
                child: Text('Disconnect',
                    style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      }).toList(),
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

// ── Add Account Sheet ─────────────────────────────────────────
class _AddAccountSheet extends StatelessWidget {
  final WidgetRef ref;
  const _AddAccountSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Connect Account',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Select a platform to connect via OAuth',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 20),
          ...SocialPlatform.values.map((p) {
            final color =
                Color(int.parse('FF${p.color}', radix: 16));
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon(p), color: color, size: 20),
              ),
              title: Text(p.label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Connect via OAuth',
                  style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => OAuthSheet(platform: p),
                );
              },
            );
          }),
          const SizedBox(height: 8),
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

// ── Profile Tile ──────────────────────────────────────────────
class _ProfileTile extends StatelessWidget {
  final User? user;
  const _ProfileTile({required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: AppTheme.primary,
        backgroundImage:
            user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
        child: user?.photoURL == null
            ? Text(
                (user?.displayName ?? 'U')[0].toUpperCase(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              )
            : null,
      ),
      title: Text(
        user?.displayName ?? 'User',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(user?.email ?? '',
          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────
class _Section extends StatelessWidget {
  final String title;
  const _Section(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey[500],
              letterSpacing: 0.8)),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBox(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorTile({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.error_outline, color: Colors.red),
      title: const Text('Failed to load accounts'),
      trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
    );
  }
}
