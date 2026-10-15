import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

class LocaleController extends Notifier<Locale> {
  static const _key = 'app_locale';
  static const supported = [Locale('km'), Locale('en')];

  @override
  Locale build() {
    final stored = ref.read(sharedPreferencesProvider).getString(_key);
    if (stored == null) return const Locale('km'); // Khmer-first by default
    return supported.firstWhere(
      (locale) => locale.languageCode == stored,
      orElse: () => const Locale('km'),
    );
  }

  Future<void> set(Locale locale) async {
    if (locale == state) return;
    state = locale;
    await ref.read(sharedPreferencesProvider).setString(_key, locale.languageCode);
  }

  Future<void> toggle() => set(
        state.languageCode == 'km' ? const Locale('en') : const Locale('km'),
      );
}
