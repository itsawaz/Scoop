/// Model selection service for optimal API usage
/// Selects the best Gemini model based on task complexity and rate limits
class ModelSelector {
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
      case 'meal_analysis':
        // Flash-Lite handles nutrition analysis well with high quota
        return 'gemini-2.5-flash-lite';
      
      case 'supplement_lookup':
        // Simple structured data extraction
        return 'gemini-2.5-flash-lite';
      
      case 'coach_chat':
        // Complex reasoning and empathetic dialogue, use Gemma 4
        return 'gemma-4-31b-it';
      
      case 'goal_calculation':
        // Complex medical reasoning, use Gemma 4
        return 'gemma-4-31b-it';
      
      case 'nutrient_analysis':
        // Medium complexity, Flash-Lite is fine
        return 'gemini-2.5-flash-lite';
      
      case 'fasting_guidance':
        // Simple advice, Flash-Lite works well
        return 'gemini-2.5-flash-lite';
      
      default:
        return 'gemini-2.5-flash-lite';
    }
  }

  /// Get rate limits for a specific model
  /// Returns map with rpm (requests per minute), rpd (requests per day), tpm (tokens per minute)
  static Map<String, int> getModelLimits(String model) {
    switch (model) {
      case 'gemini-2.5-flash-lite':
        return {'rpm': 15, 'rpd': 1000, 'tpm': 250000};
      case 'gemini-2.5-flash':
        return {'rpm': 10, 'rpd': 250, 'tpm': 250000};
      case 'gemini-2.5-pro':
        return {'rpm': 5, 'rpd': 100, 'tpm': 250000};
      case 'gemma-4-31b-it':
        return {'rpm': 15, 'rpd': 1500, 'tpm': -1}; // Unlimited TPM
      default:
        return {'rpm': 5, 'rpd': 20, 'tpm': 250000};
    }
  }

  /// Get fallback model if primary is exhausted
  static String getFallbackModel(String primary) {
    // If Flash-Lite is exhausted, try Gemma 4
    if (primary == 'gemini-2.5-flash-lite') return 'gemma-4-31b-it';
    // If Gemma 4 is exhausted, try Flash-Lite
    if (primary == 'gemma-4-31b-it') return 'gemini-2.5-flash-lite';
    // Default fallback
    return 'gemini-2.5-flash-lite';
  }

  /// Get user-friendly model name
  static String getModelDisplayName(String model) {
    switch (model) {
      case 'gemini-2.5-flash-lite':
        return 'Gemini Flash-Lite (Fast)';
      case 'gemini-2.5-flash':
        return 'Gemini Flash (Balanced)';
      case 'gemini-2.5-pro':
        return 'Gemini Pro (Advanced)';
      case 'gemma-4-31b-it':
        return 'Gemma 4 (Conversational)';
      default:
        return model;
    }
  }
}
