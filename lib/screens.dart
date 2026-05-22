import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'widgets.dart';
import 'detail_screens.dart';

// ==========================================
// ANALYTICS DASHBOARD
// ==========================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  NutritionData _totals = NutritionData.zero();
  int _mealCount = 0;
  int _apiCalls = 0;
  String _name = '';
  List<MealEntry> _todayMeals = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? 'Bestie';
    final historyList = prefs.getStringList('history') ?? [];
    
    final now = DateTime.now();
    NutritionData totals = NutritionData.zero();
    int count = 0;
    List<MealEntry> todayMeals = [];

    for (var str in historyList) {
      try {
        final entry = MealEntry.fromJson(jsonDecode(str));
        if (entry.timestamp.year == now.year && entry.timestamp.month == now.month && entry.timestamp.day == now.day) {
          totals = totals + entry.nutrition;
          count++;
          todayMeals.add(entry);
        }
      } catch (_) {}
    }

    // API limit
    final apiDate = prefs.getString('api_date') ?? '';
    final todayStr = "${now.year}-${now.month}-${now.day}";
    int apiCount = apiDate == todayStr ? (prefs.getInt('api_count') ?? 0) : 0;

    setState(() {
      _name = name;
      _totals = totals;
      _mealCount = count;
      _todayMeals = todayMeals;
      _apiCalls = apiCount;
    });
  }

  void _openNutrient(BuildContext context, String key, String label, String value, String unit, String goalLabel, double current, double goal, Color color) {
    Navigator.of(context, rootNavigator: true).push(CupertinoPageRoute(
      builder: (_) => NutrientDetailScreen(
        nutrientKey: key,
        label: label,
        value: value,
        unit: unit,
        goalLabel: goalLabel,
        current: current,
        goal: goal,
        color: color,
        todayMeals: _todayMeals,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final apiPercent = (_apiCalls / 1500).clamp(0.0, 1.0);

    return CupertinoPageScaffold(
      backgroundColor: kBg,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('WASSUP,\n${_name.toUpperCase()}', style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, height: 0.9, letterSpacing: -2, color: CupertinoColors.white)),
            const SizedBox(height: 24),

            // Calorie Hero Card
            BentoCard(
              glowColor: const Color(0x88E5FF00),
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    const Text("TODAY'S TOTAL", style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text('${_totals.calories}', style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w900, letterSpacing: -4, color: CupertinoColors.white, height: 1)),
                    const Text('KCAL', style: TextStyle(color: kNeon, fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text('$_mealCount meal${_mealCount == 1 ? '' : 's'} logged', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // MACROS GRID
            const SectionHeader(title: 'Macros'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                StatTile(
                  label: 'PROTEIN', value: '${_totals.protein.round()}g', unit: 'Recommended 50g/day',
                  color: const Color(0xFFFF9500), fillFraction: _totals.protein / 50,
                  onTap: () => _openNutrient(context, 'protein', 'Protein', '${_totals.protein.round()}g', 'g', 'Goal: 50g', _totals.protein, 50, const Color(0xFFFF9500)),
                ),
                StatTile(
                  label: 'CARBS', value: '${_totals.carbs.round()}g', unit: 'Recommended 260g/day',
                  color: const Color(0xFF30D158), fillFraction: _totals.carbs / 260,
                  onTap: () => _openNutrient(context, 'carbs', 'Carbs', '${_totals.carbs.round()}g', 'g', 'Goal: 260g', _totals.carbs, 260, const Color(0xFF30D158)),
                ),
                StatTile(
                  label: 'FAT', value: '${_totals.fat.round()}g', unit: 'Recommended 65g/day',
                  color: const Color(0xFF5E5CE6), fillFraction: _totals.fat / 65,
                  onTap: () => _openNutrient(context, 'fat', 'Fat', '${_totals.fat.round()}g', 'g', 'Limit: 65g', _totals.fat, 65, const Color(0xFF5E5CE6)),
                ),
                StatTile(
                  label: 'SUGAR', value: '${_totals.sugar.round()}g', unit: 'Limit 50g/day',
                  color: kPink, fillFraction: _totals.sugar / 50,
                  onTap: () => _openNutrient(context, 'sugar', 'Sugar', '${_totals.sugar.round()}g', 'g', 'Limit: 50g', _totals.sugar, 50, kPink),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // VITAMINS & MINERALS
            const SectionHeader(title: 'Vitamins & Minerals'),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: [
                StatTile(
                  label: 'FIBER', value: '${_totals.fiber.round()}g', unit: 'Goal 25g',
                  color: const Color(0xFF30D158), fillFraction: _totals.fiber / 25,
                  onTap: () => _openNutrient(context, 'fiber', 'Fiber', '${_totals.fiber.round()}g', 'g', 'Goal: 25g', _totals.fiber, 25, const Color(0xFF30D158)),
                ),
                StatTile(
                  label: 'SODIUM', value: '${_totals.sodium.round()}mg', unit: 'Limit 2300mg',
                  color: kPink, fillFraction: _totals.sodium / 2300,
                  onTap: () => _openNutrient(context, 'sodium', 'Sodium', '${_totals.sodium.round()}mg', 'mg', 'Limit: 2300mg', _totals.sodium, 2300, kPink),
                ),
                StatTile(
                  label: 'VIT-C', value: '${_totals.vitaminC.round()}mg', unit: 'Goal 90mg',
                  color: kTeal, fillFraction: _totals.vitaminC / 90,
                  onTap: () => _openNutrient(context, 'vitaminC', 'Vitamin C', '${_totals.vitaminC.round()}mg', 'mg', 'Goal: 90mg', _totals.vitaminC, 90, kTeal),
                ),
                StatTile(
                  label: 'VIT-D', value: '${_totals.vitaminD.round()}mcg', unit: 'Goal 20mcg',
                  color: const Color(0xFFFFD60A), fillFraction: _totals.vitaminD / 20,
                  onTap: () => _openNutrient(context, 'vitaminD', 'Vitamin D', '${_totals.vitaminD.round()}mcg', 'mcg', 'Goal: 20mcg', _totals.vitaminD, 20, const Color(0xFFFFD60A)),
                ),
                StatTile(
                  label: 'CALCIUM', value: '${_totals.calcium.round()}mg', unit: 'Goal 1g',
                  color: const Color(0xFFFF9500), fillFraction: _totals.calcium / 1000,
                  onTap: () => _openNutrient(context, 'calcium', 'Calcium', '${_totals.calcium.round()}mg', 'mg', 'Goal: 1000mg', _totals.calcium, 1000, const Color(0xFFFF9500)),
                ),
                StatTile(
                  label: 'IRON', value: '${_totals.iron.round()}mg', unit: 'Goal 18mg',
                  color: const Color(0xFFBE9B7B), fillFraction: _totals.iron / 18,
                  onTap: () => _openNutrient(context, 'iron', 'Iron', '${_totals.iron.round()}mg', 'mg', 'Goal: 18mg', _totals.iron, 18, const Color(0xFFBE9B7B)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Deficiency Hints
            if (_totals.protein < 25 || _totals.vitaminC < 45 || _totals.calcium < 500)
              BentoCard(
                glowColor: const Color(0x33FF9500),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('🔎 MIGHT BE LACKING', style: TextStyle(color: Color(0xFFFF9500), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 10),
                    if (_totals.protein < 25) const _DeficiencyHint(nutrient: 'Protein', tip: 'Try adding chicken, eggs, or legumes.'),
                    if (_totals.vitaminC < 45) const _DeficiencyHint(nutrient: 'Vitamin C', tip: 'Citrus fruits, bell peppers, or broccoli help.'),
                    if (_totals.calcium < 500) const _DeficiencyHint(nutrient: 'Calcium', tip: 'Dairy, fortified plant milks, or leafy greens.'),
                  ],
                ),
              ),

            // API Limit
            const SizedBox(height: 14),
            BentoCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('DAILY AI COMPUTE', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    Text('$_apiCalls / 1500', style: const TextStyle(color: kTeal, fontSize: 11, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 8),
                  Container(
                    height: 6,
                    decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(3)),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: apiPercent,
                      child: Container(decoration: BoxDecoration(color: apiPercent > 0.8 ? kPink : kTeal, borderRadius: BorderRadius.circular(3))),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _DeficiencyHint extends StatelessWidget {
  final String nutrient;
  final String tip;
  const _DeficiencyHint({required this.nutrient, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFFFF9500), fontSize: 14, fontWeight: FontWeight.bold)),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: CupertinoColors.white, fontSize: 13, height: 1.4),
                children: [
                  TextSpan(text: '$nutrient: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: tip, style: const TextStyle(color: CupertinoColors.systemGrey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// HISTORY SCREEN — Day-wise + Editable
// ==========================================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Map<String, List<MealEntry>> _grouped = {};
  List<MealEntry> _allEntries = [];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final historyList = prefs.getStringList('history') ?? [];
    
    final List<MealEntry> entries = [];
    for (var str in historyList) {
      try { entries.add(MealEntry.fromJson(jsonDecode(str))); } catch (_) {}
    }
    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final Map<String, List<MealEntry>> grouped = {};
    for (var e in entries) {
      final k = _formatDate(e.timestamp);
      if (!grouped.containsKey(k)) grouped[k] = [];
      grouped[k]!.add(e);
    }

    setState(() { _grouped = grouped; _allEntries = entries; });
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) return 'Today';
    final y = now.subtract(const Duration(days: 1));
    if (d.year == y.year && d.month == y.month && d.day == y.day) return 'Yesterday';
    const m = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];
    return "${m[d.month - 1]} ${d.day}, ${d.year}";
  }

  Future<void> _deleteEntry(String id) async {
    _allEntries.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('history', _allEntries.map((e) => jsonEncode(e.toJson())).toList());
    loadData();
  }

  Future<void> _editCalories(MealEntry entry) async {
    final ctrl = TextEditingController(text: entry.nutrition.calories.toString());
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Edit Calories'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(ctx)),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('Save'),
            onPressed: () async {
              final newCal = int.tryParse(ctrl.text) ?? entry.nutrition.calories;
              final updated = MealEntry(
                id: entry.id,
                timestamp: entry.timestamp,
                note: entry.note,
                nutrition: NutritionData(
                  calories: newCal,
                  protein: entry.nutrition.protein,
                  carbs: entry.nutrition.carbs,
                  fat: entry.nutrition.fat,
                  sugar: entry.nutrition.sugar,
                  fiber: entry.nutrition.fiber,
                  sodium: entry.nutrition.sodium,
                  vitaminC: entry.nutrition.vitaminC,
                  vitaminD: entry.nutrition.vitaminD,
                  calcium: entry.nutrition.calcium,
                  iron: entry.nutrition.iron,
                  reasoning: entry.nutrition.reasoning,
                  medicalAlert: entry.nutrition.medicalAlert,
                  foodName: entry.nutrition.foodName,
                ),
              );
              final idx = _allEntries.indexWhere((e) => e.id == entry.id);
              if (idx != -1) _allEntries[idx] = updated;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setStringList('history', _allEntries.map((e) => jsonEncode(e.toJson())).toList());
              Navigator.pop(ctx);
              loadData();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = _grouped.keys.toList();

    return CupertinoPageScaffold(
      backgroundColor: kBg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("HISTORY", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: CupertinoColors.white)),
              const SizedBox(height: 16),
              Expanded(
                child: _grouped.isEmpty
                    ? const Center(child: Text("No meals logged yet.", style: TextStyle(color: CupertinoColors.systemGrey)))
                    : ListView.builder(
                        itemCount: keys.length,
                        itemBuilder: (context, si) {
                          final key = keys[si];
                          final dayMeals = _grouped[key]!;
                          final dayTotal = dayMeals.fold(0, (s, e) => s + e.nutrition.calories);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 20, bottom: 10),
                                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text(key.toUpperCase(), style: const TextStyle(color: kTeal, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
                                  Text('$dayTotal kcal total', style: const TextStyle(color: CupertinoColors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                ]),
                              ),
                              ...dayMeals.map((entry) {
                                final time = "${entry.timestamp.hour}:${entry.timestamp.minute.toString().padLeft(2, '0')}";
                                final hasAlert = entry.nutrition.medicalAlert.isNotEmpty;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.of(context, rootNavigator: true).push(
                                        CupertinoPageRoute(builder: (_) => MealDetailScreen(
                                          entry: entry,
                                          onSaved: loadData,
                                        )),
                                      );
                                    },
                                    child: BentoCard(
                                      glowColor: hasAlert ? const Color(0x33FF0055) : const Color(0x00000000),
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text(time, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                                              const SizedBox(height: 4),
                                              Text(entry.nutrition.foodName.isEmpty ? entry.note : entry.nutrition.foodName, style: const TextStyle(color: CupertinoColors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                              const SizedBox(height: 2),
                                              Text('P:${entry.nutrition.protein.round()}g  C:${entry.nutrition.carbs.round()}g  F:${entry.nutrition.fat.round()}g', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                                              if (hasAlert) Padding(padding: const EdgeInsets.only(top: 4), child: Text('⚠️ ${entry.nutrition.medicalAlert}', style: const TextStyle(color: kPink, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                            ]),
                                          ),
                                          const SizedBox(width: 10),
                                          Column(children: [
                                            Text('${entry.nutrition.calories}', style: const TextStyle(color: kNeon, fontSize: 22, fontWeight: FontWeight.w900)),
                                            const Text('kcal', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 10)),
                                            const Text('tap to edit', style: TextStyle(color: Color(0xFF444444), fontSize: 9)),
                                          ]),
                                          const Icon(CupertinoIcons.chevron_right, color: Color(0xFF333333), size: 14),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
