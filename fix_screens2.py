import re

with open('lib/screens.dart', 'r') as f:
    content = f.read()

# Fix the left-hand side assignments
content = content.replace("_getGoal('calories', _goals.calorieGoal.toDouble()).round() = (raw['calories'] as num).toInt();", "_goals.calorieGoal = (raw['calories'] as num).toInt();")
content = content.replace("_getGoal('calories', _goals.calorieGoal) = (raw['calories'] as num).toInt();", "_goals.calorieGoal = (raw['calories'] as num).toInt();")
content = content.replace("_getGoal('protein', _goals.proteinGoalG) = (raw['protein'] as num).toDouble();", "_goals.proteinGoalG = (raw['protein'] as num).toDouble();")
content = content.replace("_getGoal('carbs', _goals.carbsGoalG) = (raw['carbs'] as num).toDouble();", "_goals.carbsGoalG = (raw['carbs'] as num).toDouble();")
content = content.replace("_getGoal('fat', _goals.fatGoalG) = (raw['fat'] as num).toDouble();", "_goals.fatGoalG = (raw['fat'] as num).toDouble();")
content = content.replace("_getGoal('sugar', _goals.sugarLimitG) = (raw['sugar'] as num).toDouble();", "_goals.sugarLimitG = (raw['sugar'] as num).toDouble();")
content = content.replace("_getGoal('fiber', _goals.fiberGoalG) = (raw['fiber'] as num).toDouble();", "_goals.fiberGoalG = (raw['fiber'] as num).toDouble();")
content = content.replace("_getGoal('sodium', _goals.sodiumLimitMg) = (raw['sodium'] as num).toDouble();", "_goals.sodiumLimitMg = (raw['sodium'] as num).toDouble();")

# Also find where NutrientDetailScreen is invoked without aiRecommended
content = re.sub(r'(builder: \(_\) => NutrientDetailScreen\([\s\S]*?goal: [^,]+,)(\s+color:)', r'\1\n        aiRecommended: 0, # TO BE FIXED \2', content)

with open('lib/screens.dart', 'w') as f:
    f.write(content)
