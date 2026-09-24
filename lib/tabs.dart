import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show FloatingActionButtonLocation, Scaffold;
import 'models.dart';
import 'widgets.dart';
import 'screens.dart';
import 'log_meal.dart';
import 'onboarding.dart';
import 'log_sheets.dart';
import 'coach_screen.dart';
import 'fasting_screen.dart';
import 'services/coach_service.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});
  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  int _dashToken = 0;
  int _histToken = 0;

  @override
  void initState() {
    super.initState();
    CoachService().runDailyAutomationIfNeeded();
  }

  void _refreshDash() => setState(() => _dashToken++);
  void _refreshHist() => setState(() => _histToken++);

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) _refreshDash();
      if (index == 1) _refreshHist();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold provides a nice floating bottom nav bar capability
    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(key: ValueKey('dash-$_dashToken')),
          HistoryScreen(key: ValueKey('hist-$_histToken')),
          _LogWrapper(key: const ValueKey('log'), onMealLogged: () { _refreshDash(); _refreshHist(); }),
          const CoachScreen(),
          const ProfileScreen(),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _CustomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

class _CustomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const _CustomNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: kSurface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: kBorder2, width: 1.5),
        boxShadow: [
          BoxShadow(color: kBg.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _NavItem(icon: CupertinoIcons.chart_bar_fill, label: 'Dash', isSelected: currentIndex == 0, onTap: () => onTap(0)),
          _NavItem(icon: CupertinoIcons.calendar_today, label: 'Log', isSelected: currentIndex == 1, onTap: () => onTap(1)),
          
          // Center Big Add Button
          GestureDetector(
            onTap: () => onTap(2),
            child: Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: kNeon,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: kNeon.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 0),
                ],
              ),
              child: const Icon(CupertinoIcons.add, color: kBg, size: 32),
            ),
          ),
          
          _NavItem(icon: CupertinoIcons.heart_fill, label: 'Mann', isSelected: currentIndex == 3, onTap: () => onTap(3)),
          _NavItem(icon: CupertinoIcons.person_fill, label: 'Profile', isSelected: currentIndex == 4, onTap: () => onTap(4)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? kTextPrimary : kTextMuted,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? kTextPrimary : kTextMuted,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// LogWrapper (unchanged mostly, just UI tweak)
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

  void _openWeightLog() => showWeightLogSheet(context, () { widget.onMealLogged(); _showSuccess(); });
  void _openSupplementLog() => showSupplementLogSheet(context, () { widget.onMealLogged(); _showSuccess(); });
  void _openLibraryPicker() => Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute(builder: (_) => SavedMealsPickerScreen(onLogged: () { widget.onMealLogged(); _showSuccess(); })),
      );
  void _openFasting() => Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(builder: (_) => const FastingScreen()));

  void _showSuccess() {
    setState(() => _justLogged = true);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _justLogged = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kBg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_justLogged) ...[
                  const Center(child: Text('🔥', style: TextStyle(fontSize: 80))),
                  const SizedBox(height: 20),
                  const Text('LOGGED!', style: TextStyle(color: kNeon, fontSize: 40, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
                ] else ...[
                  const Text("WHAT'S\nNEXT?", style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, height: 0.9, letterSpacing: -2, color: kTextPrimary), textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                  PulseButton(text: '📸 Snap Meal', onPressed: _openLogMeal, height: 64, icon: const Icon(CupertinoIcons.camera_fill, color: kBg)),
                  const SizedBox(height: 16),
                  
                  CupertinoButton(
                    padding: const EdgeInsets.all(16),
                    color: kSurface2,
                    borderRadius: BorderRadius.circular(100),
                    onPressed: _openLibraryPicker,
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('📚 ', style: TextStyle(fontSize: 20)),
                      Text('Pick from Library', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(children: [
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.all(16), color: kSurface,
                        onPressed: _openWeightLog,
                        child: const Column(children: [Text('⚖️', style: TextStyle(fontSize: 28)), SizedBox(height: 8), Text('Weight', style: TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w800))]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.all(16), color: kSurface,
                        onPressed: _openSupplementLog,
                        child: const Column(children: [Text('🥛', style: TextStyle(fontSize: 28)), SizedBox(height: 8), Text('Supplements', style: TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w800))]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.all(16), color: kSurface,
                        onPressed: _openFasting,
                        child: const Column(children: [Text('⏳', style: TextStyle(fontSize: 28)), SizedBox(height: 8), Text('Fasting', style: TextStyle(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w800))]),
                      ),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
