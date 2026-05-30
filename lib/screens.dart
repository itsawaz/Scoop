import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold, GridView, Curves, Colors;
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'widgets.dart';
import 'detail_screens.dart';
import 'services/health_service.dart';
import 'services/streak_service.dart';
import 'services/fasting_service.dart';
import 'services/storage_service.dart';
import 'log_sheets.dart';
import 'services/coach_service.dart';
import 'state.dart';

// ==========================================
// DASHBOARD
// ==========================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  String _name = '';
  int _mealCount = 0;
  int _streak = 0;
  int _xp = 0;
  int _level = 1;
  NutritionData _totals = NutritionData.zero();
  GoalProfile _goals = GoalProfile(calorieGoal: 2000, proteinGoalG: 50, carbsGoalG: 260, fatGoalG: 65, fiberGoalG: 25, sugarLimitG: 50, sodiumLimitMg: 2300, vitaminCGoalMg: 90, vitaminDGoalMcg: 20, calciumGoalMg: 1000, ironGoalMg: 18, waterGoalMl: 2500, aiRationale: '', computedAt: DateTime.now(), conditionAdjustments: {});
  Map<String, double> _overrides = {};
  final List<MealEntry> _todayMeals = [];

  
  // Health
  HealthSnapshot _health = HealthSnapshot();
  bool _healthLoading = true;
  String _aiHypeMessage = '';

  Timer? _refreshTimer;
  StreamSubscription<HealthSnapshot>? _healthStreamSubscription;

  // Date picker
  DateTime _selectedDate = globalSelectedDate.value;

  double _getGoal(String key, double defaultVal) {
    return _overrides[key] ?? defaultVal;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedDate = globalSelectedDate.value;
    globalSelectedDate.addListener(_onDateChanged);
    _loadData();
    
    // Request health permissions upfront (only shows dialog once)
    _requestHealthPermissions();
    
    _loadHealth();
    if (isSelectedDateToday) _startRealtimeHealthStream();
    
    // Refresh every 10 minutes for deep snapshot
    _refreshTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      _loadData();
      _loadHealth();
    });
  }

  void _onDateChanged() {
    setState(() {
      _selectedDate = globalSelectedDate.value;
    });
    _healthStreamSubscription?.cancel();
    HealthService().disposeRealtimeStream();
    _loadData();
    _loadHealth();
    if (isSelectedDateToday) _startRealtimeHealthStream();
  }

  Future<void> _requestHealthPermissions() async {
    try {
      await HealthService().requestPermissions();
    } catch (e) {
      // Silently handle permission request errors
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    globalSelectedDate.removeListener(_onDateChanged);
    _refreshTimer?.cancel();
    _healthStreamSubscription?.cancel();
    HealthService().disposeRealtimeStream();
    super.dispose();
  }

  Future<void> _updateHypeMessage() async {
    final effective = _totals.calories - (_health.activeCals + _health.basalCals);
    final msg = await CoachService().getHypeMessage(effective, _totals.calories.toDouble(), _health.activeCals + _health.basalCals);
    if (mounted) {
      setState(() {
        _aiHypeMessage = msg;
      });
    }
  }

  void _startRealtimeHealthStream() {
    // Listen to real-time health updates (every 5 seconds - matches health service)
    _healthStreamSubscription = HealthService()
      .getRealtimeHealthStream(refreshInterval: const Duration(seconds: 5))
        .listen((snapshot) {
      if (mounted) {
        print('[Dashboard] Received health snapshot - Active: ${snapshot.activeCals}, Basal: ${snapshot.basalCals}');
        setState(() {
          _health = snapshot;
          _healthLoading = false;
        });
        _updateHypeMessage();
      }
    }, onError: (e) {
      print('[Dashboard] Stream error: $e');
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
      _loadHealth();
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _name = prefs.getString('name') ?? 'Bestie';

    final goalStr = prefs.getString('goals_json');
    if (goalStr != null) {
      _goals = GoalProfile.fromJson(jsonDecode(goalStr));
    }
    
    final overridesStr = prefs.getString('nutrient_overrides');
    if (overridesStr != null) {
      try {
        final raw = jsonDecode(overridesStr) as Map<String, dynamic>;
        _overrides = raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } catch (_) {}
    }

    _streak = StreakService().currentStreak;
    // Dummy XP logic
    _xp = prefs.getInt('xp') ?? (_streak * 50);
    _level = (_xp ~/ 1000) + 1;
    final currentLevelXp = _xp % 1000;

    final historyList = prefs.getStringList('history') ?? [];
    int cals = 0;
    double p = 0, c = 0, f = 0, s = 0, fib = 0, sod = 0;
    double vc = 0, vd = 0, cal = 0, iron = 0;
    double satFat = 0, transFat = 0, chol = 0, pot = 0, mag = 0, zinc = 0, va = 0, vb6 = 0, vb12 = 0, folate = 0, phos = 0, iodine = 0;
    
    final now = DateTime.now();
    final selDate = _selectedDate;
    _todayMeals.clear();

    for (var str in historyList) {
      try {
        final e = MealEntry.fromJson(jsonDecode(str));
        if (e.timestamp.year == selDate.year && e.timestamp.month == selDate.month && e.timestamp.day == selDate.day) {
          _todayMeals.add(e);
          cals += e.nutrition.calories;
          p += e.nutrition.protein;
          c += e.nutrition.carbs;
          f += e.nutrition.fat;
          s += e.nutrition.sugar;
          fib += e.nutrition.fiber;
          sod += e.nutrition.sodium;
          vc += e.nutrition.vitaminC;
          vd += e.nutrition.vitaminD;
          cal += e.nutrition.calcium;
          iron += e.nutrition.iron;
          satFat += e.nutrition.saturatedFat;
          transFat += e.nutrition.transFat;
          chol += e.nutrition.cholesterol;
          pot += e.nutrition.potassium;
          mag += e.nutrition.magnesium;
          zinc += e.nutrition.zinc;
          va += e.nutrition.vitaminA;
          vb6 += e.nutrition.vitaminB6;
          vb12 += e.nutrition.vitaminB12;
          folate += e.nutrition.folate;
          phos += e.nutrition.phosphorus;
          iodine += e.nutrition.iodine;
        }
      } catch (_) {}
    }

    // Add supplement logs to daily totals
    final supplementList = prefs.getStringList('supplement_log') ?? [];
    for (var str in supplementList) {
      try {
        final e = SupplementEntry.fromJson(jsonDecode(str));
        if (e.timestamp.year == selDate.year && e.timestamp.month == selDate.month && e.timestamp.day == selDate.day) {
          cals += e.calories;
          p += e.proteinG;
          c += e.carbsG;
          f += e.fatG;
        }
      } catch (_) {}
    }

    setState(() {
      _mealCount = _todayMeals.length;
      _totals = NutritionData(
        foodName: 'Total',
        calories: cals, protein: p, carbs: c, fat: f, sugar: s, fiber: fib,
        sodium: sod, vitaminC: vc, vitaminD: vd, calcium: cal, iron: iron,
        saturatedFat: satFat, transFat: transFat, cholesterol: chol, potassium: pot,
        magnesium: mag, zinc: zinc, vitaminA: va, vitaminB6: vb6, vitaminB12: vb12,
        folate: folate, phosphorus: phos, iodine: iodine,
        reasoning: '', medicalAlert: '',
      );
      _xp = currentLevelXp;
    });
  }

  Future<void> _loadHealth() async {
    final snap = await HealthService().fetchDeepSnapshot(targetDate: _selectedDate);
    if (mounted) {
      setState(() {
        _health = snap;
        _healthLoading = false;
      });
      _updateHypeMessage();
    }
  }

  void _openNutrient(BuildContext context, String key, String label, String value, String unit, String goalLabel, double current, double defaultGoal, Color color) {
    final overriddenGoal = _getGoal(key, defaultGoal);
    Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(
      builder: (_) => NutrientDetailScreen(
        nutrientKey: key,
        label: label,
        value: value,
        unit: unit,
        goalLabel: goalLabel,
        current: current,
        goal: overriddenGoal,
        aiRecommended: defaultGoal,
        color: color,
        todayMeals: _todayMeals,
      ),
    )).then((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kBg,
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            CupertinoSliverRefreshControl(
              onRefresh: () async {
                _loadData();
                await _loadHealth();
              },
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 140), // padding for nav bar
              sliver: SliverList(
                delegate: SliverChildListDelegate([
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('WASSUP,', style: const TextStyle(color: kTextMuted, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      Text(_name.toUpperCase(), style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1, letterSpacing: -1, color: kTextPrimary)),
                      const SizedBox(height: 8),
                      // Inline date switcher
                      _InlineDatePill(
                        selectedDate: _selectedDate,
                        onDateChanged: (d) => globalSelectedDate.value = d,
                      ),
                    ],
                  ),
                ),
                StreakBadge(streak: _streak),
              ],
            ),
            const SizedBox(height: 16),

            // GAMIFICATION BAR
            XPBar(xp: _xp, maxXp: 1000, level: _level),
            const SizedBox(height: 24),

            // CALORIE HERO
            GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _openNutrient(context, 'calories', 'Calories', '${_totals.calories}', 'kcal', 'Daily Calorie Goal', _totals.calories.toDouble(), _goals.calorieGoal.toDouble(), kNeon),
                    child: CalorieDonut(
                      consumed: _totals.calories, 
                      goal: _getGoal('calories', _goals.calorieGoal.toDouble()).round(), 
                      burnt: _health.activeCals.round(),
                      resting: _health.basalCals.round(),
                    ),
                  ),
                  if (_aiHypeMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _aiHypeMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: kNeon,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Text('CONSUMED', style: TextStyle(color: kTextMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text('${_totals.calories} kcal', style: const TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('ACTIVE', style: TextStyle(color: kTextMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text('${_health.activeCals.round()} kcal', style: const TextStyle(color: Color(0xFFFF9F2E), fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('RESTING', style: TextStyle(color: kTextMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text('${_health.basalCals.round()} kcal', style: const TextStyle(color: Color(0xFF8B5CF6), fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MacroPill('PROT', '${_totals.protein.round()}g', const Color(0xFFFF9F2E)),
                      _MacroPill('CARB', '${_totals.carbs.round()}g', const Color(0xFF3B82F6)),
                      _MacroPill('FAT', '${_totals.fat.round()}g', const Color(0xFF8B5CF6)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // DEEP HEALTH METRICS
            SectionHeader(title: 'Health Snapshot'),
            if (_healthLoading)
              const Center(child: CupertinoActivityIndicator())
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  StatTile(
                    label: 'HEALTH SCORE', value: '${_health.healthScore}', unit: '/ 100',
                    color: kNeon, fillFraction: _health.healthScore / 100.0,
                    onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => HealthDetailScreen(health: _health, metricKey: 'health_score', label: 'Health Score', color: kNeon))),
                  ),
                  StatTile(
                    label: 'ACTIVE BURN', value: '${_health.activeCals.round()}', unit: 'kcal',
                    color: const Color(0xFFFF9F2E), fillFraction: (_health.activeCals / 1000).clamp(0.0, 1.0),
                    onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => HealthDetailScreen(health: _health, metricKey: 'active_burn', label: 'Active Burn', color: const Color(0xFFFF9F2E)))),
                  ),
                  StatTile(
                    label: 'STEPS', value: '${_health.steps}', unit: 'steps',
                    color: kNeon, fillFraction: (_health.steps / 10000).clamp(0.0, 1.0),
                    onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => HealthDetailScreen(health: _health, metricKey: 'steps', label: 'Steps', color: kNeon))),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, CupertinoPageRoute(builder: (_) => AllHealthScreen(health: _health)));
                    },
                    child: Container(
                      decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16)),
                      child: const Center(
                        child: Text('See All ➔', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // MACROS GRID
            SectionHeader(title: 'Nutrition'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                StatTile(
                  label: 'PROTEIN', value: '${_totals.protein.round()}g', unit: 'Goal: ${_getGoal('protein', _goals.proteinGoalG).round()}g',
                  color: kProtein, fillFraction: _getGoal('protein', _goals.proteinGoalG) > 0 ? _totals.protein / _getGoal('protein', _goals.proteinGoalG) : 0,
                  onTap: () => _openNutrient(context, 'protein', 'Protein', '${_totals.protein.round()}g', 'g', 'Goal', _totals.protein, _getGoal('protein', _goals.proteinGoalG), kProtein),
                ),
                StatTile(
                  label: 'CARBS', value: '${_totals.carbs.round()}g', unit: 'Goal: ${_getGoal('carbs', _goals.carbsGoalG).round()}g',
                  color: kCarbs, fillFraction: _getGoal('carbs', _goals.carbsGoalG) > 0 ? _totals.carbs / _getGoal('carbs', _goals.carbsGoalG) : 0,
                  onTap: () => _openNutrient(context, 'carbs', 'Carbs', '${_totals.carbs.round()}g', 'g', 'Goal', _totals.carbs, _getGoal('carbs', _goals.carbsGoalG), kCarbs),
                ),
                StatTile(
                  label: 'FAT', value: '${_totals.fat.round()}g', unit: 'Limit: ${_getGoal('fat', _goals.fatGoalG).round()}g',
                  color: kFat, fillFraction: _getGoal('fat', _goals.fatGoalG) > 0 ? _totals.fat / _getGoal('fat', _goals.fatGoalG) : 0,
                  onTap: () => _openNutrient(context, 'fat', 'Fat', '${_totals.fat.round()}g', 'g', 'Limit', _totals.fat, _getGoal('fat', _goals.fatGoalG), kFat),
                ),
                StatTile(
                  label: 'SUGAR', value: '${_totals.sugar.round()}g', unit: 'Limit: ${_getGoal('sugar', _goals.sugarLimitG).round()}g',
                  color: kSugar, fillFraction: _getGoal('sugar', _goals.sugarLimitG) > 0 ? _totals.sugar / _getGoal('sugar', _goals.sugarLimitG) : 0,
                  onTap: () => _openNutrient(context, 'sugar', 'Sugar', '${_totals.sugar.round()}g', 'g', 'Limit', _totals.sugar, _getGoal('sugar', _goals.sugarLimitG), kSugar),
                ),
                StatTile(
                  label: 'FIBER', value: '${_totals.fiber.round()}g', unit: 'Goal: ${_getGoal('fiber', _goals.fiberGoalG).round()}g',
                  color: kTeal, fillFraction: _getGoal('fiber', _goals.fiberGoalG) > 0 ? _totals.fiber / _getGoal('fiber', _goals.fiberGoalG) : 0,
                  onTap: () => _openNutrient(context, 'fiber', 'Fiber', '${_totals.fiber.round()}g', 'g', 'Goal', _totals.fiber, _getGoal('fiber', _goals.fiberGoalG), kTeal),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, CupertinoPageRoute(builder: (_) => AllNutritionScreen(
                      totals: _totals,
                      goals: _goals,
                      getGoal: _getGoal,
                      onNutrientTap: _openNutrient,
                    )));
                  },
                  child: Container(
                    decoration: BoxDecoration(color: kSurface, borderRadius: BorderRadius.circular(16)),
                    child: const Center(
                      child: Text('See All ➔', style: TextStyle(color: kTextPrimary, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // MILESTONES
            SectionHeader(title: 'Achievements'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  MilestoneBadge(title: 'First Log', emoji: '🌱', earned: _streak > 0),
                  MilestoneBadge(title: '3 Day Streak', emoji: '🔥', earned: _streak >= 3),
                  MilestoneBadge(title: '7 Day Streak', emoji: '⚡', earned: _streak >= 7),
                  MilestoneBadge(title: 'Level 5', emoji: '👑', earned: _level >= 5),
                ],
              ),
            ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: kTextMuted, fontSize: 10, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _InlineDatePill extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const _InlineDatePill({required this.selectedDate, required this.onDateChanged});

  String _label(DateTime d) {
    final now = DateTime.now();
    if (isSameDay(d, now)) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (isSameDay(d, yesterday)) return 'Yesterday';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isToday = isSameDay(selectedDate, DateTime.now());
    return GestureDetector(
      onTap: () => _showDatePicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isToday ? kSurface : kNeon.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isToday ? kBorder : kNeon.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left chevron
            GestureDetector(
              onTap: () => onDateChanged(selectedDate.subtract(const Duration(days: 1))),
              child: const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(CupertinoIcons.chevron_left, color: kTextMuted, size: 12),
              ),
            ),
            Icon(CupertinoIcons.calendar, color: isToday ? kTextMuted : kNeon, size: 13),
            const SizedBox(width: 5),
            Text(
              _label(selectedDate),
              style: TextStyle(
                color: isToday ? kTextMuted : kNeon,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            // Right chevron (hidden when today)
            if (!isToday) ...[
              GestureDetector(
                onTap: () => onDateChanged(selectedDate.add(const Duration(days: 1))),
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(CupertinoIcons.chevron_right, color: kTextMuted, size: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => Container(
        height: 280,
        decoration: const BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('Today', style: TextStyle(color: kNeon)),
                    onPressed: () {
                      onDateChanged(DateTime.now());
                      Navigator.pop(context);
                    },
                  ),
                  CupertinoButton(
                    child: const Text('Done', style: TextStyle(color: kNeon, fontWeight: FontWeight.bold)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: selectedDate,
                maximumDate: DateTime.now(),
                minimumDate: DateTime.now().subtract(const Duration(days: 365)),
                onDateTimeChanged: onDateChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// HISTORY SCREEN
// ==========================================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final Map<String, List<dynamic>> _grouped = {}; // Mixed MealEntry and SupplementEntry



  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final mealList = prefs.getStringList('history') ?? [];
    final supplementList = prefs.getStringList('supplement_log') ?? [];
    
    final Map<String, List<dynamic>> groups = {};
    
    // Add meals
    for (var str in mealList) {
      try {
        final e = MealEntry.fromJson(jsonDecode(str));
        final day = "${e.timestamp.year}-${e.timestamp.month.toString().padLeft(2,'0')}-${e.timestamp.day.toString().padLeft(2,'0')}";
        groups.putIfAbsent(day, () => []).add(e);
      } catch (_) {}
    }
    
    // Add supplements
    for (var str in supplementList) {
      try {
        final e = SupplementEntry.fromJson(jsonDecode(str));
        final day = "${e.timestamp.year}-${e.timestamp.month.toString().padLeft(2,'0')}-${e.timestamp.day.toString().padLeft(2,'0')}";
        groups.putIfAbsent(day, () => []).add(e);
      } catch (_) {}
    }
    
    // Sort descending
    for (var day in groups.keys) {
      groups[day]!.sort((a, b) {
        final timeA = (a is MealEntry) ? a.timestamp : (a as SupplementEntry).timestamp;
        final timeB = (b is MealEntry) ? b.timestamp : (b as SupplementEntry).timestamp;
        return timeB.compareTo(timeA);
      });
    }
    final sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final Map<String, List<dynamic>> sortedMap = {};
    for (var k in sortedKeys) {
      sortedMap[k] = groups[k]!;
    }

    setState(() {
      _grouped.clear();
      _grouped.addAll(sortedMap);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kBg,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Text('HISTORY', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: kTextPrimary, letterSpacing: -1)),
            ),
            Expanded(
              child: _grouped.isEmpty
                  ? const Center(child: Text('No meals logged yet.', style: TextStyle(color: kTextMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 140), // padding for nav bar
                      itemCount: _grouped.length,
                      itemBuilder: (context, index) {
                        final dateStr = _grouped.keys.elementAt(index);
                        final entries = _grouped[dateStr]!;
                        final totalCals = entries.fold<int>(0, (sum, entry) {
                          if (entry is MealEntry) return sum + entry.nutrition.calories;
                          if (entry is SupplementEntry) return sum + entry.calories;
                          return sum;
                        });
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(dateStr, style: const TextStyle(color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                                  Text('$totalCals kcal', style: const TextStyle(color: kNeon, fontSize: 14, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              GlassCard(
                                padding: EdgeInsets.zero,
                                child: Column(
                                  children: entries.map((entry) {
                                    final isLast = entry == entries.last;
                                    
                                    if (entry is MealEntry) {
                                      final time = "${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}";
                                      final display = entry.nutrition.foodName.isNotEmpty ? entry.nutrition.foodName : entry.note;
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.of(context, rootNavigator: true).push(
                                            CupertinoPageRoute(builder: (_) => MealDetailScreen(
                                              entry: entry, 
                                              onSaved: () {
                                                _grouped.clear();
                                                _loadHistory();
                                              }
                                            ))
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            border: isLast ? null : const Border(bottom: BorderSide(color: kBorder)),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(time, style: const TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 16),
                                              Expanded(child: Text(display, style: const TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                              Text('${entry.nutrition.calories}', style: const TextStyle(color: kNeon, fontSize: 16, fontWeight: FontWeight.w900)),
                                              const Icon(CupertinoIcons.chevron_right, color: kTextMuted, size: 14),
                                            ],
                                          ),
                                        ),
                                      );
                                    } else if (entry is SupplementEntry) {
                                      final time = "${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}";
                                      return Dismissible(
                                        key: Key(entry.id),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: 20),
                                          color: CupertinoColors.destructiveRed,
                                          child: const Icon(CupertinoIcons.delete, color: CupertinoColors.white),
                                        ),
                                        confirmDismiss: (_) async {
                                          return await showCupertinoDialog<bool>(
                                            context: context,
                                            builder: (_) => CupertinoAlertDialog(
                                              title: const Text('Delete Supplement?'),
                                              content: const Text('This will remove it from your daily totals.'),
                                              actions: [
                                                CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
                                                CupertinoDialogAction(isDestructiveAction: true, child: const Text('Delete'), onPressed: () => Navigator.pop(context, true)),
                                              ],
                                            ),
                                          );
                                        },
                                        onDismissed: (_) async {
                                          await StorageService().deleteSupplementLog(entry.id);
                                          _grouped.clear();
                                          _loadHistory();
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            border: isLast ? null : const Border(bottom: BorderSide(color: kBorder)),
                                          ),
                                          child: Row(
                                            children: [
                                              Text(time, style: const TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('🥛 ${entry.brand}', style: const TextStyle(color: kTextPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                                                    if (entry.type.isNotEmpty)
                                                      Text(entry.type, style: const TextStyle(color: kTextMuted, fontSize: 12)),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text('${entry.proteinG.toStringAsFixed(1)}g P • ${entry.carbsG.toStringAsFixed(1)}g C • ${entry.fatG.toStringAsFixed(1)}g F', 
                                                    style: const TextStyle(color: const Color(0xFFFF9F2E), fontSize: 12, fontWeight: FontWeight.w700)),
                                                  Text('${entry.calories} kcal', style: const TextStyle(color: kNeon, fontSize: 12, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ALL NUTRITION SCREEN
// ==========================================
class AllNutritionScreen extends StatelessWidget {
  final NutritionData totals;
  final GoalProfile goals;
  final double Function(String, double) getGoal;
  final void Function(BuildContext, String, String, String, String, String, double, double, Color) onNutrientTap;

  const AllNutritionScreen({
    super.key,
    required this.totals,
    required this.goals,
    required this.getGoal,
    required this.onNutrientTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kBg,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: kBg,
        middle: Text('All Nutrition', style: TextStyle(color: kTextPrimary)),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                StatTile(
                  label: 'PROTEIN', value: '${totals.protein.round()}g', unit: 'Goal: ${getGoal('protein', goals.proteinGoalG).round()}g',
                  color: kProtein, fillFraction: getGoal('protein', goals.proteinGoalG) > 0 ? totals.protein / getGoal('protein', goals.proteinGoalG) : 0,
                  onTap: () => onNutrientTap(context, 'protein', 'Protein', '${totals.protein.round()}g', 'g', 'Goal', totals.protein, getGoal('protein', goals.proteinGoalG), kProtein),
                ),
                StatTile(
                  label: 'CARBS', value: '${totals.carbs.round()}g', unit: 'Goal: ${getGoal('carbs', goals.carbsGoalG).round()}g',
                  color: kCarbs, fillFraction: getGoal('carbs', goals.carbsGoalG) > 0 ? totals.carbs / getGoal('carbs', goals.carbsGoalG) : 0,
                  onTap: () => onNutrientTap(context, 'carbs', 'Carbs', '${totals.carbs.round()}g', 'g', 'Goal', totals.carbs, getGoal('carbs', goals.carbsGoalG), kCarbs),
                ),
                StatTile(
                  label: 'FAT', value: '${totals.fat.round()}g', unit: 'Limit: ${getGoal('fat', goals.fatGoalG).round()}g',
                  color: kFat, fillFraction: getGoal('fat', goals.fatGoalG) > 0 ? totals.fat / getGoal('fat', goals.fatGoalG) : 0,
                  onTap: () => onNutrientTap(context, 'fat', 'Fat', '${totals.fat.round()}g', 'g', 'Limit', totals.fat, getGoal('fat', goals.fatGoalG), kFat),
                ),
                StatTile(
                  label: 'SUGAR', value: '${totals.sugar.round()}g', unit: 'Limit: ${getGoal('sugar', goals.sugarLimitG).round()}g',
                  color: kSugar, fillFraction: getGoal('sugar', goals.sugarLimitG) > 0 ? totals.sugar / getGoal('sugar', goals.sugarLimitG) : 0,
                  onTap: () => onNutrientTap(context, 'sugar', 'Sugar', '${totals.sugar.round()}g', 'g', 'Limit', totals.sugar, getGoal('sugar', goals.sugarLimitG), kSugar),
                ),
                StatTile(
                  label: 'FIBER', value: '${totals.fiber.round()}g', unit: 'Goal: ${getGoal('fiber', goals.fiberGoalG).round()}g',
                  color: kTeal, fillFraction: getGoal('fiber', goals.fiberGoalG) > 0 ? totals.fiber / getGoal('fiber', goals.fiberGoalG) : 0,
                  onTap: () => onNutrientTap(context, 'fiber', 'Fiber', '${totals.fiber.round()}g', 'g', 'Goal', totals.fiber, getGoal('fiber', goals.fiberGoalG), kTeal),
                ),
                StatTile(
                  label: 'SODIUM', value: '${totals.sodium.round()}mg', unit: 'Limit: ${getGoal('sodium', goals.sodiumLimitMg).round()}mg',
                  color: const Color(0xFFFACC15), fillFraction: getGoal('sodium', goals.sodiumLimitMg) > 0 ? totals.sodium / getGoal('sodium', goals.sodiumLimitMg) : 0,
                  onTap: () => onNutrientTap(context, 'sodium', 'Sodium', '${totals.sodium.round()}mg', 'mg', 'Limit', totals.sodium, getGoal('sodium', goals.sodiumLimitMg), const Color(0xFFFACC15)),
                ),
                StatTile(
                  label: 'TRANS FAT', value: '${totals.transFat.toStringAsFixed(1)}g', unit: 'Limit: ${getGoal('transFat', 0.0).round()}g',
                  color: CupertinoColors.destructiveRed, fillFraction: getGoal('transFat', 0.0) > 0 ? (totals.transFat / getGoal('transFat', 0.0)).clamp(0.0, 1.0) : (totals.transFat > 0 ? 1.0 : 0.0),
                  onTap: () => onNutrientTap(context, 'transFat', 'Trans Fat', '${totals.transFat.toStringAsFixed(1)}g', 'g', 'Limit', totals.transFat, 0.0, CupertinoColors.destructiveRed),
                ),
                StatTile(
                  label: 'CHOLESTEROL', value: '${totals.cholesterol.round()}mg', unit: 'Limit: ${getGoal('cholesterol', 300.0).round()}mg',
                  color: CupertinoColors.activeOrange, fillFraction: getGoal('cholesterol', 300.0) > 0 ? totals.cholesterol / getGoal('cholesterol', 300.0) : 0,
                  onTap: () => onNutrientTap(context, 'cholesterol', 'Cholesterol', '${totals.cholesterol.round()}mg', 'mg', 'Limit', totals.cholesterol, 300.0, CupertinoColors.activeOrange),
                ),
                StatTile(
                  label: 'IODINE', value: '${totals.iodine.round()}mcg', unit: 'Goal: ${getGoal('iodine', 150.0).round()}mcg',
                  color: CupertinoColors.systemIndigo, fillFraction: getGoal('iodine', 150.0) > 0 ? totals.iodine / getGoal('iodine', 150.0) : 0,
                  onTap: () => onNutrientTap(context, 'iodine', 'Iodine', '${totals.iodine.round()}mcg', 'mcg', 'Goal', totals.iodine, 150.0, CupertinoColors.systemIndigo),
                ),
                StatTile(
                  label: 'VITAMIN D', value: '${totals.vitaminD.round()}mcg', unit: 'Goal: ${getGoal('vitaminD', goals.vitaminDGoalMcg).round()}mcg',
                  color: const Color(0xFFFCD34D), fillFraction: getGoal('vitaminD', goals.vitaminDGoalMcg) > 0 ? totals.vitaminD / getGoal('vitaminD', goals.vitaminDGoalMcg) : 0,
                  onTap: () => onNutrientTap(context, 'vitaminD', 'Vitamin D', '${totals.vitaminD.round()}mcg', 'mcg', 'Goal', totals.vitaminD, getGoal('vitaminD', goals.vitaminDGoalMcg), const Color(0xFFFCD34D)),
                ),
                StatTile(
                  label: 'CALCIUM', value: '${totals.calcium.round()}mg', unit: 'Goal: ${getGoal('calcium', goals.calciumGoalMg).round()}mg',
                  color: CupertinoColors.systemGrey, fillFraction: getGoal('calcium', goals.calciumGoalMg) > 0 ? totals.calcium / getGoal('calcium', goals.calciumGoalMg) : 0,
                  onTap: () => onNutrientTap(context, 'calcium', 'Calcium', '${totals.calcium.round()}mg', 'mg', 'Goal', totals.calcium, getGoal('calcium', goals.calciumGoalMg), CupertinoColors.systemGrey),
                ),
                StatTile(
                  label: 'IRON', value: '${totals.iron.round()}mg', unit: 'Goal: ${getGoal('iron', goals.ironGoalMg).round()}mg',
                  color: CupertinoColors.systemBrown, fillFraction: getGoal('iron', goals.ironGoalMg) > 0 ? totals.iron / getGoal('iron', goals.ironGoalMg) : 0,
                  onTap: () => onNutrientTap(context, 'iron', 'Iron', '${totals.iron.round()}mg', 'mg', 'Goal', totals.iron, getGoal('iron', goals.ironGoalMg), CupertinoColors.systemBrown),
                ),
                StatTile(
                  label: 'POTASSIUM', value: '${totals.potassium.round()}mg', unit: 'Goal: ${getGoal('potassium', 3400.0).round()}mg',
                  color: CupertinoColors.systemYellow, fillFraction: getGoal('potassium', 3400.0) > 0 ? totals.potassium / getGoal('potassium', 3400.0) : 0,
                  onTap: () => onNutrientTap(context, 'potassium', 'Potassium', '${totals.potassium.round()}mg', 'mg', 'Goal', totals.potassium, 3400.0, CupertinoColors.systemYellow),
                ),
                StatTile(
                  label: 'MAGNESIUM', value: '${totals.magnesium.round()}mg', unit: 'Goal: ${getGoal('magnesium', 400.0).round()}mg',
                  color: CupertinoColors.activeGreen, fillFraction: getGoal('magnesium', 400.0) > 0 ? totals.magnesium / getGoal('magnesium', 400.0) : 0,
                  onTap: () => onNutrientTap(context, 'magnesium', 'Magnesium', '${totals.magnesium.round()}mg', 'mg', 'Goal', totals.magnesium, 400.0, CupertinoColors.activeGreen),
                ),
                StatTile(
                  label: 'ZINC', value: '${totals.zinc.round()}mg', unit: 'Goal: ${getGoal('zinc', 11.0).round()}mg',
                  color: CupertinoColors.systemTeal, fillFraction: getGoal('zinc', 11.0) > 0 ? totals.zinc / getGoal('zinc', 11.0) : 0,
                  onTap: () => onNutrientTap(context, 'zinc', 'Zinc', '${totals.zinc.round()}mg', 'mg', 'Goal', totals.zinc, 11.0, CupertinoColors.systemTeal),
                ),
                StatTile(
                  label: 'VITAMIN C', value: '${totals.vitaminC.round()}mg', unit: 'Goal: ${getGoal('vitaminC', goals.vitaminCGoalMg).round()}mg',
                  color: CupertinoColors.systemOrange, fillFraction: getGoal('vitaminC', goals.vitaminCGoalMg) > 0 ? totals.vitaminC / getGoal('vitaminC', goals.vitaminCGoalMg) : 0,
                  onTap: () => onNutrientTap(context, 'vitaminC', 'Vitamin C', '${totals.vitaminC.round()}mg', 'mg', 'Goal', totals.vitaminC, getGoal('vitaminC', goals.vitaminCGoalMg), CupertinoColors.systemOrange),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ALL HEALTH SCREEN
// ==========================================
class AllHealthScreen extends StatelessWidget {
  final HealthSnapshot health;

  const AllHealthScreen({super.key, required this.health});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kBg,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: kBg,
        middle: Text('All Health Metrics', style: TextStyle(color: kTextPrimary)),
        border: null,
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                StatTile(
                  label: 'HEALTH SCORE', value: '${health.healthScore}', unit: '/ 100',
                  color: kNeon, fillFraction: health.healthScore / 100.0,
                  onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => HealthDetailScreen(health: health, metricKey: 'health_score', label: 'Health Score', color: kNeon))),
                ),
                StatTile(
                  label: 'ACTIVE BURN', value: '${health.activeCals.round()}', unit: 'kcal',
                  color: const Color(0xFFFF9F2E), fillFraction: (health.activeCals / 1000).clamp(0.0, 1.0),
                  onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => HealthDetailScreen(health: health, metricKey: 'active_burn', label: 'Active Burn', color: const Color(0xFFFF9F2E)))),
                ),
                StatTile(
                  label: 'RESTING BURN', value: '${health.basalCals.round()}', unit: 'kcal',
                  color: const Color(0xFF8B5CF6), fillFraction: (health.basalCals / 2500).clamp(0.0, 1.0),
                  onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => HealthDetailScreen(health: health, metricKey: 'resting_burn', label: 'Resting Burn', color: const Color(0xFF8B5CF6)))),
                ),
                StatTile(
                  label: 'SLEEP', value: health.sleepHours.toStringAsFixed(1), unit: 'hr',
                  color: const Color(0xFF5E5CE6), fillFraction: (health.sleepHours / 8.0).clamp(0.0, 1.0),
                  onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => HealthDetailScreen(health: health, metricKey: 'sleep', label: 'Sleep', color: const Color(0xFF5E5CE6)))),
                ),
                StatTile(
                  label: 'MINDFUL', value: '${health.mindfulMinutes.round()}', unit: 'min',
                  color: kTeal, fillFraction: (health.mindfulMinutes / 30.0).clamp(0.0, 1.0),
                  onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => HealthDetailScreen(health: health, metricKey: 'mindful', label: 'Mindful Minutes', color: kTeal))),
                ),
                StatTile(
                  label: 'STEPS', value: '${health.steps}', unit: 'steps',
                  color: kNeon, fillFraction: (health.steps / 10000).clamp(0.0, 1.0),
                  onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => HealthDetailScreen(health: health, metricKey: 'steps', label: 'Steps', color: kNeon))),
                ),
                ...health.extendedMetrics.entries.map((e) {
                  final metricData = e.value as Map<String, dynamic>?;
                  if (metricData == null) return const SizedBox.shrink();
                  
                  return StatTile(
                    label: e.key.toUpperCase(),
                    value: '${metricData['value'] ?? ''}',
                    unit: metricData['unit'] ?? '',
                    color: CupertinoColors.systemGrey3,
                    fillFraction: 0.5,
                    onTap: () => Navigator.push(context, CupertinoPageRoute(builder: (_) => HealthDetailScreen(health: health, metricKey: 'extended:${e.key}', label: e.key, color: CupertinoColors.systemGrey3))),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
