import 'dart:collection';
import 'package:shared_preferences/shared_preferences.dart';
import 'model_selector.dart';

/// Rate limiter to prevent exceeding API quotas
/// Tracks requests per minute (RPM) and requests per day (RPD)
class ApiRateLimiter {
  static final ApiRateLimiter _instance = ApiRateLimiter._internal();
  factory ApiRateLimiter() => _instance;
  ApiRateLimiter._internal();

  final Queue<DateTime> _requestTimestamps = Queue();
  
  /// Check if a request can be made without exceeding limits
  /// 
  /// Parameters:
  /// - model: The model name to check limits for
  /// - keyOverride: Optional specific API key to check (for multi-key support)
  Future<bool> canMakeRequest({String? model, String? keyOverride}) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    
    // Get model limits
    final modelName = model ?? 'gemini-2.5-flash-lite';
    final limits = ModelSelector.getModelLimits(modelName);
    final maxRpm = limits['rpm'] ?? 15;
    final maxRpd = limits['rpd'] ?? 1000;
    
    // Clean old timestamps (older than 1 minute)
    _requestTimestamps.removeWhere((ts) => 
      now.difference(ts).inMinutes >= 1
    );
    
    // Check RPM limit (leave 20% buffer)
    final rpmLimit = (maxRpm * 0.8).floor();
    if (_requestTimestamps.length >= rpmLimit) {
      return false;
    }
    
    // Check RPD limit
    final todayStr = "${now.year}-${now.month}-${now.day}";
    final apiKey = keyOverride ?? prefs.getString('api_key') ?? '';
    final apiDate = prefs.getString('api_date_$apiKey') ?? todayStr;
    int apiCount = (apiDate == todayStr) 
      ? (prefs.getInt('api_count_$apiKey') ?? 0) 
      : 0;
    
    // Leave 10% buffer for RPD
    final rpdLimit = (maxRpd * 0.9).floor();
    if (apiCount >= rpdLimit) {
      return false;
    }
    
    return true;
  }

  /// Record that a request was made
  Future<void> recordRequest({String? apiKey}) async {
    final now = DateTime.now();
    _requestTimestamps.add(now);
    
    final prefs = await SharedPreferences.getInstance();
    final key = apiKey ?? prefs.getString('api_key') ?? '';
    
    final todayStr = "${now.year}-${now.month}-${now.day}";
    final apiDate = prefs.getString('api_date_$key') ?? todayStr;
    int apiCount = (apiDate == todayStr) 
      ? (prefs.getInt('api_count_$key') ?? 0) 
      : 0;
    
    await prefs.setString('api_date_$key', todayStr);
    await prefs.setInt('api_count_$key', apiCount + 1);
  }

  /// Get remaining requests for today
  Future<int> getRemainingRequests({String? model, String? apiKey}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    
    final modelName = model ?? 'gemini-2.5-flash-lite';
    final limits = ModelSelector.getModelLimits(modelName);
    final maxRpd = limits['rpd'] ?? 1000;
    
    final todayStr = "${now.year}-${now.month}-${now.day}";
    final key = apiKey ?? prefs.getString('api_key') ?? '';
    final apiDate = prefs.getString('api_date_$key') ?? todayStr;
    int apiCount = (apiDate == todayStr) 
      ? (prefs.getInt('api_count_$key') ?? 0) 
      : 0;
    
    return (maxRpd - apiCount).clamp(0, maxRpd);
  }

  /// Get user-friendly error message when limit is reached
  String getErrorMessage({String? model}) {
    final modelName = model ?? 'gemini-2.5-flash-lite';
    final limits = ModelSelector.getModelLimits(modelName);
    final maxRpd = limits['rpd'] ?? 1000;
    
    return "You've reached your daily AI limit ($maxRpd requests/day for $modelName). "
           "Try again tomorrow, add more API keys in Profile, or use saved meals for quick logging.";
  }

  /// Get time until rate limit resets
  Duration getTimeUntilReset() {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    return tomorrow.difference(now);
  }

  /// Get formatted time until reset (e.g., "5h 23m")
  String getFormattedTimeUntilReset() {
    final duration = getTimeUntilReset();
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return "${hours}h ${minutes}m";
    } else {
      return "${minutes}m";
    }
  }

  /// Clear all rate limit data (for testing)
  Future<void> clearLimits() async {
    _requestTimestamps.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_date');
    await prefs.remove('api_count');
  }
}
