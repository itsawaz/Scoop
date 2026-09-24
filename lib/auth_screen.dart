import 'package:flutter/cupertino.dart';
import 'widgets.dart';
import 'onboarding.dart';
import 'tabs.dart';
import 'config/sync_config.dart';
import 'services/auth_service.dart';
import 'services/turso_sync_service.dart';

/// Login / signup gate. Shown after consent, before the app is usable.
///
/// On success: if the account already has data in the cloud (or the user has
/// onboarded locally), go to the main app; otherwise start onboarding.
class AuthScreen extends StatefulWidget {
  /// True if this device already completed onboarding (has an API key).
  final bool alreadyOnboarded;
  const AuthScreen({super.key, required this.alreadyOnboarded});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isSignup = false;
  bool _working = false;
  String _error = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _working = true;
      _error = '';
    });

    final auth = AuthService();
    final email = _emailCtrl.text;
    final pass = _passCtrl.text;

    final result = _isSignup
        ? await auth.signup(email, pass)
        : await auth.login(email, pass);

    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _working = false;
        _error = result.error ?? 'Something went wrong.';
      });
      return;
    }

    // Pull any existing cloud data for this account (restores after reinstall
    // or on a new device). Returns count of items restored.
    int restored = 0;
    try {
      restored = await TursoSyncService().pull();
    } catch (_) {}

    // If the account had data, or this device already onboarded, go straight
    // to the app. Otherwise begin onboarding.
    final goToApp = restored > 0 || widget.alreadyOnboarded;

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      CupertinoPageRoute(
        builder: (_) =>
            goToApp ? const MainTabScreen() : const OnboardingScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configured = SyncConfig.tursoEnabled;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CupertinoPageScaffold(
        backgroundColor: kBg,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 30),
              Text(
                _isSignup ? 'CREATE\nACCOUNT' : 'WELCOME\nBACK',
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w900,
                  height: 0.95,
                  letterSpacing: -2,
                  color: CupertinoColors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your data is backed up to the cloud so it is never lost.',
                style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13),
              ),
              const SizedBox(height: 28),

              if (!configured)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Note: cloud accounts are not configured in this build. '
                    'Ask the developer to set the Turso URL/token.',
                    style: TextStyle(color: kPink, fontSize: 12),
                  ),
                ),

              BentoCard(
                glowColor: const Color(0x3300FFD1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('EMAIL',
                        style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _emailCtrl,
                      placeholder: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: CupertinoColors.white, fontSize: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14)),
                    ),
                    const SizedBox(height: 16),
                    const Text('PASSWORD',
                        style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 8),
                    CupertinoTextField(
                      controller: _passCtrl,
                      placeholder: _isSignup ? 'At least 8 characters' : 'Your password',
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _working ? null : _submit(),
                      style: const TextStyle(color: CupertinoColors.white, fontSize: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14)),
                    ),
                    if (_error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error, style: const TextStyle(color: kPink, fontSize: 13)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              NeonButton(
                text: _isSignup ? 'Sign Up' : 'Log In',
                isLoading: _working,
                onPressed: configured ? _submit : () {},
              ),
              const SizedBox(height: 14),
              Center(
                child: CupertinoButton(
                  onPressed: _working
                      ? null
                      : () => setState(() {
                            _isSignup = !_isSignup;
                            _error = '';
                          }),
                  child: Text(
                    _isSignup
                        ? 'Already have an account? Log in'
                        : "New here? Create an account",
                    style: const TextStyle(color: kTeal, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
