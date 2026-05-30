import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

class GoalEngine {
  static Future<GoalProfile> computeGoals(BiometricProfile bio, String conditions, String goals) async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key') ?? '';
    
    if (apiKey.isEmpty) {
      throw Exception('API Key is missing');
    }

    final model = GenerativeModel(model: 'gemma-4-31b-it', apiKey: apiKey);

    final prompt = """
You are a certified sports dietitian and medical nutritionist. A user has provided their health data below.
Compute precise, evidence-based nutritional goals for this person.

USER DATA:
- Age: ${bio.age} years
- Gender: ${bio.gender}
- Height: ${bio.heightCm} cm
- Current Weight: ${bio.weightKg} kg
- Goal Weight: ${bio.goalWeightKg} kg
- Activity Level: ${bio.activityLevel}
- Estimated TDEE: ${bio.tdee.toStringAsFixed(0)} kcal/day
- Medical Conditions: $conditions
- Fitness Goals: $goals

INSTRUCTIONS:
1. Calculate a safe calorie DEFICIT target for their weight goal (never below 1200 for females, 1500 for males, and max 750 kcal deficit from TDEE).
2. Set protein goal based on lean body mass and goal (weight loss = 2.2g/kg; muscle gain = 2.4-2.8g/kg; maintenance = 1.6g/kg). Use current weight for calculations unless obese.
3. Set carbs, fats from remaining calories using evidence-based splits, adjusted for conditions.
4. Adjust each nutrient for medical conditions:
   - Hypertension: sodium <= 1500mg/day
   - Type 2 Diabetes: sugar <= 25g/day, high fiber >= 35g/day
   - High Cholesterol: saturated fat guidance
   - Celiac Disease: note on gluten
   - Lactose Intolerance: calcium from non-dairy sources note
5. Set micronutrient goals based on age and gender (use NIH DRIs).
6. Set water goal (bodyweight_kg * 35 ml, adjusted for activity).

Return ONLY this exact JSON (no markdown, no backticks, no extra text):
{
  "calorieGoal": 1850,
  "proteinGoalG": 176.0,
  "carbsGoalG": 185.0,
  "fatGoalG": 62.0,
  "fiberGoalG": 35.0,
  "sugarLimitG": 50.0,
  "sodiumLimitMg": 2300.0,
  "vitaminCGoalMg": 90.0,
  "vitaminDGoalMcg": 20.0,
  "calciumGoalMg": 1000.0,
  "ironGoalMg": 18.0,
  "waterGoalMl": 3500.0,
  "aiRationale": "Detailed explanation: For a 110kg male at 6'10 with a weight loss goal...",
  "conditionAdjustments": {
    "sodium": "Reduced to 1500mg/day due to Hypertension — excess sodium raises blood pressure further"
  }
}
""";

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final raw = response.text?.trim() ?? '{}';
      
      // Robust JSON extraction
      String jsonStr = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final firstBrace = jsonStr.indexOf('{');
      final lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1) {
        jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
      }

      final Map<String, dynamic> data = jsonDecode(jsonStr);
      // Ensure we add computedAt
      data['computedAt'] = DateTime.now().toIso8601String();
      
      final goalProfile = GoalProfile.fromJson(data);
      
      // Save it automatically
      await prefs.setString('goals_json', jsonEncode(goalProfile.toJson()));
      await prefs.setString('goals_computed_at', goalProfile.computedAt.toIso8601String());
      
      return goalProfile;
    } catch (e) {
      throw Exception('Failed to generate goals: \$e');
    }
  }

  static Future<GoalProfile?> getStoredGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('goals_json');
    if (jsonStr != null) {
      try {
        return GoalProfile.fromJson(jsonDecode(jsonStr));
      } catch (_) {}
    }
    return null;
  }
}
