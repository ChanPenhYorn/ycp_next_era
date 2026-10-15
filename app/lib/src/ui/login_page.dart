import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/providers.dart';

/// Passwordless email OTP. Nothing to store, nothing to leak.
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
                const SizedBox(height: 22),
                TextField(
                  controller: _email,
                  enabled: !_codeSent,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
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
                      _error = null;
                    }),
                    child: Text(l10n.emailLabel),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = AppL10n.of(context).emailLabel);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(supabaseProvider).auth.signInWithOtp(email: email);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).codeSent(email))),
      );
    } on AuthException catch (error) {
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = AppL10n.of(context).somethingWentWrong;
      });
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(supabaseProvider).auth.verifyOTP(
            type: OtpType.email,
            email: _email.text.trim(),
            token: _token.text.trim(),
          );
      if (!mounted) return;
      setState(() => _busy = false);
      context.go('/');
    } on AuthException catch (error) {
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = AppL10n.of(context).somethingWentWrong;
      });
    }
  }
}
