import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../models/social_account.dart';
import '../services/accounts_service.dart';
import '../widgets/oauth_sheet.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Connected Accounts',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(accountsProvider),
          ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(onRetry: () => ref.invalidate(accountsProvider)),
        data: (accounts) => _AccountsList(accounts: accounts),
      ),
    );
  }
}

// ── Accounts List ─────────────────────────────────────────────
class _AccountsList extends ConsumerWidget {
  final List<SocialAccount> accounts;
  const _AccountsList({required this.accounts});

  static const _allPlatforms = SocialPlatform.values;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Platforms not yet connected
    final connectedPlatforms = accounts.map((a) => a.platform).toSet();
    final availablePlatforms = _allPlatforms
        .where((p) => !connectedPlatforms.contains(p))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Connected accounts ─────────────────────────────
        if (accounts.isNotEmpty) ...[
          _SectionLabel('Connected (${accounts.length})'),
          const SizedBox(height: 10),
          ...accounts.map((a) => _ConnectedTile(
                account: a,
                onDisconnect: () => _disconnect(context, ref, a),
                onReconnect: () => _reconnect(context, ref, a.platform),
              )),
          const SizedBox(height: 24),
        ],

        // ── Available platforms ────────────────────────────
        if (availablePlatforms.isNotEmpty) ...[
          _SectionLabel('Add Account'),
          const SizedBox(height: 10),
          ...availablePlatforms.map((p) => _AvailableTile(
                platform: p,
                onConnect: () => _connect(context, ref, p),
              )),
        ],

        if (accounts.isEmpty && availablePlatforms.isEmpty)
          const _EmptyState(),
      ],
    );
  }

  Future<void> _connect(
      BuildContext context, WidgetRef ref, SocialPlatform platform) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => OAuthSheet(platform: platform),
    );
    if (confirmed == true) {
      ref.invalidate(accountsProvider);
    }
  }

  Future<void> _reconnect(
      BuildContext context, WidgetRef ref, SocialPlatform platform) async {
    await _connect(context, ref, platform);
  }

  Future<void> _disconnect(
      BuildContext context, WidgetRef ref, SocialAccount account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disconnect Account'),
        content: Text(
            'Remove ${account.platform.label} (@${account.username})?\n\nScheduled posts for this account will be cancelled.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      final success = await ref
          .read(accountsServiceProvider)
          .disconnectAccount(account.id);
      if (success) {
        ref.invalidate(accountsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${account.platform.label} disconnected'),
            backgroundColor: Colors.orange,
          ));
        }
      }
    }
  }
}

// ── Connected Account Tile ────────────────────────────────────
class _ConnectedTile extends StatelessWidget {
  final SocialAccount account;
  final VoidCallback onDisconnect;
  final VoidCallback onReconnect;

  const _ConnectedTile({
    required this.account,
    required this.onDisconnect,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(account.platform.color);
    final isExpired = account.status == AccountStatus.expired;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isExpired
              ? Colors.orange.withValues(alpha: 0.4)
              : color.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: _PlatformAvatar(
          platform: account.platform,
          avatarUrl: account.avatarUrl,
          color: color,
        ),
        title: Text(
          account.displayName.isNotEmpty
              ? account.displayName
              : account.platform.label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('@${account.username}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            _StatusBadge(status: account.status),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (v) {
            if (v == 'disconnect') onDisconnect();
            if (v == 'reconnect') onReconnect();
          },
          itemBuilder: (_) => [
            if (isExpired)
              const PopupMenuItem(
                value: 'reconnect',
                child: Row(children: [
                  Icon(Icons.refresh, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Reconnect'),
                ]),
              ),
            const PopupMenuItem(
              value: 'disconnect',
              child: Row(children: [
                Icon(Icons.link_off, size: 16, color: Colors.red),
                SizedBox(width: 8),
                Text('Disconnect', style: TextStyle(color: Colors.red)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Available Platform Tile ───────────────────────────────────
class _AvailableTile extends StatelessWidget {
  final SocialPlatform platform;
  final VoidCallback onConnect;

  const _AvailableTile({required this.platform, required this.onConnect});

  @override
  Widget build(BuildContext context) {
    final color = _hexColor(platform.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_platformIcon(platform), color: color, size: 22),
        ),
        title: Text(platform.label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('Tap to connect via OAuth',
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        trailing: OutlinedButton(
          onPressed: onConnect,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withValues(alpha: 0.5)),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Connect',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final AccountStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case AccountStatus.connected:
        color = Colors.green;
        label = 'Connected';
        icon = Icons.check_circle_outline;
        break;
      case AccountStatus.expired:
        color = Colors.orange;
        label = 'Token Expired — Reconnect';
        icon = Icons.warning_amber_outlined;
        break;
      case AccountStatus.disconnected:
        color = Colors.grey;
        label = 'Disconnected';
        icon = Icons.link_off;
        break;
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ── Platform Avatar ───────────────────────────────────────────
class _PlatformAvatar extends StatelessWidget {
  final SocialPlatform platform;
  final String? avatarUrl;
  final Color color;

  const _PlatformAvatar({
    required this.platform,
    required this.avatarUrl,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: color.withValues(alpha: 0.15),
        backgroundImage:
            avatarUrl != null ? NetworkImage(avatarUrl!) : null,
        child: avatarUrl == null
            ? Icon(_platformIcon(platform), color: color, size: 20)
            : null,
      ),
      Positioned(
        bottom: 0, right: 0,
        child: Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
          ),
          child: Icon(_platformIcon(platform), size: 9, color: Colors.white),
        ),
      ),
    ]);
  }
}

// ── Section Label ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 0.8));
  }
}

// ── Empty State ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(children: [
        Icon(Icons.link_off, size: 56, color: Colors.grey[400]),
        const SizedBox(height: 16),
        const Text('No accounts connected',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Connect your social media accounts\nto start scheduling posts',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ]),
    );
  }
}

// ── Error State ───────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
        const SizedBox(height: 12),
        const Text('Could not load accounts'),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────
// Re-export from oauth_sheet.dart for use in this file
Color _hexColor(String hex) => Color(int.parse('FF$hex', radix: 16));

IconData _platformIcon(SocialPlatform p) => platformIcon(p);
