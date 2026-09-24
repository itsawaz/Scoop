/// Model selection service for optimal API usage
/// Selects the best Gemini model based on task complexity and rate limits.
///
/// NOTE: The Gemini 2.5 family is being retired (shutdown Oct 2026), so the app
/// targets the current Gemini 3.5 family. `gemini-3.5-flash-lite` is the fast,
/// cost-efficient, high-throughput default; `gemini-3.5-flash` is the fallback.
class ModelSelector {
  /// The primary model used across the app for almost everything.
  static const String primaryModel = 'gemini-3.5-flash-lite';

  /// A slightly more capable model used as a fallback.
  static const String balancedModel = 'gemini-3.5-flash';

  /// Select optimal model for a given task type
  ///
  /// Task types:
  /// - meal_analysis: Nutrition analysis from image/text
  /// - supplement_lookup: Supplement information extraction
  /// - coach_chat: Conversational AI coaching
  /// - goal_calculation: Complex medical/nutritional reasoning
  /// - nutrient_analysis: Nutrient goal analysis
  /// - fasting_guidance: Fasting advice
  static String selectModelForTask(String taskType, {bool hasImage = false}) {
    switch (taskType) {
      case 'coach_chat':
      case 'goal_calculation':
        // Slightly more reasoning-heavy tasks use the balanced model.
        return balancedModel;
      case 'meal_analysis':
      case 'supplement_lookup':
      case 'nutrient_analysis':
      case 'fasting_guidance':
      default:
        return primaryModel;
    }
  }

  /// Get rate limits for a specific model
  /// Returns map with rpm (requests per minute), rpd (requests per day), tpm (tokens per minute)
  static Map<String, int> getModelLimits(String model) {
    switch (model) {
      case 'gemini-3.5-flash-lite':
        return {'rpm': 15, 'rpd': 1000, 'tpm': 250000};
      case 'gemini-3.5-flash':
        return {'rpm': 10, 'rpd': 250, 'tpm': 250000};
      default:
        // Conservative defaults for any other/unknown model.
        return {'rpm': 10, 'rpd': 250, 'tpm': 250000};
    }
  }

  /// Get fallback model if primary is exhausted
  static String getFallbackModel(String primary) {
    // If Flash-Lite is exhausted, try the standard Flash tier.
    if (primary == primaryModel) return balancedModel;
    // If Flash is exhausted, drop back to Flash-Lite.
    if (primary == balancedModel) return primaryModel;
    // Default fallback.
    return primaryModel;
  }

  /// Get user-friendly model name
  static String getModelDisplayName(String model) {
    switch (model) {
      case 'gemini-3.5-flash-lite':
        return 'Gemini Flash-Lite (Fast)';
      case 'gemini-3.5-flash':
        return 'Gemini Flash (Balanced)';
      default:
        return model;
    }
  }
}
