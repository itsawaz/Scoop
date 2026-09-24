import 'package:google_generative_ai/google_generative_ai.dart';
import 'api_key_manager.dart';
import 'api_rate_limiter.dart';
import 'model_selector.dart';

/// Unified API service that handles model selection, key rotation, and rate limiting
/// 
/// Usage:
/// ```dart
/// final apiService = ApiService();
/// final model = await apiService.getModel('meal_analysis', hasImage: true);
/// final response = await model.generateContent([...]);
/// await apiService.recordUsage();
/// ```
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _lastUsedApiKey;

  /// Get a GenerativeModel instance for a specific task
  /// 
  /// Parameters:
  /// - taskType: Type of task (meal_analysis, coach_chat, etc.)
  /// - hasImage: Whether the request includes an image
  /// - forceModel: Optional model name to override automatic selection
  /// 
  /// Throws exception if no API keys are available or all are exhausted
  Future<GenerativeModel> getModel(
    String taskType, {
    bool hasImage = false,
    String? forceModel,
  }) async {
    // Initialize key manager if needed
    final keyManager = ApiKeyManager();
    if (keyManager.getKeyCount() == 0) {
      await keyManager.loadApiKeys();
    }

    // Select optimal model for task
    final modelName = forceModel ?? ModelSelector.selectModelForTask(taskType, hasImage: hasImage);

    // Get available API key (with rate limit checking)
    try {
      final apiKey = await keyManager.getAvailableApiKey(modelName: modelName);
      _lastUsedApiKey = apiKey;

      // Check rate limits
      final limiter = ApiRateLimiter();
      if (!await limiter.canMakeRequest(model: modelName, keyOverride: apiKey)) {
        // Try fallback model
        final fallbackModel = ModelSelector.getFallbackModel(modelName);
        final fallbackKey = await keyManager.getAvailableApiKey(modelName: fallbackModel);
        
        if (await limiter.canMakeRequest(model: fallbackModel, keyOverride: fallbackKey)) {
          _lastUsedApiKey = fallbackKey;
          return GenerativeModel(model: fallbackModel, apiKey: fallbackKey);
        }
        
        throw Exception(limiter.getErrorMessage(model: modelName));
      }

      return GenerativeModel(model: modelName, apiKey: apiKey);
    } catch (e) {
      // If all keys exhausted, provide helpful error
      if (e.toString().contains('daily limit')) {
        rethrow;
      }
      throw Exception('Failed to get API model: $e');
    }
  }

  /// Record that an API call was made (call this after successful API request)
  Future<void> recordUsage() async {
    if (_lastUsedApiKey == null) return;

    final keyManager = ApiKeyManager();
    await keyManager.recordKeyUsage(_lastUsedApiKey!);

    final limiter = ApiRateLimiter();
    await limiter.recordRequest(apiKey: _lastUsedApiKey);
  }

  /// Get usage statistics
  Future<Map<String, dynamic>> getUsageStats() async {
    final keyManager = ApiKeyManager();
    await keyManager.loadApiKeys();

    final stats = await keyManager.getUsageStats();
    final totalLimit = await keyManager.getTotalDailyLimit(modelName: 'gemini-3.5-flash-lite');
    final remaining = await keyManager.getRemainingRequests(modelName: 'gemini-3.5-flash-lite');

    return {
      'keyStats': stats,
      'totalLimit': totalLimit,
      'remaining': remaining,
      'keyCount': keyManager.getKeyCount(),
      'hasMultipleKeys': keyManager.hasMultipleKeys(),
    };
  }

  /// Get remaining requests for display
  Future<int> getRemainingRequests({String? model}) async {
    final keyManager = ApiKeyManager();
    await keyManager.loadApiKeys();
    return await keyManager.getRemainingRequests(modelName: model);
  }

  /// Check if API is available (has keys and capacity)
  Future<bool> isAvailable() async {
    try {
      final keyManager = ApiKeyManager();
      await keyManager.loadApiKeys();
      
      if (keyManager.getKeyCount() == 0) return false;
      
      final remaining = await keyManager.getRemainingRequests();
      return remaining > 0;
    } catch (e) {
      return false;
    }
  }

  /// Get user-friendly status message
  Future<String> getStatusMessage() async {
    final keyManager = ApiKeyManager();
    await keyManager.loadApiKeys();

    if (keyManager.getKeyCount() == 0) {
      return 'No API key configured. Add one in Profile settings.';
    }

    final remaining = await keyManager.getRemainingRequests(modelName: 'gemini-3.5-flash-lite');
    final totalLimit = await keyManager.getTotalDailyLimit(modelName: 'gemini-3.5-flash-lite');
    final keyCount = keyManager.getKeyCount();

    if (remaining == 0) {
      final limiter = ApiRateLimiter();
      final resetTime = limiter.getFormattedTimeUntilReset();
      return 'Daily limit reached. Resets in $resetTime. Add more API keys to increase capacity.';
    }

    final keyText = keyCount > 1 ? '$keyCount keys' : '1 key';
    return '$remaining of $totalLimit AI requests remaining today ($keyText)';
  }
}
