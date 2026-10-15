import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ycp_store/main.dart';
import 'package:ycp_store/src/core/env.dart';
import 'package:ycp_store/src/state/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('explains the setup instead of failing when Supabase is absent',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const YcpStoreApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Tests run without --dart-define, so the app must explain which variable
    // is missing rather than showing a blank screen or a network error.
    expect(find.text('Supabase is not configured'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL is not set'), findsOneWidget);
  });

  test('defaults to Khmer because that is the primary audience', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(localeControllerProvider).languageCode,
      'km',
    );
  });

  group('configuration guard', () {
    const url = 'https://example.supabase.co';
    const key = 'sb_publishable_abcdefghijklmnopqrstuv';

    String? problem(String u, String k) =>
        Env.configurationProblemFor(url: u, key: k);

    test('accepts a real project url and publishable key', () {
      expect(problem(url, key), isNull);
    });

    test('rejects the placeholder left in the committed launch config', () {
      // This is the exact failure that produced a confusing 401 Invalid API
      // key: the variable was non-empty, so the app believed it was configured.
      final result = problem(url, 'REPLACE_WITH_PUBLISHABLE_KEY');
      expect(result, isNotNull);
      expect(result, contains('placeholder'));
    });

    test('rejects an empty key', () {
      expect(problem(url, ''), contains('not set'));
    });

    test('rejects an empty url', () {
      expect(problem('', key), contains('SUPABASE_URL'));
    });

    test('rejects a url placeholder', () {
      expect(problem('https://YOUR-REF.supabase.co', key), contains('placeholder'));
    });

    test('refuses a secret key, which would ship an RLS bypass', () {
      final result = problem(url, 'sb_secret_abcdefghijklmnopqrstuv');
      expect(result, isNotNull);
      expect(result, contains('secret key'));
    });

    test('refuses a legacy service_role jwt', () {
      expect(problem(url, 'eyJhbGciOiJIUzI1NiJ9.service_role.x'), contains('secret key'));
    });
  });
}
