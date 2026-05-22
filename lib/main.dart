import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widgets.dart';
import 'onboarding.dart';
import 'tabs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final prefs = await SharedPreferences.getInstance();
    final hasKey = prefs.getString('api_key') != null;
    runApp(CalorieApp(startOnboarded: hasKey));
  } catch (e) {
    runApp(const CalorieApp(startOnboarded: false));
  }
}

class CalorieApp extends StatelessWidget {
  final bool startOnboarded;
  const CalorieApp({super.key, required this.startOnboarded});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'NutriAI',
      debugShowCheckedModeBanner: false,
      theme: const CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFFE5FF00),
        scaffoldBackgroundColor: Color(0xFF0A0A0A),
      ),
      home: startOnboarded ? const MainTabScreen() : const OnboardingScreen(),
    );
  }
}
