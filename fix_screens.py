import re

with open('lib/screens.dart', 'r') as f:
    content = f.read()

# 1. Add _overrides and _getGoal to state
state_vars = """  NutritionData _totals = NutritionData.zero();
  GoalProfile _goals = GoalProfile(calorieGoal: 2000, proteinGoalG: 50, carbsGoalG: 260, fatGoalG: 65, fiberGoalG: 25, sugarLimitG: 50, sodiumLimitMg: 2300, vitaminCGoalMg: 90, vitaminDGoalMcg: 20, calciumGoalMg: 1000, ironGoalMg: 18, waterGoalMl: 2500, aiRationale: '', computedAt: DateTime.now(), conditionAdjustments: {});
  Map<String, double> _overrides = {};
  final List<MealEntry> _todayMeals = [];
"""
content = re.sub(r'  NutritionData _totals = NutritionData.zero\(\);\n  GoalProfile _goals = [^\n]+\n  final List<MealEntry> _todayMeals = \[\];', state_vars, content)

get_goal_method = """  double _getGoal(String key, double defaultVal) {
    return _overrides[key] ?? defaultVal;
  }

  @override
"""
content = content.replace("  @override\n  void initState() {", get_goal_method + "  void initState() {")


# 2. Update _loadData to populate _overrides
load_overrides = """    final overridesStr = prefs.getString('nutrient_overrides');
    if (overridesStr != null) {
      try {
        final raw = jsonDecode(overridesStr) as Map<String, dynamic>;
        _overrides = raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
        // Apply legacy goals
        if (raw.containsKey('calories')) _goals.calorieGoal = (raw['calories'] as num).toInt();
        if (raw.containsKey('protein')) _goals.proteinGoalG = (raw['protein'] as num).toDouble();
        if (raw.containsKey('carbs')) _goals.carbsGoalG = (raw['carbs'] as num).toDouble();
        if (raw.containsKey('fat')) _goals.fatGoalG = (raw['fat'] as num).toDouble();
        if (raw.containsKey('sugar')) _goals.sugarLimitG = (raw['sugar'] as num).toDouble();
        if (raw.containsKey('fiber')) _goals.fiberGoalG = (raw['fiber'] as num).toDouble();
        if (raw.containsKey('sodium')) _goals.sodiumLimitMg = (raw['sodium'] as num).toDouble();
      } catch (_) {}
    }"""
content = re.sub(r"    final overridesStr = prefs\.getString\('nutrient_overrides'\);\n    if \(overridesStr != null\) \{\n      try \{\n        final overrides = jsonDecode\(overridesStr\) as Map<String, dynamic>;\n        if \(overrides\.containsKey\('calories'\)\)[^\}]+\} catch \(_\) \{\}\n    \}", load_overrides, content)


# 3. Update _openNutrient method
open_nutrient = """  void _openNutrient(BuildContext context, String key, String label, String value, String unit, String goalLabel, double current, double defaultGoal, Color color) {
    final overriddenGoal = _overrides[key] ?? defaultGoal;
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
      if (mounted) _loadData();
    });
  }"""
content = re.sub(r"  void _openNutrient\(BuildContext context, String key, String label, String value, String unit, String goalLabel, double current, double goal, Color color\) \{[^\}]+\}\)\);\n  \}", open_nutrient, content)

# 4. Update the Grid items to use _getGoal for text and fillFraction. 
# Also update Calories donut.
content = content.replace("Goal: ${_goals.calorieGoal}", "Goal: ${_getGoal('calories', _goals.calorieGoal.toDouble()).round()}")
content = content.replace("goal: _goals.calorieGoal", "goal: _getGoal('calories', _goals.calorieGoal.toDouble()).round()")

def replace_stat(key, raw_default, is_limit=False):
    global content
    
    # We must find the StatTile for the key.
    # We'll just do global replacements for the goal values.
    # E.g. _goals.proteinGoalG -> _getGoal('protein', _goals.proteinGoalG)
    pass

# Let's do regex replaces on the StatTile block.
# We'll find all StatTile(...) and replace their `unit:` and `fillFraction:`
# Actually, since we know the exact lines, we can just replace the specific goals with _getGoal calls.
replacements = [
    ('_goals.proteinGoalG', "_getGoal('protein', _goals.proteinGoalG)"),
    ('_goals.carbsGoalG', "_getGoal('carbs', _goals.carbsGoalG)"),
    ('_goals.fatGoalG', "_getGoal('fat', _goals.fatGoalG)"),
    ('_goals.sugarLimitG', "_getGoal('sugar', _goals.sugarLimitG)"),
    ('_goals.fiberGoalG', "_getGoal('fiber', _goals.fiberGoalG)"),
    ('_goals.sodiumLimitMg', "_getGoal('sodium', _goals.sodiumLimitMg)"),
    ('_goals.vitaminDGoalMcg', "_getGoal('vitaminD', _goals.vitaminDGoalMcg)"),
    ('_goals.calciumGoalMg', "_getGoal('calcium', _goals.calciumGoalMg)"),
    ('_goals.ironGoalMg', "_getGoal('iron', _goals.ironGoalMg)"),
    ('_goals.vitaminCGoalMg', "_getGoal('vitaminC', _goals.vitaminCGoalMg)"),
]

for old, new in replacements:
    content = content.replace(old, new)

# And for the hardcoded ones:
content = content.replace("unit: 'Limit: 0g',", "unit: 'Limit: ${_getGoal('transFat', 0.0).round()}g',")
content = content.replace("fillFraction: _totals.transFat > 0 ? 1.0 : 0.0,", "fillFraction: _getGoal('transFat', 0.0) > 0 ? (_totals.transFat / _getGoal('transFat', 0.0)).clamp(0.0, 1.0) : (_totals.transFat > 0 ? 1.0 : 0.0),")
content = content.replace("0, CupertinoColors.destructiveRed", "0.0, CupertinoColors.destructiveRed")

content = content.replace("unit: 'Limit: 300mg',", "unit: 'Limit: ${_getGoal('cholesterol', 300.0).round()}mg',")
content = content.replace("fillFraction: _totals.cholesterol / 300,", "fillFraction: _getGoal('cholesterol', 300.0) > 0 ? _totals.cholesterol / _getGoal('cholesterol', 300.0) : 0,")
content = content.replace("300, CupertinoColors.activeOrange", "300.0, CupertinoColors.activeOrange")

content = content.replace("unit: 'Goal: 150mcg',", "unit: 'Goal: ${_getGoal('iodine', 150.0).round()}mcg',")
content = content.replace("fillFraction: _totals.iodine / 150,", "fillFraction: _getGoal('iodine', 150.0) > 0 ? _totals.iodine / _getGoal('iodine', 150.0) : 0,")
content = content.replace("150, CupertinoColors.systemIndigo", "150.0, CupertinoColors.systemIndigo")

content = content.replace("unit: 'Goal: 3400mg',", "unit: 'Goal: ${_getGoal('potassium', 3400.0).round()}mg',")
content = content.replace("fillFraction: _totals.potassium / 3400,", "fillFraction: _getGoal('potassium', 3400.0) > 0 ? _totals.potassium / _getGoal('potassium', 3400.0) : 0,")
content = content.replace("3400, CupertinoColors.systemYellow", "3400.0, CupertinoColors.systemYellow")

content = content.replace("unit: 'Goal: 400mg',", "unit: 'Goal: ${_getGoal('magnesium', 400.0).round()}mg',")
content = content.replace("fillFraction: _totals.magnesium / 400,", "fillFraction: _getGoal('magnesium', 400.0) > 0 ? _totals.magnesium / _getGoal('magnesium', 400.0) : 0,")
content = content.replace("400, CupertinoColors.activeGreen", "400.0, CupertinoColors.activeGreen")

content = content.replace("unit: 'Goal: 11mg',", "unit: 'Goal: ${_getGoal('zinc', 11.0).round()}mg',")
content = content.replace("fillFraction: _totals.zinc / 11,", "fillFraction: _getGoal('zinc', 11.0) > 0 ? _totals.zinc / _getGoal('zinc', 11.0) : 0,")
content = content.replace("11, CupertinoColors.systemTeal", "11.0, CupertinoColors.systemTeal")

with open('lib/screens.dart', 'w') as f:
    f.write(content)
