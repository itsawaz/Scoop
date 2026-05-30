import 'package:shared_preferences/shared_preferences.dart';

/// Manages multiple API keys for load balancing and rate limit distribution
/// 
/// Rate limits are per Google Cloud project, not per API key.
/// This service allows users to add multiple API keys from different projects
/// to multiply their effective rate limits.
class ApiKeyManager {
  static final ApiKeyManager _instance = ApiKeyManager._internal();
  factory ApiKeyManager() => _instance;
  ApiKeyManager._internal();

  List<String> _apiKeys = [];
  int _currentKeyIndex = 0;
  final Map<String, int> _keyUsageCount = {};
  final Map<String, DateTime> _keyLastUsed = {};
  final Map<String, int> _keyDailyCount = {};
  final Map<String, String> _keyDailyDate = {};

  /// Load all API keys from SharedPreferences
  Future<void> loadApiKeys() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKeys = [
      prefs.getString('api_key') ?? '',
      prefs.getString('api_key_2') ?? '',
      prefs.getString('api_key_3') ?? '',
    ].where((k) => k.isNotEmpty).toList();
    
    // Initialize usage counters
    for (var key in _apiKeys) {
      _keyUsageCount[key] = 0;
      _keyLastUsed[key] = DateTime.now();
      
      // Load daily counts
      final today = _getTodayString();
      final savedDate = prefs.getString('api_date_$key') ?? today;
      final savedCount = prefs.getInt('api_count_$key') ?? 0;
      
      _keyDailyDate[key] = savedDate;
      _keyDailyCount[key] = (savedDate == today) ? savedCount : 0;
    }
  }

  /// Get the next API key using round-robin rotation
  String getNextApiKey() {
    if (_apiKeys.isEmpty) return '';
    
    // Round-robin rotation
    final key = _apiKeys[_currentKeyIndex];
    _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
    _keyUsageCount[key] = (_keyUsageCount[key] ?? 0) + 1;
    _keyLastUsed[key] = DateTime.now();
    
    return key;
  }

  /// Get an available API key that hasn't hit rate limits
  /// Throws exception if all keys are exhausted
  Future<String> getAvailableApiKey({String? modelName}) async {
    if (_apiKeys.isEmpty) {
      throw Exception('No API keys configured. Please add an API key in Profile settings.');
    }

    // Get model limits
    final limits = _getModelLimits(modelName ?? 'gemini-2.5-flash-lite');
    final maxRpd = limits['rpd'] ?? 1000;

    // Try each key in rotation
    for (var i = 0; i < _apiKeys.length; i++) {
      final key = getNextApiKey();
      
      // Check if this key has capacity
      final dailyCount = await _getDailyCount(key);
      if (dailyCount < maxRpd) {
        return key;
      }
    }
    
    // All keys exhausted
    throw Exception(
      'All ${_apiKeys.length} API key(s) have reached their daily limit ($maxRpd requests/day). '
      'Try again tomorrow or add more API keys in Profile settings.'
    );
  }

  /// Record that an API key was used
  Future<void> recordKeyUsage(String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayString();
    
    // Reset counter if it's a new day
    if (_keyDailyDate[apiKey] != today) {
      _keyDailyDate[apiKey] = today;
      _keyDailyCount[apiKey] = 0;
    }
    
    // Increment counter
    _keyDailyCount[apiKey] = (_keyDailyCount[apiKey] ?? 0) + 1;
    
    // Save to preferences
    await prefs.setString('api_date_$apiKey', today);
    await prefs.setInt('api_count_$apiKey', _keyDailyCount[apiKey] ?? 0);
  }

  /// Get daily usage count for a specific key
  Future<int> _getDailyCount(String apiKey) async {
    final today = _getTodayString();
    
    // Reset if new day
    if (_keyDailyDate[apiKey] != today) {
      _keyDailyDate[apiKey] = today;
      _keyDailyCount[apiKey] = 0;
    }
    
    return _keyDailyCount[apiKey] ?? 0;
  }

  /// Get total daily limit across all keys
  Future<int> getTotalDailyLimit({String? modelName}) async {
    final limits = _getModelLimits(modelName ?? 'gemini-2.5-flash-lite');
    final rpdPerKey = limits['rpd'] ?? 1000;
    return _apiKeys.length * rpdPerKey;
  }

  /// Get remaining requests across all keys
  Future<int> getRemainingRequests({String? modelName}) async {
    final limits = _getModelLimits(modelName ?? 'gemini-2.5-flash-lite');
    final rpdPerKey = limits['rpd'] ?? 1000;
    
    int totalRemaining = 0;
    for (var key in _apiKeys) {
      final used = await _getDailyCount(key);
      final remaining = rpdPerKey - used;
      totalRemaining += remaining.clamp(0, rpdPerKey);
    }
    
    return totalRemaining;
  }

  /// Get usage statistics for all keys
  Future<Map<String, dynamic>> getUsageStats() async {
    final stats = <String, dynamic>{};
    
    for (var i = 0; i < _apiKeys.length; i++) {
      final key = _apiKeys[i];
      final keyLabel = 'Key ${i + 1}';
      final dailyCount = await _getDailyCount(key);
      
      stats[keyLabel] = {
        'used': dailyCount,
        'lastUsed': _keyLastUsed[key],
        'totalCalls': _keyUsageCount[key] ?? 0,
      };
    }
    
    return stats;
  }

  /// Get number of configured API keys
  int getKeyCount() => _apiKeys.length;

  /// Check if multiple keys are configured
  bool hasMultipleKeys() => _apiKeys.length > 1;

  String _getTodayString() {
    final now = DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }

  Map<String, int> _getModelLimits(String model) {
    switch (model) {
      case 'gemini-2.5-flash-lite':
        return {'rpm': 15, 'rpd': 1000, 'tpm': 250000};
      case 'gemini-2.5-flash':
        return {'rpm': 10, 'rpd': 250, 'tpm': 250000};
      case 'gemini-2.5-pro':
        return {'rpm': 5, 'rpd': 100, 'tpm': 250000};
      case 'gemma-4-31b-it':
        return {'rpm': 15, 'rpd': 1500, 'tpm': -1};
      default:
        return {'rpm': 5, 'rpd': 20, 'tpm': 250000};
    }
  }
}
