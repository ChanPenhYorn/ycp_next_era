import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/brand.dart';
import '../core/env.dart';
import '../core/theme.dart';
import '../data/auth_repository.dart';
import '../state/providers.dart';
import '../../l10n/generated/app_localizations.dart';
import 'widgets/brand_mark.dart';

/// The one place anyone signs in or signs up.
///
/// Three ways in, deliberately ordered:
///
///   1. Google — one tap, no email, and no rate limit.
///   2. Email + password — what people expect, and what the reset flow needs.
///   3. Emailed six-digit code — kept as the fallback it always was. It is the
///      only path that works while the project is stuck on Supabase's built-in
///      mailer (2 emails/hour for everyone), so removing it would remove the
///      way most people get in today.
///
/// `/login` and `/register` are the same screen with a different starting tab,
/// so a shared link to either works and the tab state stays honest.
enum AuthMode { signIn, register }

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, this.initialMode = AuthMode.signIn, this.next});

  final AuthMode initialMode;

  /// Where to land after a successful sign-in. Comes from `?next=` on the
  /// route, so a protected page can send people back where they were.
  final String? next;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

/// Which panel is on screen. The mode (sign in vs register) picks the fields,
/// the panel picks the step.
enum _Panel { form, code, confirm, reset }

class _AuthPageState extends ConsumerState<AuthPage> {
  late AuthMode _mode = widget.initialMode;
  _Panel _panel = _Panel.form;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _referral = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();

  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agree = false;
  bool _showReferral = false;
  bool _resetCodeSent = false;
  String? _error;

  /// When [_error] belongs to one field, it is shown under that field instead of
  /// in the banner. Null means the banner.
  _Field? _errorField;

  /// A referral code typed at signup that has not been applied yet. Kept until
  /// the account actually has a session, which is not the same moment when the
  /// project requires email confirmation.
  String? _pendingReferral;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _referral.dispose();
    _code.dispose();
    _newPassword.dispose();
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
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandMark(size: 52),
                ),
                const SizedBox(height: 20),
                _Header(mode: _mode, panel: _panel),
                const SizedBox(height: 22),

                // Google first: it is the fastest path and the only one with no
                // mail involved. Hidden when the project has it switched off,
                // rather than shown and failing.
                if (_panel == _Panel.form)
                  ...capabilities.maybeWhen(
                    data: (caps) => caps.google
                        ? [
                            _GoogleButton(
                              onPressed: _busy ? null : _google,
                              label: l10n.continueWithGoogle,
                            ),
                            const SizedBox(height: 18),
                            _OrDivider(label: l10n.orContinueWithEmail),
                            const SizedBox(height: 18),
                          ]
                        : <Widget>[],
                    orElse: () => <Widget>[],
                  ),

                if (_panel == _Panel.form) ...[
                  if (_mode == AuthMode.register) ...[
                    TextField(
                      controller: _name,
                      enabled: !_busy,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      // Without these, Chrome's autofill drops the account email
                      // into the first field it finds — the name — and the email
                      // box is left holding whatever was typed next, which is
                      // exactly how a valid signup gets rejected as a bad address.
                      autofillHints: const [AutofillHints.name],
                      onChanged: _clearError,
                      decoration: InputDecoration(
                        labelText: l10n.nameLabel,
                        prefixIcon: const Icon(Icons.person_outline, size: 18),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    onChanged: _clearError,
                    decoration: InputDecoration(
                      labelText: l10n.emailLabel,
                      // A concrete example, because the field that gets filled
                      // wrongly is this one: "PhnomPenh" is not an address, and
                      // the rejection only says so after the form is submitted.
                      hintText: l10n.emailHint,
                      // An address problem belongs under the address field, not
                      // in a banner at the bottom of the form.
                      errorText: _errorField == _Field.email ? _error : null,
                      prefixIcon: const Icon(Icons.mail_outline, size: 18),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _obscurePassword,
                    textInputAction: _mode == AuthMode.signIn
                        ? TextInputAction.done
                        : TextInputAction.next,
                    autofillHints: [
                      _mode == AuthMode.signIn
                          ? AutofillHints.password
                          : AutofillHints.newPassword,
                    ],
                    onChanged: _onPasswordChanged,
                    onSubmitted: (_) =>
                        _mode == AuthMode.signIn ? _signIn() : null,
                    decoration: InputDecoration(
                      labelText: l10n.passwordLabel,
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword ? 'Show' : 'Hide',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                      ),
                    ),
                  ),

                  if (_mode == AuthMode.register)
                    _PasswordHints(controller: _password, l10n: l10n)
                  else
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _startReset,
                        child: Text(
                          l10n.forgotPassword,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ),

                  if (_mode == AuthMode.register) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _confirm,
                      enabled: !_busy,
                      // Its own flag: one toggle used to unmask both boxes, so
                      // checking the password you typed also exposed whatever
                      // sat in the confirm field.
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onChanged: _clearError,
                      onSubmitted: (_) => _signUp(),
                      decoration: InputDecoration(
                        labelText: l10n.confirmPasswordLabel,
                        errorText: _errorField == _Field.confirm
                            ? _error
                            : null,
                        prefixIcon: const Icon(
                          Icons.lock_reset_outlined,
                          size: 18,
                        ),
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirm ? 'Show' : 'Hide',
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (!_showReferral)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _busy
                              ? null
                              : () => setState(() => _showReferral = true),
                          child: Text(
                            l10n.referralToggle,
                            style: const TextStyle(fontSize: 12.5),
                          ),
                        ),
                      )
                    else
                      TextField(
                        controller: _referral,
                        enabled: !_busy,
                        autocorrect: false,
                        textCapitalization: TextCapitalization.characters,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp('[A-Za-z0-9]'),
                          ),
                          LengthLimitingTextInputFormatter(8),
                        ],
                        onChanged: _clearError,
                        decoration: InputDecoration(
                          labelText: l10n.referralCodeLabel,
                          helperText: l10n.referralHint,
                          prefixIcon: const Icon(
                            Icons.card_giftcard_outlined,
                            size: 18,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    _Terms(
                      value: _agree,
                      label: l10n.termsAgree,
                      enabled: !_busy,
                      onChanged: (v) => setState(() {
                        _agree = v;
                        _error = null;
                        _errorField = null;
                      }),
                    ),
                  ],
                ],

                if (_panel == _Panel.code) ...[
                  _LockedEmail(email: _email.text.trim()),
                  const SizedBox(height: 14),
                  _CodeField(controller: _code, l10n: l10n),
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

                if (_panel == _Panel.confirm) ...[
                  Text(
                    l10n.confirmEmailBody(_email.text.trim()),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.ink400,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CodeField(controller: _code, l10n: l10n),
                ],

                if (_panel == _Panel.reset) ...[
                  if (!_resetCodeSent) ...[
                    Text(
                      l10n.resetSubtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.ink400,
                        height: 1.5,
                      ),
                    ),
                  ] else ...[
                    Text(
                      l10n.otpSentTo(_email.text.trim()),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.ink400,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _CodeField(controller: _code, l10n: l10n),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _newPassword,
                      enabled: !_busy,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      onChanged: _clearError,
                      decoration: InputDecoration(
                        labelText: l10n.newPasswordLabel,
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      ),
                    ),
                    _PasswordHints(controller: _newPassword, l10n: l10n),
                  ],
                ],

                if (_error != null && _errorField == null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(message: _error!),
                ],

                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _primaryAction,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_primaryLabel(l10n)),
                ),

                if (_panel == _Panel.code) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _busy ? null : _sendCode,
                    child: Text(l10n.resendCode),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _panel = _Panel.form;
                      _code.clear();
                      _error = null;
                      _errorField = null;
                    }),
                    child: Text(l10n.useDifferentEmail),
                  ),
                ],

                if (_panel == _Panel.reset) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => setState(() {
                      _panel = _Panel.form;
                      _resetCodeSent = false;
                      _code.clear();
                      _newPassword.clear();
                      _error = null;
                      _errorField = null;
                    }),
                    child: Text(l10n.usePasswordInstead),
                  ),
                ],

                // Cross-links. On the form panel they are the register/sign-in
                // switch; inside a panel they only go back.
                if (_panel == _Panel.form) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _mode == AuthMode.signIn
                            ? l10n.noAccountYet(Brand.displayName(locale))
                            : l10n.haveAccountAlready,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.ink400,
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _switchMode,
                        child: Text(
                          _mode == AuthMode.signIn
                              ? l10n.authTabRegister
                              : l10n.authTabSignIn,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                  if (_mode == AuthMode.signIn)
                    TextButton(
                      onPressed: _busy ? null : _sendCode,
                      child: Text(
                        l10n.signInWithCode,
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.emailOnlyNote,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.ink400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _google() => _run((_) async {
    await ref.read(authRepositoryProvider).signInWithGoogle();
    // Web navigates away; mobile returns through the deep link and the auth
    // stream refreshes the router. Either way there is nothing to do here.
  });

  Future<void> _signIn() => _run((l10n) async {
    final email = _email.text.trim();
    final password = _password.text;

    if (!isLikelyEmail(email)) {
      _fail(l10n.invalidEmail, field: _Field.email);
      return;
    }
    if (password.isEmpty) {
      _fail(l10n.passwordRequired, field: _Field.password);
      return;
    }

    await ref
        .read(authRepositoryProvider)
        .signInWithPassword(email: email, password: password);
    _done();
  });

  Future<void> _signUp() => _run((l10n) async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    final referral = _referral.text.trim();

    if (name.isEmpty) {
      _fail(l10n.nameRequired);
      return;
    }
    if (!isLikelyEmail(email)) {
      _fail(l10n.invalidEmail, field: _Field.email);
      return;
    }
    final problem = passwordProblem(password);
    if (problem != null) {
      _fail(_passwordProblemText(problem, l10n), field: _Field.password);
      return;
    }
    if (password != _confirm.text) {
      _fail(l10n.passwordMismatch, field: _Field.confirm);
      return;
    }
    if (referral.isNotEmpty && !isLikelyReferralCode(referral)) {
      _fail(l10n.referralInvalid);
      return;
    }
    if (!_agree) {
      _fail(l10n.termsRequired);
      return;
    }

    _pendingReferral = referral.isEmpty ? null : referral.toUpperCase();

    final res = await ref
        .read(authRepositoryProvider)
        .signUpWithPassword(
          email: email,
          password: password,
          displayName: name,
        );

    // No session: this project still requires email confirmation. The mail it
    // just sent carries the same six digits the code panel takes.
    if (res.session == null) {
      setState(() {
        _panel = _Panel.confirm;
        _code.clear();
      });
      return;
    }

    await _finish();
  });

  Future<void> _confirmSignup() => _run((l10n) async {
    if (_code.text.trim().length != 6) {
      _fail(l10n.codeRequired);
      return;
    }
    await ref
        .read(authRepositoryProvider)
        .verifySignupOtp(email: _email.text.trim(), token: _code.text.trim());
    await _finish();
  });

  Future<void> _sendCode() => _run((l10n) async {
    final email = _email.text.trim();
    if (!isLikelyEmail(email)) {
      _fail(l10n.invalidEmail, field: _Field.email);
      return;
    }

    // Sandbox: nothing is emailed, so the mailer's budget never comes into it
    // and the fixed code in the build is the one that works.
    if (!Env.devAuthEnabled) {
      await ref.read(authRepositoryProvider).signInWithOtp(email);
    }
    setState(() {
      _panel = _Panel.code;
      _code.clear();
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          Env.devAuthEnabled
              ? l10n.devCodeHint(Env.devOtp)
              : l10n.otpSentTo(email),
        ),
      ),
    );
  });

  Future<void> _verifyCode() => _run((l10n) async {
    if (_code.text.trim().length != 6) {
      _fail(l10n.codeRequired);
      return;
    }
    final repo = ref.read(authRepositoryProvider);
    final email = _email.text.trim();
    final token = _code.text.trim();

    if (Env.devAuthEnabled) {
      await repo.devSignIn(email: email, token: token);
    } else {
      await repo.verifyOtp(email: email, token: token);
    }
    _done();
  });

  Future<void> _startReset() => _run((l10n) async {
    setState(() {
      _panel = _Panel.reset;
      _resetCodeSent = false;
      _error = null;
    });
  });

  Future<void> _sendResetCode() => _run((l10n) async {
    final email = _email.text.trim();
    if (!isLikelyEmail(email)) {
      _fail(l10n.invalidEmail, field: _Field.email);
      return;
    }
    if (Env.devAuthEnabled) {
      // The sandbox does not send mail, and `dev-signin` only issues a session
      // for a code, not for a reset. Say so instead of pretending.
      _fail(l10n.providerNotEnabled);
      return;
    }
    await ref.read(authRepositoryProvider).sendPasswordReset(email);
    setState(() {
      _resetCodeSent = true;
      _code.clear();
    });
  });

  Future<void> _savePassword() => _run((l10n) async {
    if (_code.text.trim().length != 6) {
      _fail(l10n.codeRequired);
      return;
    }
    final problem = passwordProblem(_newPassword.text);
    if (problem != null) {
      _fail(_passwordProblemText(problem, l10n), field: _Field.password);
      return;
    }

    final repo = ref.read(authRepositoryProvider);
    await repo.verifyRecoveryOtp(
      email: _email.text.trim(),
      token: _code.text.trim(),
    );
    await repo.updatePassword(_newPassword.text);
    _done();
  });

  /// Applies a pending referral code, then leaves the page.
  ///
  /// The account already exists by now, so a bad code is reported and stepped
  /// over: failing the whole signup because a friend's code was mistyped would
  /// be worse than losing the attribution.
  Future<void> _finish() async {
    final code = _pendingReferral;
    if (code != null) {
      try {
        await ref.read(authRepositoryProvider).applyReferralCode(code);
        _pendingReferral = null;
      } on PostgrestException {
        _pendingReferral = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppL10n.of(context).referralFailed)),
          );
        }
      }
    }
    _done();
  }

  void _done() {
    if (!mounted) return;
    final next = widget.next;
    context.go(next == null || next.isEmpty ? '/' : next);
  }

  /// Marks the request failed without an exception, so a validation message
  /// travels the same path as a server error.
  void _fail(String message, {_Field? field}) {
    throw _AuthFormError(message, field: field);
  }

  /// One place for busy/error handling, so no action forgets either.
  Future<void> _run(Future<void> Function(AppL10n l10n) body) async {
    final l10n = AppL10n.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _errorField = null;
    });

    try {
      await body(l10n);
      if (mounted) setState(() => _busy = false);
    } on _AuthFormError catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
        _errorField = error.field;
      });
    } on AuthException catch (error) {
      if (!mounted) return;
      final (field, message) = _mapError(error, l10n);
      setState(() {
        _busy = false;
        _error = message;
        _errorField = field;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.somethingWentWrong;
      });
    }
  }

  void _clearError(String _) {
    if (_error != null) {
      setState(() {
        _error = null;
        _errorField = null;
      });
    }
  }

  void _onPasswordChanged(String _) => _clearError('');

  void _switchMode() {
    setState(() {
      _mode = _mode == AuthMode.signIn ? AuthMode.register : AuthMode.signIn;
      _error = null;
      _errorField = null;
      _code.clear();
    });
  }

  /// Supabase's messages are accurate and unfriendly. The ones that actually
  /// happen get real copy; anything else is shown as-is rather than swallowed.
  ///
  /// The field is where the message should be shown: under the box that has the
  /// problem when there is one, otherwise in the banner.
  (_Field?, String) _mapError(AuthException error, AppL10n l10n) {
    final raw = error.message.toLowerCase();

    if (raw.contains('rate limit') || error.statusCode == '429') {
      return (null, l10n.emailRateLimited);
    }
    if (raw.contains('already registered') || raw.contains('already exists')) {
      return (_Field.email, l10n.emailInUse);
    }
    if (raw.contains('invalid login credentials')) {
      return (_Field.password, l10n.wrongCredentials);
    }
    if (raw.contains('email not confirmed')) {
      return (_Field.email, l10n.emailNotConfirmed);
    }
    if (raw.contains('password')) {
      return (_Field.password, l10n.passwordTooWeak);
    }
    if (raw.contains('expired')) {
      return (null, l10n.codeExpired);
    }
    if (raw.contains('not enabled') || raw.contains('provider')) {
      return (null, l10n.providerNotEnabled);
    }
    if (raw.contains('invalid') &&
        (raw.contains('token') || raw.contains('code'))) {
      return (null, l10n.codeInvalid);
    }
    if (raw.contains('invalid') && raw.contains('email')) {
      return (_Field.email, l10n.invalidEmail);
    }
    return (null, error.message);
  }

  String _passwordProblemText(PasswordProblem problem, AppL10n l10n) {
    switch (problem) {
      case PasswordProblem.tooShort:
        return l10n.passwordRuleTooShort('$passwordMinLength');
      case PasswordProblem.needsLower:
        return l10n.passwordRuleNeedsLower;
      case PasswordProblem.needsUpper:
        return l10n.passwordRuleNeedsUpper;
      case PasswordProblem.needsDigit:
        return l10n.passwordRuleNeedsDigit;
    }
  }

  /// The button does whatever the current panel is for.
  VoidCallback get _primaryAction {
    switch (_panel) {
      case _Panel.form:
        return _mode == AuthMode.signIn ? _signIn : _signUp;
      case _Panel.code:
        return _verifyCode;
      case _Panel.confirm:
        return _confirmSignup;
      case _Panel.reset:
        return _resetCodeSent ? _savePassword : _sendResetCode;
    }
  }

  String _primaryLabel(AppL10n l10n) {
    switch (_panel) {
      case _Panel.form:
        return _mode == AuthMode.signIn ? l10n.signIn : l10n.signUp;
      case _Panel.code:
        return l10n.verify;
      case _Panel.confirm:
        return l10n.confirmAndContinue;
      case _Panel.reset:
        return _resetCodeSent ? l10n.savePassword : l10n.sendResetCode;
    }
  }

  String get locale => Localizations.localeOf(context).languageCode;
}

/// Which field an error belongs under. Errors with no field render in the
/// banner at the bottom of the form.
enum _Field { email, password, confirm }

/// Thrown by validation inside an action, so the error lands in the same
/// place as a server error instead of in a second code path.
class _AuthFormError implements Exception {
  const _AuthFormError(this.message, {this.field});

  final String message;
  final _Field? field;
}

// -----------------------------------------------------------------------------
// Small pieces. Each one is only used here, so they stay in this file.
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.mode, required this.panel});

  final AuthMode mode;
  final _Panel panel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final (String title, String subtitle) = switch (panel) {
      _Panel.code => (l10n.codeSignInTitle, l10n.codeSignInSubtitle),
      _Panel.confirm => (l10n.confirmEmailTitle, ''),
      _Panel.reset => (l10n.resetTitle, ''),
      _Panel.form =>
        mode == AuthMode.signIn
            ? (l10n.loginTitle, l10n.loginSubtitle)
            : (l10n.registerTitle, l10n.registerSubtitle),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.3,
          ),
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.ink400,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onPressed, required this.label});

  final VoidCallback? onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    // White on a dark page, because that is what the Google mark is drawn for:
    // a blue primary button with a red-and-yellow logo inside it looks broken.
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.g_mobiledata, size: 30, color: AppColors.brand),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink950,
        disabledBackgroundColor: AppColors.ink700,
        disabledForegroundColor: AppColors.ink400,
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

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
            style: const TextStyle(fontSize: 11.5, color: AppColors.ink400),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller, required this.l10n});

  final TextEditingController controller;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: const TextStyle(letterSpacing: 6, fontSize: 18),
      decoration: InputDecoration(
        labelText: l10n.otpLabel,
        counterText: '',
        prefixIcon: const Icon(Icons.password_outlined, size: 18),
      ),
    );
  }
}

/// The email a code went to, shown as text: it must not be editable here, or
/// the code stops matching.
class _LockedEmail extends StatelessWidget {
  const _LockedEmail({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.mail_outline, size: 16, color: AppColors.ink400),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            email,
            style: const TextStyle(fontSize: 13, color: AppColors.ink200),
          ),
        ),
      ],
    );
  }
}

/// Live password feedback: the next rule to fix, plus a coarse strength bar.
/// Both are hints — Supabase validates again on the server.
class _PasswordHints extends StatelessWidget {
  const _PasswordHints({required this.controller, required this.l10n});

  final TextEditingController controller;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text;
        if (text.isEmpty) return const SizedBox.shrink();

        final problem = passwordProblem(text);
        final score = passwordScore(text);
        final (String strength, Color color) = switch (score) {
          <= 1 => (l10n.passwordStrengthWeak, AppColors.danger),
          2 => (l10n.passwordStrengthFair, AppColors.warn),
          _ => (l10n.passwordStrengthStrong, AppColors.accent),
        };

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 0; i < 3; i++) ...[
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: i < score ? color : AppColors.ink800,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    if (i < 2) const SizedBox(width: 6),
                  ],
                  const SizedBox(width: 10),
                  Text(
                    strength,
                    style: TextStyle(fontSize: 11.5, color: color),
                  ),
                ],
              ),
              if (problem != null) ...[
                const SizedBox(height: 8),
                Text(
                  switch (problem) {
                    PasswordProblem.tooShort => l10n.passwordRuleTooShort(
                      '$passwordMinLength',
                    ),
                    PasswordProblem.needsLower => l10n.passwordRuleNeedsLower,
                    PasswordProblem.needsUpper => l10n.passwordRuleNeedsUpper,
                    PasswordProblem.needsDigit => l10n.passwordRuleNeedsDigit,
                  },
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.ink400,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Terms extends StatelessWidget {
  const _Terms({
    required this.value,
    required this.label,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final String label;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onChanged(!value) : null,
      borderRadius: BorderRadius.circular(AppRadius.tile),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: enabled ? (v) => onChanged(v ?? false) : null,
              side: const BorderSide(color: AppColors.ink400),
              activeColor: AppColors.brand,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.ink400,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.tile),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.ink200,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
