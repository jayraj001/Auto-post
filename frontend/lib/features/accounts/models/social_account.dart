enum AccountStatus { connected, expired, disconnected }

enum SocialPlatform { instagram, facebook, twitter, linkedin, youtube }

extension SocialPlatformX on SocialPlatform {
  String get id => name;

  String get label {
    switch (this) {
      case SocialPlatform.instagram: return 'Instagram';
      case SocialPlatform.facebook:  return 'Facebook';
      case SocialPlatform.twitter:   return 'Twitter / X';
      case SocialPlatform.linkedin:  return 'LinkedIn';
      case SocialPlatform.youtube:   return 'YouTube';
    }
  }

  String get color {
    switch (this) {
      case SocialPlatform.instagram: return 'E1306C';
      case SocialPlatform.facebook:  return '1877F2';
      case SocialPlatform.twitter:   return '000000';
      case SocialPlatform.linkedin:  return '0A66C2';
      case SocialPlatform.youtube:   return 'FF0000';
    }
  }

  String get oauthPath {
    switch (this) {
      case SocialPlatform.instagram: return '/api/oauth/instagram';
      case SocialPlatform.facebook:  return '/api/oauth/facebook';
      case SocialPlatform.twitter:   return '/api/oauth/twitter';
      case SocialPlatform.linkedin:  return '/api/oauth/linkedin';
      case SocialPlatform.youtube:   return '/api/oauth/youtube';
    }
  }
}

class SocialAccount {
  final String id;
  final SocialPlatform platform;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final AccountStatus status;
  final DateTime connectedAt;

  const SocialAccount({
    required this.id,
    required this.platform,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    required this.status,
    required this.connectedAt,
  });

  factory SocialAccount.fromJson(Map<String, dynamic> json) {
    final platformStr = json['platform'] as String? ?? 'instagram';
    final platform = SocialPlatform.values.firstWhere(
      (p) => p.id == platformStr,
      orElse: () => SocialPlatform.instagram,
    );

    final isActive = json['is_active'] as bool? ?? false;
    final tokenExpired = json['token_expired'] as bool? ?? false;
    AccountStatus status;
    if (!isActive) {
      status = AccountStatus.disconnected;
    } else if (tokenExpired) {
      status = AccountStatus.expired;
    } else {
      status = AccountStatus.connected;
    }

    return SocialAccount(
      id: json['id']?.toString() ?? '',
      platform: platform,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      status: status,
      connectedAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
