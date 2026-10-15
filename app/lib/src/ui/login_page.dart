import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

import '../core/env.dart';
import '../core/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../state/providers.dart';
import 'widgets/brand_mark.dart';

/// Passwordless sign-in: Google where it is enabled, email OTP otherwise.
///
/// Note on email: Supabase's built-in mailer allows only 2 emails per hour for
/// the whole project. That is fine for testing and not fine for launch, so the
/// UI says so plainly instead of leaving people stuck.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _email = TextEditingController();
  final _token = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final capabilities = ref.watch(authCapabilitiesProvider);

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandMark(size: 52),
                ),
                const SizedBox(height: 22),
                Text(
                  l10n.loginTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.loginSubtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.ink400),
                ),
                const SizedBox(height: 24),

                // Social first: no rate limit, one tap, and it is what most
                // people will reach for.
                ...capabilities.maybeWhen(
                  data: (caps) => caps.google
                      ? [
                          FilledButton.icon(
                            onPressed: _busy ? null : _google,
                            icon: const Icon(Icons.g_mobiledata, size: 26),
                            label: Text(l10n.continueWithGoogle),
                          ),
                          const SizedBox(height: 18),
                          _Divider(label: l10n.orDivider),
                          const SizedBox(height: 18),
                        ]
                      : <Widget>[],
                  orElse: () => <Widget>[],
                ),

                TextField(
                  controller: _email,
                  enabled: !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  decoration: InputDecoration(
                    labelText: l10n.emailLabel,
                    errorText: _error,
                    prefixIcon: const Icon(Icons.mail_outline, size: 18),
                  ),
                ),

                if (_codeSent) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: _token,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.otpLabel,
                      counterText: '',
                    ),
                  ),
                  if (Env.devAuthEnabled) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.devCodeHint(Env.devOtp),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.ink400,
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : (_codeSent ? _verify : _sendCode),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_codeSent ? l10n.verify : l10n.sendCode),
                ),

                if (_codeSent)
                  TextButton(
                    onPressed: () => setState(() {
                      _codeSent = false;
                      _token.clear();
                      _error = null;
                    }),
                    child: Text(l10n.useDifferentEmail),
                  ),

                const SizedBox(height: 10),
                Text(
                  l10n.emailOnlyNote,
                  style: const TextStyle(fontSize: 11, color: AppColors.ink400),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      // Web redirects away; mobile returns through the deep link and the auth
      // stream refreshes the router.
      if (mounted) setState(() => _busy = false);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(error, AppL10n.of(context));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppL10n.of(context).somethingWentWrong;
      });
    }
  }

  Future<void> _sendCode() async {
    final l10n = AppL10n.of(context);
    // Trim first: a trailing space is a common paste artefact.
    final email = _email.text.trim();

    if (!isLikelyEmail(email)) {
      // Name the actual problem. The previous copy just repeated the field
      // label, which told the user nothing.
      setState(() => _error = l10n.invalidEmail);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      // Sandbox: nothing is emailed, so neither the mailer's 2-per-hour budget
      // nor the hosted project's confirmation template comes into it.
      if (!Env.devAuthEnabled) {
        await ref.read(authRepositoryProvider).signInWithOtp(email);
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Env.devAuthEnabled
                ? l10n.devCodeHint(Env.devOtp)
                : l10n.otpSentTo(email),
          ),
        ),
      );
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(error, l10n);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.somethingWentWrong;
      });
    }
  }

  Future<void> _verify() async {
    final l10n = AppL10n.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (Env.devAuthEnabled) {
        await ref
            .read(authRepositoryProvider)
            .devSignIn(email: _email.text.trim(), token: _token.text.trim());
      } else {
        await ref
            .read(authRepositoryProvider)
            .verifyOtp(email: _email.text.trim(), token: _token.text.trim());
      }
      if (!mounted) return;
      setState(() => _busy = false);
      context.go('/');
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _message(error, l10n);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.somethingWentWrong;
      });
    }
  }

  /// Supabase's raw messages are accurate but unfriendly, and the rate limit
  /// one is guaranteed to happen on the built-in mailer.
  String _message(AuthException error, AppL10n l10n) {
    final raw = error.message.toLowerCase();

    if (raw.contains('rate limit') || error.statusCode == '429') {
      return l10n.emailRateLimited;
    }
    if (raw.contains('not enabled') || raw.contains('provider')) {
      return l10n.providerNotEnabled;
    }
    if (raw.contains('invalid') && raw.contains('code')) {
      return l10n.codeInvalid;
    }
    if (raw.contains('invalid') && raw.contains('email')) {
      return l10n.invalidEmail;
    }
    return error.message;
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.ink400),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}
