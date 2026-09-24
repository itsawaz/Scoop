import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets.dart';
import 'auth_screen.dart';

const String kConsentPrefKey = 'data_consent_accepted';

/// Mandatory data-collection consent gate shown before the app can be used.
///
/// Using the app requires agreeing that meal photos + AI analysis are stored
/// and shared to improve the AI model, and that data is synced to the cloud so
/// it survives reinstalls. Declining exits the flow — the app cannot be used
/// without consent, by product requirement.
class ConsentScreen extends StatefulWidget {
  /// Where to go after consent is granted: true if the user has already
  /// onboarded (has an API key), false to start onboarding.
  final bool alreadyOnboarded;
  const ConsentScreen({super.key, required this.alreadyOnboarded});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _working = false;

  Future<void> _accept() async {
    setState(() => _working = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kConsentPrefKey, true);
    if (!mounted) return;
    // After consent, require login/signup before using the app.
    Navigator.of(context, rootNavigator: true).pushReplacement(
      CupertinoPageRoute(
        builder: (_) => AuthScreen(alreadyOnboarded: widget.alreadyOnboarded),
      ),
    );
  }

  void _decline() {
    showCupertinoDialog(
      context: context,
      builder: (dctx) => CupertinoAlertDialog(
        title: const Text('Consent Required'),
        content: const Text(
          'Data collection is required to use this app. Without it, the app '
          'cannot be used. You can close the app, or accept to continue.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(dctx),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Review Again'),
            onPressed: () => Navigator.pop(dctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kBg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 20),
            const Text(
              'BEFORE\nYOU START',
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w900,
                height: 0.95,
                letterSpacing: -2,
                color: CupertinoColors.white,
              ),
            ),
            const SizedBox(height: 28),
            BentoCard(
              glowColor: const Color(0x3300FFD1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('DATA COLLECTION & SYNC',
                      style: TextStyle(
                          color: kTeal,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
                  SizedBox(height: 14),
                  _ConsentPoint(
                    icon: '📸',
                    title: 'Meal photos & AI analysis',
                    body:
                        'When you analyze a meal, the photo and the AI\'s nutrition '
                        'analysis are stored and shared with us to train and improve '
                        'the AI model.',
                  ),
                  SizedBox(height: 14),
                  _ConsentPoint(
                    icon: '☁️',
                    title: 'Cloud sync',
                    body:
                        'Your logs (meals, weight, supplements, profile) are backed '
                        'up to the cloud so your data is not lost if you reinstall '
                        'the app.',
                  ),
                  SizedBox(height: 14),
                  _ConsentPoint(
                    icon: '🔒',
                    title: 'Your control',
                    body:
                        'Data is tied to a private account id on your device. Photos '
                        'are removed from your device once uploaded.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Data collection is required to use this app.',
              style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            NeonButton(
              text: 'I Agree & Continue',
              isLoading: _working,
              onPressed: _accept,
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: _working ? null : _decline,
              child: const Text('I do not agree',
                  style: TextStyle(color: CupertinoColors.systemGrey)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _ConsentPoint extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  const _ConsentPoint(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(body,
                  style: const TextStyle(
                      color: CupertinoColors.systemGrey,
                      fontSize: 13,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}
