import 'profile.dart';

abstract class ProfileRepository {
  /// The signed-in user's profile, or null when there is no session.
  Future<Profile?> profile();

  /// Telegram linking. Only the bot can unlink (`/unlink`): the app is not
  /// granted rights to clear `telegram_chat_id`.
  Future<TelegramLinkCode> createTelegramLinkCode();
}
