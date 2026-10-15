import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/core/env.dart';
import 'src/core/router.dart';
import 'src/core/theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'src/state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferences = await SharedPreferences.getInstance();

  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseKey,
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const YcpStoreApp(),
    ),
  );
}

class YcpStoreApp extends ConsumerWidget {
  const YcpStoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final problem = Env.configurationProblem;
    if (problem != null) return _MissingConfiguration(problem: problem);

    final locale = ref.watch(localeControllerProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppL10n.of(context).appTitle,
      theme: AppTheme.build(locale),
      routerConfig: router,
      locale: locale,
      supportedLocales: AppL10n.supportedLocales,
      localizationsDelegates: const [
        AppL10n.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

/// Shown when the app cannot reach Supabase. Explains which variable is wrong
/// rather than letting the failure surface later as an opaque 401.
class _MissingConfiguration extends StatelessWidget {
  const _MissingConfiguration({required this.problem});

  final String problem;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(const Locale('en')),
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Supabase is not configured',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    problem,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: AppColors.warn,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Option 1 — recommended',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    './scripts/run-app.sh -d chrome\n'
                    'Reads the publishable key from .env.local, so no key is\n'
                    'written into a tracked file.',
                    style: TextStyle(fontSize: 12, height: 1.7),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Option 2 — edit the launch config',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Replace REPLACE_WITH_PUBLISHABLE_KEY in .vscode/launch.json\n'
                    'with the value from Dashboard → Settings → API.',
                    style: TextStyle(fontSize: 12, height: 1.7),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Do not use the secret key. It bypasses every RLS policy\n'
                    'and would ship inside the app bundle.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.7,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
