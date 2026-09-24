import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Slider, SliderTheme, SliderThemeData, Material, MaterialType;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'models.dart';
import 'widgets.dart';
import 'services/health_service.dart';

// ==========================================
// NUTRIENT DETAIL SCREEN
// ==========================================
class NutrientDetailScreen extends StatefulWidget {
  final String nutrientKey;
  final String label;
  final String value;
  final String unit;
  final String goalLabel;
  final double current;
  final double goal;
  final double aiRecommended;
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
    required this.aiRecommended,
    required this.color,
    required this.todayMeals,
  });

  static const Map<String, Map<String, String>> _info = {
    'calories': {
      'icon': '⚡',
      'why': 'Calories are a measure of energy. They fuel every bodily function from breathing to intense exercise. Matching calorie intake to your goals is essential for weight management.',
      'tip': 'Use the AI to estimate meal calories. A 2000 kcal daily intake is typical for a 70kg adult; adjust based on your activity level and goals.',
      'risk': 'Too few calories cause fatigue, muscle loss, and metabolic slowdown. Too many lead to weight gain and increased disease risk.',
    },
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
      case 'calories': return n.calories.toDouble();
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
  State<NutrientDetailScreen> createState() => _NutrientDetailScreenState();
}

class _NutrientDetailScreenState extends State<NutrientDetailScreen> {
  double _customGoal = 0;
  double _aiRecommended = 0;

  @override
  void initState() {
    super.initState();
    _customGoal = widget.goal;
    _aiRecommended = widget.aiRecommended;
  }

  void _openGoalSlider() {
    showCupertinoModalPopup(
      context: context,
      builder: (_) => _GoalSliderSheet(
        nutrientKey: widget.nutrientKey,
        label: widget.label,
        unit: widget.unit,
        currentGoal: _customGoal,
        aiRecommended: _aiRecommended,
        color: widget.color,
        onSaved: (newGoal) {
          setState(() => _customGoal = newGoal);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = NutrientDetailScreen._info[widget.nutrientKey] ?? {};
    final percent = (widget.current / _customGoal).clamp(0.0, 1.0);
    final isOver = widget.current > _customGoal;
    final progressColor = isOver ? kPink : widget.color;
    final remaining = _customGoal - widget.current;

    return CupertinoPageScaffold(
      backgroundColor: kBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: kBg.withValues(alpha: 0.85),
        border: null,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.chevron_back, color: CupertinoColors.white),
        ),
        middle: Text(widget.label, style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [

            // Hero Card
            BentoCard(
              glowColor: widget.color.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Text(info['icon'] ?? '💊', style: const TextStyle(fontSize: 60)),
                  const SizedBox(height: 16),
                  Text(widget.value, style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: progressColor, letterSpacing: -3, height: 1)),
                  Text(widget.unit, style: TextStyle(color: progressColor, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),

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
                    const Text('0', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                    Text(
                      isOver ? '⚠️ ${(widget.current - _customGoal).round()}${widget.unit} over' : '${remaining.round()}${widget.unit} remaining',
                      style: TextStyle(color: isOver ? kPink : CupertinoColors.systemGrey, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text('Goal: ${_customGoal.round()}${widget.unit}', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                  ]),
                  const SizedBox(height: 20),

                  // Adjust Goal button
                  GestureDetector(
                    onTap: _openGoalSlider,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: widget.color),
                        borderRadius: BorderRadius.circular(20),
                        color: widget.color.withValues(alpha: 0.1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.slider_horizontal_3, color: widget.color, size: 16),
                          const SizedBox(width: 8),
                          Text('Adjust Goal', style: TextStyle(color: widget.color, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Today's breakdown
            if (widget.todayMeals.isNotEmpty) ...[
              const SectionHeader(title: "Today's Breakdown"),
              BentoCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: widget.todayMeals.map((meal) {
                    final mealVal = widget._getMealValue(meal.nutrition);
                    final mealPercent = widget.current > 0 ? (mealVal / widget.current) : 0.0;
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
                              '${mealVal.round()}${widget.unit}',
                              style: TextStyle(color: widget.color, fontSize: 13, fontWeight: FontWeight.w800),
                            ),
                          ]),
                          const SizedBox(height: 6),
                          Container(
                            height: 5,
                            decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(3)),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: mealPercent.clamp(0.0, 1.0),
                              child: Container(decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(3))),
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
// GOAL SLIDER SHEET
// ==========================================
class _GoalSliderSheet extends StatefulWidget {
  final String nutrientKey;
  final String label;
  final String unit;
  final double currentGoal;
  final double aiRecommended;
  final Color color;
  final void Function(double) onSaved;

  const _GoalSliderSheet({
    required this.nutrientKey,
    required this.label,
    required this.unit,
    required this.currentGoal,
    required this.aiRecommended,
    required this.color,
    required this.onSaved,
  });

  @override
  State<_GoalSliderSheet> createState() => _GoalSliderSheetState();
}

class _GoalSliderSheetState extends State<_GoalSliderSheet> {
  late double _sliderValue;
  String _pros = '';
  String _cons = '';
  bool _isLoadingAnalysis = false;
  bool _analysisLoaded = false;

  // Slider range: 50% to 200% of AI recommendation
  double get _min => (widget.aiRecommended * 0.3).roundToDouble();
  double get _max => (widget.aiRecommended * 2.5).roundToDouble();

  double get _deviationPct =>
      ((_sliderValue - widget.aiRecommended) / widget.aiRecommended * 100).abs();

  @override
  void initState() {
    super.initState();
    _sliderValue = widget.currentGoal.clamp(_min, _max);
  }

  Future<void> _fetchAnalysis() async {
    setState(() { _isLoadingAnalysis = true; _analysisLoaded = false; });

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key');
    if (apiKey == null || apiKey.isEmpty) {
      setState(() {
        _pros = 'Set your Gemini API key in Profile to get AI analysis.';
        _cons = '';
        _isLoadingAnalysis = false;
        _analysisLoaded = true;
      });
      return;
    }

    final direction = _sliderValue > widget.aiRecommended ? 'higher' : 'lower';
    final prompt = '''
You are a certified nutritionist. Analyze this goal change:
- Nutrient: ${widget.label}
- AI Recommended: ${widget.aiRecommended.round()}${widget.unit}/day
- User's New Goal: ${_sliderValue.round()}${widget.unit}/day (${_deviationPct.round()}% $direction than recommended)

Respond with ONLY this JSON (no markdown, no extra text):
{
  "pros": "1-2 sentence benefit of this specific amount, if any.",
  "cons": "1-2 sentence risk or downside of this deviation from recommended, be specific and scientific."
}
''';

    try {
      final model = GenerativeModel(model: 'gemini-3.5-flash-lite', apiKey: apiKey);
      final response = await model.generateContent([Content.text(prompt)]);
      final raw = response.text?.trim() ?? '{}';
      String jsonStr = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final firstBrace = jsonStr.indexOf('{');
      final lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1) {
        jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
      }
      final data = jsonDecode(jsonStr);
      if (mounted) {
        setState(() {
          _pros = data['pros'] ?? '';
          _cons = data['cons'] ?? '';
          _isLoadingAnalysis = false;
          _analysisLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pros = 'Could not fetch analysis. Check your API key.';
          _cons = '';
          _isLoadingAnalysis = false;
          _analysisLoaded = true;
        });
      }
    }
  }

  void _confirmSave() {
    final deviating = _deviationPct > 15;

    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: Text(deviating ? '⚠️ Custom Goal Warning' : 'Confirm Goal Change'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Text(
              'New goal: ${_sliderValue.round()}${widget.unit}/day',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              'AI recommended: ${widget.aiRecommended.round()}${widget.unit}/day',
              style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12),
            ),
            if (deviating) ...[
              const SizedBox(height: 10),
              Text(
                'You are deviating ${_deviationPct.round()}% from your AI-personalized recommendation. This may impact your health outcomes.',
                style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 12, height: 1.4),
              ),
            ],
            if (_cons.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Risk: $_cons', style: const TextStyle(fontSize: 12, height: 1.4)),
            ],
          ],
        ),
        actions: [
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
          CupertinoDialogAction(
            isDefaultAction: !deviating,
            isDestructiveAction: deviating,
            child: Text(deviating ? 'Override Anyway' : 'Save Goal'),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              // Save to prefs
              final prefs = await SharedPreferences.getInstance();
              final overrides = jsonDecode(prefs.getString('nutrient_overrides') ?? '{}') as Map<String, dynamic>;
              overrides[widget.nutrientKey] = _sliderValue;
              await prefs.setString('nutrient_overrides', jsonEncode(overrides));
              widget.onSaved(_sliderValue);
              if (mounted) Navigator.pop(context); // Close sheet
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = _deviationPct;
    final isHigh = _sliderValue > widget.aiRecommended;
    final deviationColor = pct < 5
        ? const Color(0xFF30D158)
        : pct < 20
            ? const Color(0xFFFF9500)
            : kPink;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      decoration: const BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(2)),
              ),
            ),

            Text('Adjust ${widget.label} Goal', style: const TextStyle(color: CupertinoColors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('AI recommended: ${widget.aiRecommended.round()}${widget.unit}/day', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 13)),
            const SizedBox(height: 24),

            // Current value display
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _sliderValue.round().toString(),
                    style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: widget.color, height: 1, letterSpacing: -3),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(widget.unit, style: TextStyle(fontSize: 20, color: widget.color, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // Deviation badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: deviationColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  pct < 2 ? 'AI Recommended ✓' : '${pct.round()}% ${isHigh ? "above" : "below"} recommendation',
                  style: TextStyle(color: deviationColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Slider
            Material(
              type: MaterialType.transparency,
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: widget.color,
                  inactiveTrackColor: const Color(0xFF333333),
                  thumbColor: widget.color,
                  overlayColor: widget.color.withValues(alpha: 0.2),
                  trackHeight: 6,
                ),
                child: Slider(
                  value: _sliderValue.clamp(_min, _max),
                  min: _min,
                  max: _max,
                  divisions: ((_max - _min) / (_max > 200 ? 10 : 1)).round(),
                  onChanged: (v) {
                    setState(() {
                      _sliderValue = v;
                      _analysisLoaded = false;
                      _pros = '';
                      _cons = '';
                    });
                  },
                  onChangeEnd: (v) => _fetchAnalysis(),
                ),
              ),
            ),

            // Range labels
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${_min.round()}${widget.unit}', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
              Text('${_max.round()}${widget.unit}', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
            ]),
            const SizedBox(height: 20),

            // AI Analysis panel
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              child: _isLoadingAnalysis
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CupertinoActivityIndicator()),
                    )
                  : _analysisLoaded
                      ? Column(
                          children: [
                            if (_pros.isNotEmpty)
                              BentoCard(
                                glowColor: const Color(0x2200FFD1),
                                padding: const EdgeInsets.all(14),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('✅ ', style: TextStyle(fontSize: 16)),
                                  Expanded(child: Text(_pros, style: const TextStyle(color: CupertinoColors.white, fontSize: 13, height: 1.5))),
                                ]),
                              ),
                            if (_cons.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              BentoCard(
                                glowColor: const Color(0x22FF0055),
                                padding: const EdgeInsets.all(14),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  const Text('⚠️ ', style: TextStyle(fontSize: 16)),
                                  Expanded(child: Text(_cons, style: const TextStyle(color: kPink, fontSize: 13, height: 1.5))),
                                ]),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            'Slide to a value and release to get AI analysis',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFF555555), fontSize: 13),
                          ),
                        ),
            ),

            NeonButton(text: 'Save Goal', onPressed: _confirmSave),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}


// ==========================================
// MEAL DETAIL / EDIT SCREEN
// ==========================================
// ==========================================
// HEALTH DETAIL SCREEN
// ==========================================
class HealthDetailScreen extends StatelessWidget {
  final HealthSnapshot health;
  final String metricKey;
  final String label;
  final Color color;

  const HealthDetailScreen({super.key, required this.health, required this.metricKey, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    String value = '';
    String unit = '';
    double fill = 0.0;

    if (metricKey == 'health_score') {
      value = '${health.healthScore}'; unit = '/ 100'; fill = health.healthScore / 100.0;
    } else if (metricKey == 'active_burn') {
      value = '${health.activeCals.round()}'; unit = 'kcal'; fill = (health.activeCals / 1000).clamp(0.0, 1.0);
    } else if (metricKey == 'resting_burn') {
      value = '${health.basalCals.round()}'; unit = 'kcal'; fill = (health.basalCals / 2500).clamp(0.0, 1.0);
    } else if (metricKey == 'steps') {
      value = '${health.steps}'; unit = 'steps'; fill = (health.steps / 10000).clamp(0.0, 1.0);
    } else if (metricKey == 'sleep') {
      value = health.sleepHours.toStringAsFixed(1); unit = 'hr'; fill = (health.sleepHours / 8.0).clamp(0.0, 1.0);
    } else if (metricKey == 'mindful') {
      value = '${health.mindfulMinutes.round()}'; unit = 'min'; fill = (health.mindfulMinutes / 30.0).clamp(0.0, 1.0);
    } else if (metricKey.startsWith('extended:')) {
      final k = metricKey.split(':').length > 1 ? metricKey.split(':')[1] : metricKey;
      final ext = health.extendedMetrics[k] as Map<String, dynamic>?;
      if (ext != null) {
        value = '${ext['value'] ?? ''}'; 
        unit = ext['unit'] ?? '';
      }
    }

    return CupertinoPageScaffold(
      backgroundColor: kBg,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: kBg.withValues(alpha: 0.85),
        border: null,
        leading: GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(CupertinoIcons.chevron_back, color: CupertinoColors.white)),
        middle: Text(label, style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold)),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            BentoCard(
              glowColor: color.withValues(alpha: 0.25),
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text(value, style: TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: color, height: 1)),
                const SizedBox(height: 6),
                Text(unit, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
                const SizedBox(height: 12),
                Container(
                  height: 10,
                  decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(6)),
                  child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: fill, child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6))))
                ),
              ]),
            ),
            const SizedBox(height: 16),

            // Contextual breakdowns
            if (metricKey == 'active_burn') ...[
              const SectionHeader(title: 'Breakdown'),
              BentoCard(padding: const EdgeInsets.all(12), child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Active', style: const TextStyle(color: CupertinoColors.systemGrey)), 
                  Text('${health.activeCals.round()} kcal', style: TextStyle(color: color, fontWeight: FontWeight.bold))
                ]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Resting', style: const TextStyle(color: CupertinoColors.systemGrey)), 
                  Text('${health.basalCals.round()} kcal${health.basalIsEstimated ? ' (est)' : ''}', style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold))
                ]),
              ])),
              const SizedBox(height: 16),
            ],
            
            if (metricKey == 'resting_burn') ...[
              const SectionHeader(title: 'About Resting Burn'),
              BentoCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  health.basalIsEstimated 
                    ? 'This is an estimated value based on time elapsed today. For accurate tracking, use an Apple Watch or manually enter your BMR in the Health app.'
                    : 'This data comes from Apple Health. Resting burn is the calories your body burns at rest (BMR).',
                  style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 13, height: 1.4),
                ),
              ])),
              const SizedBox(height: 16),
            ],
            
            if (metricKey == 'health_score') ...[
              const SectionHeader(title: 'Score Breakdown'),
              BentoCard(padding: const EdgeInsets.all(12), child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Steps', style: const TextStyle(color: CupertinoColors.systemGrey)), 
                  Text(health.steps > 10000 ? '+30' : health.steps > 5000 ? '+15' : health.steps < 3000 ? '-10' : '0', style: const TextStyle(color: kNeon, fontWeight: FontWeight.bold))
                ]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Sleep', style: const TextStyle(color: CupertinoColors.systemGrey)), 
                  Text(health.sleepHours >= 7 && health.sleepHours <= 9 ? '+20' : health.sleepHours >= 6 ? '+10' : health.sleepHours > 0 && health.sleepHours < 5 ? '-15' : '0', style: const TextStyle(color: Color(0xFF5E5CE6), fontWeight: FontWeight.bold))
                ]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Mindfulness', style: const TextStyle(color: CupertinoColors.systemGrey)), 
                  Text(health.mindfulMinutes > 10 ? '+10' : '0', style: TextStyle(color: kTeal, fontWeight: FontWeight.bold))
                ]),
              ])),
              const SizedBox(height: 16),
            ],
            
            if (metricKey == 'steps') ...[
              const SectionHeader(title: 'Daily Goal'),
              BentoCard(padding: const EdgeInsets.all(12), child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Current', style: const TextStyle(color: CupertinoColors.systemGrey)), 
                  Text('${health.steps}', style: TextStyle(color: color, fontWeight: FontWeight.bold))
                ]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Goal', style: const TextStyle(color: CupertinoColors.systemGrey)), 
                  Text('10,000', style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold))
                ]),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Remaining', style: const TextStyle(color: CupertinoColors.systemGrey)), 
                  Text('${math.max(0, 10000 - health.steps)}', style: const TextStyle(color: CupertinoColors.systemGrey2, fontWeight: FontWeight.bold))
                ]),
              ])),
              const SizedBox(height: 16),
            ],

            // Show list of extended metrics only if they exist
            if (health.extendedMetrics.isNotEmpty) ...[
              const SectionHeader(title: 'More Metrics'),
              BentoCard(padding: const EdgeInsets.all(12), child: Column(children: [
                ...health.extendedMetrics.entries.map((e) {
                  final metricData = e.value as Map<String, dynamic>?;
                  if (metricData == null) return const SizedBox.shrink();
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(e.key, style: const TextStyle(color: CupertinoColors.white, fontSize: 13))),
                      const SizedBox(width: 8),
                      Text('${metricData['value'] ?? ''} ${metricData['unit'] ?? ''}', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 13)),
                    ]),
                  );
                }),
              ])),
            ],
          ],
        ),
      ),
    );
  }
}

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
          backgroundColor: kBg.withValues(alpha: 0.85),
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
              Text('$dateStr at $time', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
              const SizedBox(height: 4),
              if (n.medicalAlert.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A0A0A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kPink.withValues(alpha: 0.5)),
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
