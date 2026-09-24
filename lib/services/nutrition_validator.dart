import '../models.dart';

/// Sanity-checks AI-generated nutrition so obviously wrong values (a banana at
/// 4000 kcal, macros that don't add up) don't silently corrupt the user's log.
class NutritionValidation {
  /// The (possibly corrected) data to use.
  final NutritionData data;

  /// Human-readable warnings to surface to the user, if any.
  final List<String> warnings;

  /// True if the calories are inconsistent with the macros (Atwater check).
  final bool caloriesInconsistent;

  const NutritionValidation({
    required this.data,
    required this.warnings,
    required this.caloriesInconsistent,
  });

  bool get hasWarnings => warnings.isNotEmpty;
}

class NutritionValidator {
  // Plausible per-serving upper bounds. Beyond these we clamp and warn.
  static const int _maxCalories = 5000;
  static const double _maxMacroGrams = 1000; // protein/carbs/fat grams
  static const double _atwaterTolerance = 0.25; // 25%

  /// Estimated calories from macros using Atwater factors (4/4/9 kcal per g).
  static double atwaterCalories(NutritionData n) =>
      4 * n.protein + 4 * n.carbs + 9 * n.fat;

  static NutritionValidation validate(NutritionData n) {
    final warnings = <String>[];

    // Clamp implausible values instead of trusting the model blindly.
    var calories = n.calories;
    if (calories < 0) {
      calories = 0;
      warnings.add('Calories were negative; reset to 0.');
    } else if (calories > _maxCalories) {
      warnings.add('Calories ($calories kcal) look unusually high for one serving.');
      calories = _maxCalories;
    }

    double clampMacro(double v, String label) {
      if (v < 0) {
        warnings.add('$label was negative; reset to 0.');
        return 0;
      }
      if (v > _maxMacroGrams) {
        warnings.add('$label ($v g) looks unusually high; capped.');
        return _maxMacroGrams;
      }
      return v;
    }

    final protein = clampMacro(n.protein, 'Protein');
    final carbs = clampMacro(n.carbs, 'Carbs');
    final fat = clampMacro(n.fat, 'Fat');

    // Atwater consistency: do the macros roughly account for the calories?
    final estimated = 4 * protein + 4 * carbs + 9 * fat;
    var inconsistent = false;
    if (calories > 0 && estimated > 0) {
      final diff = (estimated - calories).abs() / calories;
      if (diff > _atwaterTolerance) {
        inconsistent = true;
        warnings.add(
          'Calories and macros don\'t quite add up '
          '(macros suggest ~${estimated.round()} kcal). Treat as an estimate.',
        );
      }
    }

    final corrected = _copyWith(n, calories: calories, protein: protein, carbs: carbs, fat: fat);

    return NutritionValidation(
      data: corrected,
      warnings: warnings,
      caloriesInconsistent: inconsistent,
    );
  }

  static NutritionData _copyWith(
    NutritionData n, {
    required int calories,
    required double protein,
    required double carbs,
    required double fat,
  }) {
    return NutritionData(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      sugar: n.sugar,
      fiber: n.fiber,
      sodium: n.sodium,
      vitaminC: n.vitaminC,
      vitaminD: n.vitaminD,
      calcium: n.calcium,
      iron: n.iron,
      saturatedFat: n.saturatedFat,
      transFat: n.transFat,
      cholesterol: n.cholesterol,
      potassium: n.potassium,
      magnesium: n.magnesium,
      zinc: n.zinc,
      vitaminA: n.vitaminA,
      vitaminB6: n.vitaminB6,
      vitaminB12: n.vitaminB12,
      folate: n.folate,
      phosphorus: n.phosphorus,
      iodine: n.iodine,
      reasoning: n.reasoning,
      medicalAlert: n.medicalAlert,
      foodName: n.foodName,
    );
  }
}
