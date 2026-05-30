import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models.dart';
import 'health_service.dart';

class FastingService {
  static final FastingService _instance = FastingService._internal();
  factory FastingService() => _instance;
  FastingService._internal();

  FastingSession? currentSession;

  Future<void> loadCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('current_fasting_session');
    if (jsonStr != null) {
      try {
        currentSession = FastingSession.fromJson(jsonDecode(jsonStr));
      } catch (_) {}
    }
  }

  Future<void> startFast(int targetHours) async {
    currentSession = FastingSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: DateTime.now(),
      targetHours: targetHours.toDouble(),
      completed: false,
    );
    await _saveCurrentSession();
  }

  Future<void> stopFast() async {
    if (currentSession != null) {
      final end = DateTime.now();
      final actual = end.difference(currentSession!.startTime).inMinutes / 60.0;
      
      final completedSession = FastingSession(
        id: currentSession!.id,
        startTime: currentSession!.startTime,
        endTime: end,
        targetHours: currentSession!.targetHours,
        completed: true,
        actualHours: actual,
      );
      
      // Save to history
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('fasting_history') ?? [];
      history.add(jsonEncode(completedSession.toJson()));
      await prefs.setStringList('fasting_history', history);
      
      // Clear current
      currentSession = null;
      await prefs.remove('current_fasting_session');
    }
  }

  Future<void> _saveCurrentSession() async {
    if (currentSession != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_fasting_session', jsonEncode(currentSession!.toJson()));
    }
  }

  Future<String> getAIFastingGuidance() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key');
    if (apiKey == null || apiKey.isEmpty) return "Please set your Gemini API key in Profile.";

    final snap = await HealthService().fetchDeepSnapshot();
    double sleepHours = snap.sleepHours;
    if (sleepHours == 0) sleepHours = 7.0; // fallback if no health data

    final model = GenerativeModel(model: 'gemma-4-31b-it', apiKey: apiKey);
    final prompt = """
You are a fasting coach. 
The user slept for ${sleepHours.toStringAsFixed(1)} hours last night.
Provide a short, motivating 2-sentence guidance on how they should approach intermittent fasting today based on their sleep.
If sleep is low (< 6 hrs), recommend a shorter fast (12-14 hrs). If sleep is good (7-9 hrs), they can push for 16-18 hrs.
""";

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? "Stay hydrated and listen to your body!";
    } catch (e) {
      return "Stay hydrated and listen to your body! (AI Error)";
    }
  }
}
