import 'package:shared_preferences/shared_preferences.dart';

class StreakService {
  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  int currentStreak = 0;
  int maxStreak = 0;
  DateTime? lastLogDate;

  Future<void> loadStreaks() async {
    final prefs = await SharedPreferences.getInstance();
    currentStreak = prefs.getInt('current_streak') ?? 0;
    maxStreak = prefs.getInt('max_streak') ?? 0;
    final l = prefs.getString('last_log_date');
    if (l != null) lastLogDate = DateTime.parse(l);

    _checkStreak();
  }

  void _checkStreak() async {
    if (lastLogDate == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final last = DateTime(lastLogDate!.year, lastLogDate!.month, lastLogDate!.day);

    final diff = today.difference(last).inDays;
    if (diff > 1) {
      // Streak broken. No way to restore it as per user requirement!
      currentStreak = 0;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('current_streak', 0);
    }
  }

  Future<void> logActivity() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    if (lastLogDate != null) {
      final last = DateTime(lastLogDate!.year, lastLogDate!.month, lastLogDate!.day);
      if (today.isAtSameMomentAs(last)) {
        return; // Already logged today
      }
      final diff = today.difference(last).inDays;
      if (diff == 1) {
        currentStreak++;
      } else if (diff > 1) {
        currentStreak = 1;
      }
    } else {
      currentStreak = 1;
    }

    if (currentStreak > maxStreak) {
      maxStreak = currentStreak;
    }

    lastLogDate = now;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_streak', currentStreak);
    await prefs.setInt('max_streak', maxStreak);
    await prefs.setString('last_log_date', now.toIso8601String());
  }

  // Milestones feature
  List<String> getEarnedMilestones() {
    final List<String> earned = [];
    if (currentStreak >= 3) earned.add('3-Day Warrior');
    if (currentStreak >= 7) earned.add('One Week Strong');
    if (currentStreak >= 14) earned.add('Two Week Titan');
    if (currentStreak >= 30) earned.add('Monthly Master');
    if (currentStreak >= 100) earned.add('Century Club');
    return earned;
  }
}
