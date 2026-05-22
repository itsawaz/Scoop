import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'widgets.dart';
import 'screens.dart';
import 'log_meal.dart';
import 'onboarding.dart';

// MainTabScreen lives here — imported by both main.dart and onboarding.dart
// This breaks the circular dependency.
class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});
  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  // Token-based key refresh: incrementing the token forces Flutter to
  // destroy & recreate the child widget, re-running initState & loading fresh data.
  int _dashToken = 0;
  int _histToken = 0;

  void _refreshDash() => setState(() => _dashToken++);
  void _refreshHist() => setState(() => _histToken++);

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      backgroundColor: kBg,
      tabBar: CupertinoTabBar(
        backgroundColor: kBg.withOpacity(0.9),
        activeColor: kNeon,
        inactiveColor: CupertinoColors.systemGrey,
        onTap: (idx) {
          if (idx == 0) _refreshDash();
          if (idx == 1) _refreshHist();
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.chart_bar_fill), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.calendar_today), label: 'History'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.add_circled_solid), label: 'Log'),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.person_crop_circle_fill), label: 'Profile'),
        ],
      ),
      tabBuilder: (context, index) {
        if (index == 0) return DashboardScreen(key: ValueKey('dash-$_dashToken'));
        if (index == 1) return HistoryScreen(key: ValueKey('hist-$_histToken'));
        if (index == 2) return _LogWrapper(
          key: const ValueKey('log'),
          onMealLogged: () { _refreshDash(); _refreshHist(); },
        );
        return const ProfileScreen();
      },
    );
  }
}

class _LogWrapper extends StatefulWidget {
  final VoidCallback onMealLogged;
  const _LogWrapper({super.key, required this.onMealLogged});
  @override
  State<_LogWrapper> createState() => _LogWrapperState();
}

class _LogWrapperState extends State<_LogWrapper> {
  bool _justLogged = false;

  void _openLogMeal() async {
    final entry = await Navigator.of(context, rootNavigator: true).push<MealEntry>(
      CupertinoPageRoute(builder: (_) => const LogMealScreen()),
    );
    if (entry != null) {
      widget.onMealLogged();
      setState(() => _justLogged = true);
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _justLogged = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kBg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_justLogged) ...[
                  const Text('🔥', style: TextStyle(fontSize: 80)),
                  const SizedBox(height: 20),
                  const Text('LOGGED!', style: TextStyle(color: kNeon, fontSize: 40, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Tap Dashboard to see your stats!', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14)),
                ] else ...[
                  const Text('📸', style: TextStyle(fontSize: 80)),
                  const SizedBox(height: 24),
                  const Text("WHAT'D\nYOU EAT?", style: TextStyle(fontSize: 50, fontWeight: FontWeight.w900, height: 0.9, letterSpacing: -2, color: CupertinoColors.white), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text('AI identifies your meal, estimates calories & nutrients, and checks it against your health profile.', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13, height: 1.5), textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                  NeonButton(text: 'Snap / Describe a Meal', onPressed: _openLogMeal),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
