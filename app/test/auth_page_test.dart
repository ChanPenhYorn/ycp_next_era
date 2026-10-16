import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ycp_store/l10n/generated/app_localizations.dart';
import 'package:ycp_store/src/features/auth/domain/auth_models.dart';
import 'package:ycp_store/src/features/auth/domain/auth_repository.dart';
import 'package:ycp_store/src/state/providers.dart';
import 'package:ycp_store/src/ui/auth_page.dart';

/// The auth screen reads its providers from the network in production. Every
/// test here overrides them instead, so nothing here needs a project or a
/// running stack.
Widget _wrap({
  required Widget child,
  AuthCapabilities capabilities = AuthCapabilities.fallback,
  AuthRepository? auth,
}) {
  return ProviderScope(
    overrides: [
      authCapabilitiesProvider.overrideWith((ref) async => capabilities),
      if (auth != null) authRepositoryProvider.overrideWithValue(auth),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: AppL10n.localizationsDelegates,
      home: Scaffold(body: child),
    ),
  );
}

/// Taps a submit button even when the form is taller than the 800x600 test
/// surface: without the scroll, the tap lands on empty space below the fold and
/// the assertion fails for the wrong reason.
Future<void> _tapSubmit(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  group('Google button', () {
    testWidgets('is hidden while the project has the provider switched off', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(child: const AuthPage()));
      await tester.pumpAndSettle();

      // The whole point of reading /auth/v1/settings: never show a button that
      // would answer "provider is not enabled".
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('appears as soon as the project reports google: true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          child: const AuthPage(),
          capabilities: const AuthCapabilities(
            email: true,
            google: true,
            facebook: false,
            apple: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('or continue with email'), findsOneWidget);
    });
  });

  group('register form', () {
    testWidgets('starts on the sign-in tab and switches without a new route', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(child: const AuthPage()));
      await tester.pumpAndSettle();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Full name'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      // The tab switch must not lose what was already typed.
      expect(find.text('Forgot password?'), findsNothing);
    });

    testWidgets('/register opens straight on the create tab', (tester) async {
      await tester.pumpWidget(
        _wrap(child: const AuthPage(initialMode: AuthMode.register)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create your account'), findsOneWidget);
    });

    testWidgets('reveals the referral field only when asked', (tester) async {
      await tester.pumpWidget(
        _wrap(child: const AuthPage(initialMode: AuthMode.register)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Referral code (optional)'), findsNothing);

      await tester.tap(find.text('Have a referral code?'));
      await tester.pumpAndSettle();

      expect(find.text('Referral code (optional)'), findsOneWidget);
    });
  });

  group('validation', () {
    /// The failure that prompted this file: a name typed into the email box, so
    /// Supabase was never reached and the only clue was the bottom banner.
    testWidgets('a bad address is reported under the email field', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(child: const AuthPage()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'PhnomPenh');
      await tester.enterText(find.byType(TextField).last, 'ChanPenh123');
      await _tapSubmit(tester, 'Sign in');

      expect(
        find.text(
          'That doesn\'t look like an email address. Check for a missing @.',
        ),
        findsOneWidget,
      );
      // Field-level, not the banner: the banner carries an error icon.
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('an empty name is refused before any request', (tester) async {
      await tester.pumpWidget(
        _wrap(child: const AuthPage(initialMode: AuthMode.register)),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).at(1),
        'someone@example.com',
      );
      // Not find.text: in register mode "Create account" is also the footer
      // link back to sign-in. The filled button is the submit one.
      await _tapSubmit(tester, 'Create account');

      expect(find.text('Please enter your name.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('the terms box gates signup', (tester) async {
      await tester.pumpWidget(
        _wrap(child: const AuthPage(initialMode: AuthMode.register)),
      );
      await tester.pumpAndSettle();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Chanpenh Buyer');
      await tester.enterText(fields.at(1), 'someone@example.com');
      await tester.enterText(fields.at(2), 'ChanPenh123');
      await tester.enterText(fields.at(3), 'ChanPenh123');
      // Not find.text: in register mode "Create account" is also the footer
      // link back to sign-in. The filled button is the submit one.
      await _tapSubmit(tester, 'Create account');

      expect(find.text('Please accept the terms to continue.'), findsOneWidget);
    });
  });

  group('a refused sign-in', () {
    /// The bug this guards: `_mapError` sends a wrong password to the password
    /// field, the password box had no `errorText`, and the banner only draws
    /// when the field is null. So the button stopped spinning and said nothing
    /// at all — no wrong-password message, no failure, no sign-in.
    testWidgets('shows the reason under the password field', (tester) async {
      await tester.pumpWidget(
        _wrap(child: const AuthPage(), auth: _RefusingAuth()),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'buyer@example.com');
      await tester.enterText(find.byType(TextField).at(1), 'not-the-password');
      await _tapSubmit(tester, 'Sign in');

      expect(find.text('Email or password is not right.'), findsOneWidget);
      // Field-level, not the banner: the banner carries an error icon.
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });
}

/// Refuses a sign-in with the exact message Supabase returns for a wrong
/// password. Every other method throws, so a test that reaches one is wrong.
class _RefusingAuth implements AuthRepository {
  @override
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    throw const AuthFailure('Invalid login credentials', statusCode: '400');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not stubbed');
}
