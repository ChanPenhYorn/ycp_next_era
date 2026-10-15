import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ycp_store/l10n/generated/app_localizations.dart';
import 'package:ycp_store/src/data/auth_repository.dart';
import 'package:ycp_store/src/state/providers.dart';
import 'package:ycp_store/src/ui/auth_page.dart';

/// The auth screen reads its providers from the network in production. Every
/// test here overrides them instead, so nothing here needs a project or a
/// running stack.
Widget _wrap({
  required Widget child,
  AuthCapabilities capabilities = AuthCapabilities.fallback,
}) {
  return ProviderScope(
    overrides: [
      authCapabilitiesProvider.overrideWith((ref) async => capabilities),
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
}
