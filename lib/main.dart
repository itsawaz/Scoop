import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding.dart';
import 'tabs.dart';
import 'consent_screen.dart';
import 'auth_screen.dart';
import 'services/auth_service.dart';
import 'services/turso_sync_service.dart';
import 'services/training_queue.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  bool hasKey = false;
  bool consented = false;
  bool loggedIn = false;

  try {
    final prefs = await SharedPreferences.getInstance();
    hasKey = prefs.getString('api_key') != null;
    consented = prefs.getBool(kConsentPrefKey) ?? false;
    // Populates AuthService's in-memory session cache used by the sync layer.
    loggedIn = await AuthService().isLoggedIn();
  } catch (_) {}

  // Best-effort background sync on launch (all no-ops if not configured):
  // push local changes up and drain the training-upload queue.
  if (loggedIn) {
    TursoSyncService().push();
    TrainingQueue().flush();
  }

  runApp(CalorieApp(
    startOnboarded: hasKey,
    consented: consented,
    loggedIn: loggedIn,
  ));
}

class CalorieApp extends StatelessWidget {
  final bool startOnboarded;
  final bool consented;
  final bool loggedIn;
  const CalorieApp({
    super.key,
    required this.startOnboarded,
    required this.consented,
    required this.loggedIn,
  });

  @override
  Widget build(BuildContext context) {
    // Flow: consent -> auth (login/signup) -> onboarding (if new) / main app.
    final Widget home;
    if (!consented) {
      home = ConsentScreen(alreadyOnboarded: startOnboarded);
    } else if (!loggedIn) {
      home = AuthScreen(alreadyOnboarded: startOnboarded);
    } else if (startOnboarded) {
      home = const MainTabScreen();
    } else {
      home = const OnboardingScreen();
    }

    return CupertinoApp(
      title: 'Hoop',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFFCDFF3C),
        scaffoldBackgroundColor: Color(0xFF050508),
      ),
      home: home,
    );
  }
}
