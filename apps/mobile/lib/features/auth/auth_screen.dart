import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../ui/ats_design.dart';

/// An authentication-first, mobile-native flow. No marketing splash screen.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.initiallyRegister = false});

  final bool initiallyRegister;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _confirmation = TextEditingController();

  late bool _create;
  bool _passwordVisible = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _create = widget.initiallyRegister;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _switchTab(bool create) {
    if (_busy || _create == create) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _create = create;
      _error = null;
      _passwordVisible = false;
    });
  }

  void _completeLogin() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
    // If this is the app's first route, SessionGate replaces it automatically.
  }

  Future<void> _submit() async {
    if (!SupabaseConfig.configured || _busy) return;
    if (!_formKey.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final auth = SupabaseConfig.client.auth;
      final email = _email.text.trim();
      if (_create) {
        final response = await auth.signUp(
          email: email,
          password: _password.text,
          data: {'display_name': _name.text.trim()},
        );
        if (!mounted) return;
        if (response.session != null) {
          _completeLogin();
        } else {
          await Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => VerificationCodeScreen(email: email),
            ),
          );
          if (mounted && SupabaseConfig.client.auth.currentSession != null) {
            _completeLogin();
          }
        }
      } else {
        await auth.signInWithPassword(
          email: email,
          password: _password.text,
        );
        if (!mounted) return;
        _completeLogin();
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'We couldn’t connect securely. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 380;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(narrow ? 18 : 24, 22, narrow ? 18 : 24, 26),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandMark(),
                    const SizedBox(height: 30),
                    const _EditorialHeader(),
                    const SizedBox(height: 28),
                    _AuthTabs(
                      create: _create,
                      onChange: _switchTab,
                    ),
                    const SizedBox(height: 23),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.topCenter,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _create ? 'Create your account' : 'Welcome back',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.7,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _create
                                ? 'Your next opportunity starts with a clearer CV.'
                                : 'Sign in to pick up right where you left off.',
                            style: TextStyle(
                              height: 1.5,
                              color: colors.onSurface.withValues(alpha: .64),
                            ),
                          ),
                          const SizedBox(height: 23),
                          if (_create) ...[
                            _FieldLabel('Full name'),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _name,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              textInputAction: TextInputAction.next,
                              maxLength: 80,
                              decoration: const InputDecoration(
                                hintText: 'How should we call you?',
                                counterText: '',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) =>
                                  (value?.trim().length ?? 0) < 2
                                      ? 'Enter at least two characters'
                                      : null,
                            ),
                            const SizedBox(height: 17),
                          ],
                          _FieldLabel('Email address'),
                          const SizedBox(height: 7),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            autocorrect: false,
                            decoration: const InputDecoration(
                              hintText: 'you@example.com',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                                  ? null
                                  : 'Enter a valid email address';
                            },
                          ),
                          const SizedBox(height: 17),
                          _FieldLabel('Password'),
                          const SizedBox(height: 7),
                          TextFormField(
                            controller: _password,
                            obscureText: !_passwordVisible,
                            autofillHints: [
                              _create
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            textInputAction: _create
                                ? TextInputAction.next
                                : TextInputAction.done,
                            onFieldSubmitted: (_) {
                              if (!_create) _submit();
                            },
                            decoration: InputDecoration(
                              hintText: _create
                                  ? 'At least 8 characters'
                                  : 'Enter your password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: _passwordVisible
                                    ? 'Hide password'
                                    : 'Show password',
                                icon: Icon(_passwordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                                onPressed: () =>
                                    setState(() => _passwordVisible = !_passwordVisible),
                              ),
                            ),
                            validator: (value) =>
                                (value?.length ?? 0) < 8
                                    ? 'Use at least 8 characters'
                                    : null,
                          ),
                          if (_create) ...[
                            const SizedBox(height: 17),
                            _FieldLabel('Confirm password'),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _confirmation,
                              obscureText: !_passwordVisible,
                              autofillHints: const [AutofillHints.newPassword],
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                hintText: 'Repeat your password',
                                prefixIcon: Icon(Icons.verified_user_outlined),
                              ),
                              validator: (value) =>
                                  value != _password.text
                                      ? 'Passwords do not match'
                                      : null,
                            ),
                          ] else ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => Navigator.of(context).push<void>(
                                        MaterialPageRoute<void>(
                                          builder: (_) => const ForgotPasswordPage(),
                                        ),
                                      ),
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            _InlineNotice(message: _error!, isError: true),
                          ],
                          if (!SupabaseConfig.configured) ...[
                            const SizedBox(height: 12),
                            const _InlineNotice(
                              message: 'Authentication is not configured for this build. '
                                  'Add the public Supabase publishable key.',
                              isError: true,
                            ),
                          ],
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _busy || !SupabaseConfig.configured
                                  ? null
                                  : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(_create ? 'Create account' : 'Sign in'),
                                        const SizedBox(width: 10),
                                        const Icon(Icons.arrow_forward_rounded, size: 19),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined, size: 17,
                            color: AtsPalette.success),
                        SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            'Private documents. Clear insights.',
                            style: TextStyle(fontSize: 12, color: AtsPalette.muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'CV ATS  ·  Built for better applications',
                        style: TextStyle(
                          color: colors.onSurface.withValues(alpha: .45),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      height: 42,
      width: 42,
      decoration: BoxDecoration(
        color: AtsPalette.midnight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.article_outlined, color: Colors.white, size: 22),
    ),
    const SizedBox(width: 11),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('cv/ats',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              )),
      const Text('CAREER STUDIO',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: AtsPalette.muted,
            letterSpacing: 1.7,
          )),
    ]),
    const Spacer(),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: AtsPalette.stroke),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Text('MOBILE  ·  01',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: .9,
            fontWeight: FontWeight.w800,
          )),
    ),
  ]);
}

class _EditorialHeader extends StatelessWidget {
  const _EditorialHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(23, 22, 21, 20),
    decoration: BoxDecoration(
      color: AtsPalette.midnight,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Stack(children: [
      Positioned(
        right: -30, top: -45,
        child: Container(
          height: 170, width: 170,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF42567B), width: 1),
            shape: BoxShape.circle,
          ),
        ),
      ),
      Positioned(
        right: -58, top: -20,
        child: Container(
          height: 155, width: 155,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF263A5E), width: 1),
            shape: BoxShape.circle,
          ),
        ),
      ),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('THE NEXT CHAPTER STARTS HERE',
            style: TextStyle(color: Color(0xFF88DDE3), fontSize: 10,
                letterSpacing: 1.6, fontWeight: FontWeight.w800)),
        const SizedBox(height: 15),
        Text(
          'Make your experience\nstand out.',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                height: 1.13,
                fontWeight: FontWeight.w900,
                letterSpacing: -.9,
              ),
        ),
        const SizedBox(height: 13),
        const Text(
          'Understand your CV. Match with intention.\nApply with confidence.',
          style: TextStyle(
            color: Color(0xFFC1CCDD),
            fontSize: 13,
            height: 1.55,
          ),
        ),
      ]),
    ]),
  );
}

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({required this.create, required this.onChange});
  final bool create;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) => Container(
    height: 54,
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AtsPalette.stroke),
    ),
    child: Row(children: [
      _tab(context, 'Sign in', !create, () => onChange(false)),
      _tab(context, 'Create account', create, () => onChange(true)),
    ]),
  );

  Widget _tab(BuildContext context, String label, bool active, VoidCallback tap) =>
      Expanded(
        child: Semantics(
          selected: active,
          button: true,
          child: InkWell(
            onTap: tap,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 210),
              curve: Curves.easeOut,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? AtsPalette.midnight : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(label, style: TextStyle(
                color: active ? Colors.white
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: .65),
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                fontSize: 13,
              )),
            ),
          ),
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13));
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.message, this.isError = false});
  final String message;
  final bool isError;
  @override
  Widget build(BuildContext context) {
    final tone = isError ? AtsPalette.danger : AtsPalette.success;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .075),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: tone.withValues(alpha: .20)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.info_outline : Icons.mark_email_read_outlined,
            size: 20, color: tone),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12, height: 1.5))),
      ]),
    );
  }
}

/// Password sign-up verification. Users can paste the entire email code.
class VerificationCodeScreen extends StatefulWidget {
  const VerificationCodeScreen({super.key, required this.email});
  final String email;
  @override
  State<VerificationCodeScreen> createState() => _VerificationCodeScreenState();
}

class _VerificationCodeScreenState extends State<VerificationCodeScreen> {
  final _code = TextEditingController();
  Timer? _countdown;
  int _remaining = 60;
  bool _busy = false;
  String? _error;
  String? _success;
  // Supabase email OTP can be configured between 6 and 10 digits.
  bool get _codeIsValid => RegExp(r'^\d{6,10}
  @override
  void initState() {
    super.initState();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining > 0) setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || !_codeIsValid) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final response = await SupabaseConfig.client.auth.verifyOTP(
        email: widget.email,
        token: _code.text,
        type: OtpType.email,
      );
      if (!mounted) return;
      if (response.session != null) {
        Navigator.of(context).pop();
      } else {
        setState(() => _success =
            'Email verified. Return to Sign in to access your workspace.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error =
          'The code is invalid or has expired. Please check your email and try again.');
    } catch (_) {
      if (mounted) setState(() => _error =
          'Verification couldn’t be completed. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_remaining > 0 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await SupabaseConfig.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (mounted) setState(() {
        _remaining = 60;
        _success = 'A fresh code has been requested. Check your inbox.';
      });
    } on AuthException catch (e) {
      if (mounted) setState(() => _error =
          'We couldn’t resend the code yet. Wait a moment and try again.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Please check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    color: AtsPalette.ocean.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      color: AtsPalette.ocean, size: 31),
                ),
              ),
              const SizedBox(height: 24),
              const AtsEyebrow('ONE QUICK STEP'),
              const SizedBox(height: 9),
              Text('Check your inbox.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900, letterSpacing: -.7)),
              const SizedBox(height: 12),
              Text('We sent a verification code to',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: .64))),
              const SizedBox(height: 5),
              Text(widget.email,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 30),
              const _FieldLabel('Verification code'),
              const SizedBox(height: 9),
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.done,
                maxLength: 10,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
                decoration: const InputDecoration(
                  hintText: 'Enter the email code',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 12),
              const Text('Paste the full code from your email (6–10 digits).',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AtsPalette.muted)),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _InlineNotice(message: _error!, isError: true),
              ],
              if (_success != null) ...[
                const SizedBox(height: 14),
                _InlineNotice(message: _success!),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy || !_codeIsValid ? null : _verify,
                child: Text(_busy ? 'Verifying...' : 'Verify and continue'),
              ),
              const SizedBox(height: 12),
              Center(child: TextButton(
                onPressed: _busy || _remaining > 0 ? null : _resend,
                child: Text(_remaining > 0
                    ? 'Resend code in ${_remaining}s'
                    : 'Send a new code'),
              )),
              const SizedBox(height: 12),
              const Text(
                'If the message doesn’t arrive, check Spam or Junk. '
                'Email delivery settings are managed by Supabase.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12,
                    color: AtsPalette.muted, height: 1.5),
              ),
            ]),
          ),
        )),
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _email.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to request recovery right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AtsPage(
    title: 'Account recovery',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 28),
      const AtsEyebrow('GET BACK ON TRACK'),
      const SizedBox(height: 10),
      Text('Forgot your password?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      const Text('Enter your email address. We’ll send you a secure recovery email.',
          style: TextStyle(color: AtsPalette.muted, height: 1.5)),
      const SizedBox(height: 26),
      _FieldLabel('Email address'),
      const SizedBox(height: 9),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(
          hintText: 'you@example.com',
          prefixIcon: Icon(Icons.alternate_email_rounded),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 13),
        _InlineNotice(message: _error!, isError: true),
      ],
      if (_sent) ...[
        const SizedBox(height: 13),
        const _InlineNotice(message:
            'If this address is registered, we’ve requested a recovery email.'),
      ],
      const SizedBox(height: 19),
      SizedBox(width: double.infinity,
        child: FilledButton(
          onPressed: _busy || _sent || !SupabaseConfig.configured
              ? null : _send,
          child: Text(_busy ? 'Sending...' : 'Send recovery email'),
        ),
      ),
      const SizedBox(height: 18),
      const Text('Completing password recovery through an Android deep link '
          'requires additional app-link configuration.',
          style: TextStyle(color: AtsPalette.muted, fontSize: 12)),
    ]),
  );
}
).hasMatch(_code.text);

  @override
  void initState() {
    super.initState();
    _countdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining > 0) setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _countdown?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || _code.text.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      final response = await SupabaseConfig.client.auth.verifyOTP(
        email: widget.email,
        token: _code.text,
        type: OtpType.email,
      );
      if (!mounted) return;
      if (response.session != null) {
        Navigator.of(context).pop();
      } else {
        setState(() => _success =
            'Email verified. Return to Sign in to access your workspace.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error =
          'The code is invalid or has expired. Please check your email and try again.');
    } catch (_) {
      if (mounted) setState(() => _error =
          'Verification couldn’t be completed. Check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_remaining > 0 || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await SupabaseConfig.client.auth.resend(
        type: OtpType.signup,
        email: widget.email,
      );
      if (mounted) setState(() {
        _remaining = 60;
        _success = 'A fresh code has been requested. Check your inbox.';
      });
    } on AuthException catch (e) {
      if (mounted) setState(() => _error =
          'We couldn’t resend the code yet. Wait a moment and try again.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Please check your connection.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: SafeArea(
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.all(19),
                  decoration: BoxDecoration(
                    color: AtsPalette.ocean.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      color: AtsPalette.ocean, size: 31),
                ),
              ),
              const SizedBox(height: 24),
              const AtsEyebrow('ONE QUICK STEP'),
              const SizedBox(height: 9),
              Text('Check your inbox.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900, letterSpacing: -.7)),
              const SizedBox(height: 12),
              Text('We sent a verification code to',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface
                      .withValues(alpha: .64))),
              const SizedBox(height: 5),
              Text(widget.email,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 30),
              const _FieldLabel('Verification code'),
              const SizedBox(height: 9),
              TextField(
                controller: _code,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.done,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 14,
                ),
                decoration: const InputDecoration(
                  hintText: '000000',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _verify(),
              ),
              const SizedBox(height: 12),
              const Text('You can paste all six digits directly from the email.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AtsPalette.muted)),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _InlineNotice(message: _error!, isError: true),
              ],
              if (_success != null) ...[
                const SizedBox(height: 14),
                _InlineNotice(message: _success!),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy || _code.text.length != 6 ? null : _verify,
                child: Text(_busy ? 'Verifying...' : 'Verify and continue'),
              ),
              const SizedBox(height: 12),
              Center(child: TextButton(
                onPressed: _busy || _remaining > 0 ? null : _resend,
                child: Text(_remaining > 0
                    ? 'Resend code in ${_remaining}s'
                    : 'Send a new code'),
              )),
              const SizedBox(height: 12),
              const Text(
                'If the message doesn’t arrive, check Spam or Junk. '
                'Email delivery settings are managed by Supabase.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12,
                    color: AtsPalette.muted, height: 1.5),
              ),
            ]),
          ),
        )),
      ),
    );
  }
}

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});
  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  bool _busy = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _email.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SupabaseConfig.client.auth.resetPasswordForEmail(_email.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to request recovery right now.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AtsPage(
    title: 'Account recovery',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 28),
      const AtsEyebrow('GET BACK ON TRACK'),
      const SizedBox(height: 10),
      Text('Forgot your password?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900)),
      const SizedBox(height: 10),
      const Text('Enter your email address. We’ll send you a secure recovery email.',
          style: TextStyle(color: AtsPalette.muted, height: 1.5)),
      const SizedBox(height: 26),
      _FieldLabel('Email address'),
      const SizedBox(height: 9),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(
          hintText: 'you@example.com',
          prefixIcon: Icon(Icons.alternate_email_rounded),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 13),
        _InlineNotice(message: _error!, isError: true),
      ],
      if (_sent) ...[
        const SizedBox(height: 13),
        const _InlineNotice(message:
            'If this address is registered, we’ve requested a recovery email.'),
      ],
      const SizedBox(height: 19),
      SizedBox(width: double.infinity,
        child: FilledButton(
          onPressed: _busy || _sent || !SupabaseConfig.configured
              ? null : _send,
          child: Text(_busy ? 'Sending...' : 'Send recovery email'),
        ),
      ),
      const SizedBox(height: 18),
      const Text('Completing password recovery through an Android deep link '
          'requires additional app-link configuration.',
          style: TextStyle(color: AtsPalette.muted, fontSize: 12)),
    ]),
  );
}
