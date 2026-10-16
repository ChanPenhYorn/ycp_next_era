// Profile entities as the app uses them. Pure Dart: no JSON, no SDK types.

class Profile {
  const Profile({
    required this.id,
    required this.walletBalance,
    required this.coins,
    required this.displayName,
    this.role = 'customer',
    this.telegramChatId,
    this.telegramUsername,
  });

  final String id;
  final double walletBalance;
  final int coins;
  final String? displayName;

  /// `profiles.role`. Read through the self-select policy, which is also what
  /// gates the staff screens: the database re-checks it on every RPC, so this
  /// only decides what the app bothers to draw.
  final String role;

  final int? telegramChatId;
  final String? telegramUsername;

  bool get telegramLinked => telegramChatId != null;
  bool get isStaff => role == 'staff' || role == 'admin';
  bool get isAdmin => role == 'admin';
}

/// Returned by create_telegram_link_code.
class TelegramLinkCode {
  const TelegramLinkCode({
    required this.code,
    required this.expiresInMinutes,
    this.botUsername,
    this.deepLink,
  });

  final String code;
  final int expiresInMinutes;
  final String? botUsername;
  final String? deepLink;
}
