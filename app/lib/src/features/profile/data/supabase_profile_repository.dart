import 'package:supabase_flutter/supabase_flutter.dart';

import '../../orders/data/order_mappers.dart';
import '../domain/profile.dart';
import '../domain/profile_repository.dart';

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Profile?> profile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from('profiles')
        .select(
          'id, wallet_balance, coins, display_name, role, telegram_chat_id, telegram_username',
        )
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;

    return Profile(
      id: row['id'] as String,
      walletBalance: (row['wallet_balance'] as num?)?.toDouble() ?? 0,
      coins: (row['coins'] as num?)?.toInt() ?? 0,
      displayName: row['display_name'] as String?,
      role: row['role'] as String? ?? 'customer',
      telegramChatId: (row['telegram_chat_id'] as num?)?.toInt(),
      telegramUsername: row['telegram_username'] as String?,
    );
  }

  /// Only the webhook can set telegram_chat_id: profiles grants the app update
  /// rights on display_name, phone and locale and nothing else.
  @override
  Future<TelegramLinkCode> createTelegramLinkCode() async {
    try {
      final result = await _client.rpc('create_telegram_link_code');
      final json = (result as Map).cast<String, dynamic>();
      return TelegramLinkCode(
        code: json['code'] as String? ?? '',
        expiresInMinutes: (json['expires_in_minutes'] as num?)?.toInt() ?? 15,
        botUsername: json['bot_username'] as String?,
        deepLink: json['deep_link'] as String?,
      );
    } on PostgrestException catch (error) {
      throw orderExceptionFrom(error);
    }
  }
}
