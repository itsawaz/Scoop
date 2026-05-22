import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'widgets.dart';

// ==========================================
// NUTRIENT DETAIL SCREEN
// ==========================================
class NutrientDetailScreen extends StatelessWidget {
  final String nutrientKey; // 'protein', 'carbs', 'fat', 'sugar', 'fiber', 'sodium', 'vitaminC', 'vitaminD', 'calcium', 'iron'
  final String label;
  final String value;
  final String unit;
  final String goalLabel;
  final double current;
  final double goal;
  final Color color;
  final List<MealEntry> todayMeals;

  const NutrientDetailScreen({
    super.key,
    required this.nutrientKey,
    required this.label,
    required this.value,
    required this.unit,
    required this.goalLabel,
    required this.current,
    required this.goal,
    required this.color,
    required this.todayMeals,
  });

  static const Map<String, Map<String, String>> _info = {
    'protein': {
      'icon': '🥩',
      'why': 'Protein builds and repairs muscles, tissues, and organs. It also produces enzymes, hormones, and antibodies.',
      'tip': 'Aim for 0.8–1.2g per kg of body weight. Great sources: chicken, eggs, Greek yogurt, lentils.',
      'risk': 'Low protein leads to muscle loss, fatigue, and weakened immunity.',
    },
    'carbs': {
      'icon': '🍚',
      'why': 'Carbohydrates are your body\'s primary energy source — especially for the brain and muscles during exercise.',
      'tip': 'Choose complex carbs (oats, brown rice, vegetables) over simple sugars for sustained energy.',
      'risk': 'Too many refined carbs spike blood sugar and can increase fat storage.',
    },
    'fat': {
      'icon': '🥑',
      'why': 'Healthy fats are essential for hormone production, vitamin absorption (A, D, E, K), and brain health.',
      'tip': 'Focus on unsaturated fats from avocado, nuts, olive oil. Limit saturated and avoid trans fats.',
      'risk': 'Excessive saturated fat raises LDL cholesterol and cardiovascular risk.',
    },
    'sugar': {
      'icon': '🍬',
      'why': 'Natural sugars in fruit and dairy are fine. Added sugars provide empty calories with no nutritional value.',
      'tip': 'WHO recommends keeping added sugar under 25g/day. Read labels — it hides as corn syrup, dextrose, etc.',
      'risk': 'High sugar intake is linked to obesity, Type 2 Diabetes, and dental decay.',
    },
    'fiber': {
      'icon': '🥦',
      'why': 'Fiber supports digestive health, feeds good gut bacteria, regulates blood sugar, and lowers cholesterol.',
      'tip': 'Eat whole grains, legumes, fruits with skin, and vegetables. Increase intake gradually with water.',
      'risk': 'Low fiber is linked to constipation, poor gut health, and elevated colon cancer risk.',
    },
    'sodium': {
      'icon': '🧂',
      'why': 'Sodium regulates fluid balance and nerve function. However, most people consume far more than needed.',
      'tip': 'Cook at home, avoid processed foods, and use herbs instead of salt. Choose low-sodium options.',
      'risk': 'Excess sodium raises blood pressure, increasing risk of stroke and heart disease.',
    },
    'vitaminC': {
      'icon': '🍊',
      'why': 'Vitamin C is a powerful antioxidant that supports immune function, collagen synthesis, and iron absorption.',
      'tip': 'Get it from citrus fruits, bell peppers, strawberries, broccoli. Heat destroys it — eat some raw.',
      'risk': 'Deficiency causes scurvy, poor wound healing, and increased infection susceptibility.',
    },
    'vitaminD': {
      'icon': '☀️',
      'why': 'Vitamin D regulates calcium absorption for strong bones and teeth, and supports immune and muscle function.',
      'tip': 'Get 15–30 mins of sunlight daily. Food sources: fatty fish, egg yolks, fortified dairy.',
      'risk': 'Deficiency is extremely common and linked to bone loss, depression, and immune weakness.',
    },
    'calcium': {
      'icon': '🦴',
      'why': 'Calcium is the main mineral in bones and teeth. It also supports muscle contraction and nerve signals.',
      'tip': 'Dairy, fortified plant milk, tofu, leafy greens, and almonds are great sources.',
      'risk': 'Long-term deficiency leads to osteoporosis and increased fracture risk.',
    },
    'iron': {
      'icon': '🩸',
      'why': 'Iron is essential for making haemoglobin, which carries oxygen in your blood to every cell in your body.',
      'tip': 'Eat red meat, legumes, spinach, and fortified cereals. Pair plant iron with vitamin C to boost absorption.',
      'risk': 'Iron deficiency is the #1 nutritional deficiency worldwide, causing anaemia and fatigue.',
    },
  };

  double _getMealValue(NutritionData n) {
    switch (nutrientKey) {
      case 'protein': return n.protein;
      case 'carbs': return n.carbs;
      case 'fat': return n.fat;
      case 'sugar': return n.sugar;
      case 'fiber': return n.fiber;
      case 'sodium': return n.sodium;
      case 'vitaminC': return n.vitaminC;
      case 'vitaminD': return n.vitaminD;
      case 'calcium': return n.calcium;
      case 'iron': return n.iron;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info[nutrientKey] ?? {};
    final percent = (current / goal).clamp(0.0, 1.0);
    final isOver = current > goal;
    final progressColor = isOver ? kPink : color;
    final remaining = goal - current;

    return CupertinoPageScaffold(
      backgroundColor: kBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: kBg.withOpacity(0.85),
        border: null,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.chevron_back, color: CupertinoColors.white),
        ),
        middle: Text(label, style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // Hero Card
            BentoCard(
              glowColor: color.withOpacity(0.3),
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Text(info['icon'] ?? '💊', style: const TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  Text(value, style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: progressColor, letterSpacing: -3, height: 1)),
                  Text(unit, style: TextStyle(color: progressColor, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),

                  // Progress bar
                  Container(
                    height: 12,
                    decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(6)),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: percent,
                      child: Container(decoration: BoxDecoration(color: progressColor, borderRadius: BorderRadius.circular(6))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('0', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                    Text(
                      isOver ? '⚠️ ${(current - goal).round()}$unit over limit' : '${remaining.round()}$unit remaining',
                      style: TextStyle(color: isOver ? kPink : CupertinoColors.systemGrey, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(goalLabel, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Today's meal breakdown
            if (todayMeals.isNotEmpty) ...[
              const SectionHeader(title: "Today's Breakdown"),
              BentoCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: todayMeals.map((meal) {
                    final mealVal = _getMealValue(meal.nutrition);
                    final mealPercent = current > 0 ? (mealVal / current) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(
                                meal.nutrition.foodName.isEmpty ? meal.note : meal.nutrition.foodName,
                                style: const TextStyle(color: CupertinoColors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${mealVal.round()}$unit',
                              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          Container(
                            height: 5,
                            decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(3)),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: mealPercent.clamp(0.0, 1.0),
                              child: Container(decoration: BoxDecoration(color: color.withOpacity(0.7), borderRadius: BorderRadius.circular(3))),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Why it matters
            if (info.containsKey('why')) ...[
              const SectionHeader(title: 'Why It Matters'),
              BentoCard(
                padding: const EdgeInsets.all(16),
                child: Text(info['why']!, style: const TextStyle(color: CupertinoColors.white, fontSize: 14, height: 1.6)),
              ),
              const SizedBox(height: 14),
              BentoCard(
                glowColor: const Color(0x2200FFD1),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('💡 TIP', style: TextStyle(color: kTeal, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(info['tip']!, style: const TextStyle(color: CupertinoColors.white, fontSize: 14, height: 1.6)),
                ]),
              ),
              const SizedBox(height: 14),
              BentoCard(
                glowColor: const Color(0x22FF0055),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('⚠️ RISK IF LOW/HIGH', style: TextStyle(color: kPink, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Text(info['risk']!, style: const TextStyle(color: CupertinoColors.white, fontSize: 14, height: 1.6)),
                ]),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MEAL DETAIL / EDIT SCREEN
// ==========================================
class MealDetailScreen extends StatefulWidget {
  final MealEntry entry;
  final VoidCallback onSaved;

  const MealDetailScreen({super.key, required this.entry, required this.onSaved});

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  late final TextEditingController _foodName;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late final TextEditingController _sugar;
  late final TextEditingController _fiber;
  late final TextEditingController _sodium;
  late final TextEditingController _vitaminC;
  late final TextEditingController _vitaminD;
  late final TextEditingController _calcium;
  late final TextEditingController _iron;
  late final TextEditingController _reasoning;

  @override
  void initState() {
    super.initState();
    final n = widget.entry.nutrition;
    _foodName  = TextEditingController(text: n.foodName);
    _calories  = TextEditingController(text: n.calories.toString());
    _protein   = TextEditingController(text: n.protein.toStringAsFixed(1));
    _carbs     = TextEditingController(text: n.carbs.toStringAsFixed(1));
    _fat       = TextEditingController(text: n.fat.toStringAsFixed(1));
    _sugar     = TextEditingController(text: n.sugar.toStringAsFixed(1));
    _fiber     = TextEditingController(text: n.fiber.toStringAsFixed(1));
    _sodium    = TextEditingController(text: n.sodium.toStringAsFixed(1));
    _vitaminC  = TextEditingController(text: n.vitaminC.toStringAsFixed(1));
    _vitaminD  = TextEditingController(text: n.vitaminD.toStringAsFixed(1));
    _calcium   = TextEditingController(text: n.calcium.toStringAsFixed(1));
    _iron      = TextEditingController(text: n.iron.toStringAsFixed(1));
    _reasoning = TextEditingController(text: n.reasoning);
  }

  @override
  void dispose() {
    for (final c in [_foodName,_calories,_protein,_carbs,_fat,_sugar,_fiber,_sodium,_vitaminC,_vitaminD,_calcium,_iron,_reasoning]) {
      c.dispose();
    }
    super.dispose();
  }

  double _d(TextEditingController c) => double.tryParse(c.text) ?? 0.0;
  int _i(TextEditingController c) => int.tryParse(c.text) ?? 0;

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final prefs = await SharedPreferences.getInstance();
    final historyList = prefs.getStringList('history') ?? [];

    final updated = MealEntry(
      id: widget.entry.id,
      timestamp: widget.entry.timestamp,
      note: _foodName.text,
      nutrition: NutritionData(
        foodName: _foodName.text,
        calories: _i(_calories),
        protein: _d(_protein),
        carbs: _d(_carbs),
        fat: _d(_fat),
        sugar: _d(_sugar),
        fiber: _d(_fiber),
        sodium: _d(_sodium),
        vitaminC: _d(_vitaminC),
        vitaminD: _d(_vitaminD),
        calcium: _d(_calcium),
        iron: _d(_iron),
        reasoning: _reasoning.text,
        medicalAlert: widget.entry.nutrition.medicalAlert,
      ),
    );

    final newList = historyList.map((str) {
      try {
        final e = MealEntry.fromJson(jsonDecode(str));
        return e.id == widget.entry.id ? jsonEncode(updated.toJson()) : str;
      } catch (_) { return str; }
    }).toList();

    await prefs.setStringList('history', newList);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete Meal?'),
        content: const Text('This cannot be undone.'),
        actions: [
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Delete'),
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              final historyList = prefs.getStringList('history') ?? [];
              historyList.removeWhere((str) {
                try { return MealEntry.fromJson(jsonDecode(str)).id == widget.entry.id; } catch (_) { return false; }
              });
              await prefs.setStringList('history', historyList);
              widget.onSaved();
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool multiline = false, TextInputType keyboard = TextInputType.number}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder),
            ),
            child: CupertinoTextField(
              controller: ctrl,
              keyboardType: multiline ? TextInputType.multiline : keyboard,
              maxLines: multiline ? 4 : 1,
              textInputAction: multiline ? TextInputAction.newline : TextInputAction.next,
              style: const TextStyle(color: CupertinoColors.white, fontSize: 15),
              decoration: const BoxDecoration(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.entry.nutrition;
    final time = "${widget.entry.timestamp.hour}:${widget.entry.timestamp.minute.toString().padLeft(2, '0')}";
    final dateStr = "${widget.entry.timestamp.day}/${widget.entry.timestamp.month}/${widget.entry.timestamp.year}";

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CupertinoPageScaffold(
        backgroundColor: kBg,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: kBg.withOpacity(0.85),
          border: null,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(CupertinoIcons.chevron_back, color: CupertinoColors.white),
          ),
          middle: const Text('Edit Meal', style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold)),
          trailing: GestureDetector(
            onTap: _delete,
            child: const Icon(CupertinoIcons.trash, color: CupertinoColors.destructiveRed, size: 20),
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header
              Text('$dateStr at $time', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
              const SizedBox(height: 4),
              if (n.medicalAlert.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A0A0A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kPink.withOpacity(0.5)),
                  ),
                  child: Row(children: [
                    const Text('⚠️ ', style: TextStyle(fontSize: 18)),
                    Expanded(child: Text(n.medicalAlert, style: const TextStyle(color: kPink, fontSize: 12))),
                  ]),
                ),

              const SectionHeader(title: 'Food Info'),
              _field('FOOD NAME', _foodName, keyboard: TextInputType.text),

              const SectionHeader(title: 'Calories'),
              _field('CALORIES (kcal)', _calories),

              const SectionHeader(title: 'Macronutrients'),
              _field('PROTEIN (g)', _protein),
              _field('CARBOHYDRATES (g)', _carbs),
              _field('FAT (g)', _fat),
              _field('SUGAR (g)', _sugar),
              _field('FIBER (g)', _fiber),

              const SectionHeader(title: 'Minerals & Vitamins'),
              _field('SODIUM (mg)', _sodium),
              _field('VITAMIN C (mg)', _vitaminC),
              _field('VITAMIN D (mcg)', _vitaminD),
              _field('CALCIUM (mg)', _calcium),
              _field('IRON (mg)', _iron),

              const SectionHeader(title: 'AI Reasoning'),
              _field('REASONING', _reasoning, multiline: true, keyboard: TextInputType.text),

              const SizedBox(height: 24),
              NeonButton(text: 'Save Changes ✓', onPressed: _save),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
