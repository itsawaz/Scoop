import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';
import 'streak_service.dart';
import 'goal_engine.dart';
import 'health_service.dart';

class CoachMessage {
  final String role; // 'user' or 'ai'
  final String text;
  CoachMessage({required this.role, required this.text});

  Map<String, dynamic> toJson() => {'role': role, 'text': text};
  factory CoachMessage.fromJson(Map<String, dynamic> j) =>
      CoachMessage(role: j['role'] ?? 'ai', text: j['text'] ?? '');
}

class CoachService {
  static final CoachService _instance = CoachService._internal();
  factory CoachService() => _instance;
  CoachService._internal();

  final List<CoachMessage> chatHistory = [];
  GenerativeModel? _model;
  ChatSession? _chat;
  bool _initialized = false;
  String? _resumeSessionId; // Track which archived session is being continued

  Future<void> resumeArchivedConversation(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final archives = prefs.getStringList('coach_archives') ?? [];
    
    // Find the archive with matching ID
    String? foundArchive;
    for (final archive in archives) {
      if (archive.contains(sessionId)) {
        foundArchive = archive;
        break;
      }
    }
    
    if (foundArchive == null) return;
    
    _resumeSessionId = sessionId;
    chatHistory.clear();
    
    // Parse the archived conversation back into messages
    final lines = foundArchive.split('\n');
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('Mann:')) {
        final text = line.substring(5).trim();
        chatHistory.add(CoachMessage(role: 'ai', text: text));
      } else if (line.startsWith('User:')) {
        final text = line.substring(5).trim();
        chatHistory.add(CoachMessage(role: 'user', text: text));
      }
    }
    
    await _saveHistory();
    
    // Rebuild chat session
    if (_model != null) {
      final historyContent = chatHistory.map((m) {
        return Content(m.role == 'user' ? 'user' : 'model', [TextPart(m.text)]);
      }).toList();
      _chat = _model!.startChat(history: historyContent);
    }
  }
  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = chatHistory.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList('coach_chat_history', encoded);
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList('coach_chat_history') ?? [];
    chatHistory.clear();
    for (final s in stored) {
      try {
        chatHistory.add(CoachMessage.fromJson(jsonDecode(s)));
      } catch (_) {}
    }
  }

  Future<void> clearHistory() async {
    chatHistory.clear();
    _chat = null;
    _initialized = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('coach_chat_history');
    // Re-init fresh
    await initializeChat();
  }

  // ---- Chat Init ----
  Future<void> initializeChat() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key');
    if (apiKey == null || apiKey.isEmpty) return;

    // Build rich context
    String context = 'You are a personal fitness and nutrition coach named Mann. '
        'You are a female, obedient, and insightful understanding coach. '
        'Use data-driven insights. Format responses with line breaks for readability. ';

    final profileStr = prefs.getString('profile');
    if (profileStr != null) {
      try {
        final p = BiometricProfile.fromJson(jsonDecode(profileStr));
        context += 'User: ${p.age}yo ${p.gender}, ${p.weightKg.toStringAsFixed(1)}kg, '
            'height ${p.heightCm.toStringAsFixed(0)}cm, goal weight ${p.goalWeightKg.toStringAsFixed(1)}kg. '
            'Activity: ${p.activityLevel}. TDEE: ${p.tdee.toStringAsFixed(0)} kcal. ';
      } catch (_) {}
    }

    final conditions = prefs.getString('conditions') ?? 'None';
    final goals = prefs.getString('goals') ?? 'None';
    context += 'Health conditions: $conditions. Fitness goals: $goals. ';

    final goalStr = prefs.getString('goals_json');
    if (goalStr != null) {
      try {
        final g = GoalProfile.fromJson(jsonDecode(goalStr));
        context += 'Daily targets: ${g.calorieGoal} kcal, ${g.proteinGoalG.round()}g protein, '
            '${g.carbsGoalG.round()}g carbs, ${g.fatGoalG.round()}g fat. ';
      } catch (_) {}
    }

    final summary = await getRecentSummary();
    context += 'Recent Meal Data: $summary ';

    // Add health snapshot
    try {
      final health = await _fetchRecentHealthSnapshot();
      context += 'Recent Health Snapshot: Steps: ${health.steps}, Active Burn: ${health.activeCals.round()} kcal, Sleep: ${health.sleepHours.toStringAsFixed(1)} hr, Mindful: ${health.mindfulMinutes.round()} min. ';
    } catch (_) {}

    final archives = prefs.getStringList('coach_archives') ?? [];
    if (archives.isNotEmpty) {
      context += '\n\nHere is the historical conversation data from past sessions:\n${archives.join('\n\n')}';
    }

    _model = GenerativeModel(
      model: 'gemini-3.5-flash-lite',
      apiKey: apiKey,
      systemInstruction: Content.system(context),
    );

    // Load persisted history first
    await _loadHistory();

    if (chatHistory.isEmpty) {
      // Inject opening message without sending to API
      chatHistory.add(CoachMessage(
        role: 'ai',
        text: "Hey! I'm Mann, your AI health coach 💪\n\nI've reviewed your profile and recent activity. ${await _getPersonalisedGreeting(prefs)}",
      ));
      await _saveHistory();
    }

    // Rebuild the Gemini chat session with all past history
    final historyContent = chatHistory.map((m) {
      return Content(m.role == 'user' ? 'user' : 'model', [TextPart(m.text)]);
    }).toList();

    _chat = _model!.startChat(history: historyContent);
    _initialized = true;
  }

  Future<String> _getPersonalisedGreeting(SharedPreferences prefs) async {
    final streak = StreakService().currentStreak;
    if (streak > 0) return 'You\'re on a $streak-day streak — let\'s keep it going! What\'s on your mind?';
    return 'Ready to crush your goals today? Ask me anything about nutrition, workouts, or your progress!';
  }

  Future<String> sendMessage(String text) async {
    if (!_initialized || _chat == null) {
      await initializeChat();
      if (_chat == null) {
        return 'Please set your Gemini API Key in the Profile tab first ⚙️';
      }
    }

    chatHistory.add(CoachMessage(role: 'user', text: text));
    await _saveHistory();

    try {
      final response = await _chat!.sendMessage(Content.text(text));
      final reply = response.text ?? "Hmm, I didn't get that. Try again?";
      chatHistory.add(CoachMessage(role: 'ai', text: reply));
      await _saveHistory();
      return reply;
    } catch (e) {
      final errMsg = 'Connection error: ${e.toString().split(']').last.trim()}';
      chatHistory.add(CoachMessage(role: 'ai', text: errMsg));
      await _saveHistory();
      return errMsg;
    }
  }

  Future<String> getRecentSummary() async {
    final prefs = await SharedPreferences.getInstance();
    final historyList = prefs.getStringList('history') ?? [];
    int totalCals = 0;
    int mealCount = 0;
    int todayCalories = 0;
    List<String> foodNames = [];
    List<String> todayMealDetails = [];
    final now = DateTime.now();
    for (var str in historyList) {
      try {
        final e = MealEntry.fromJson(jsonDecode(str));
        if (now.difference(e.timestamp).inDays <= 3) {
          totalCals += e.nutrition.calories;
          mealCount++;
          if (now.difference(e.timestamp).inDays == 0) {
            foodNames.add(e.nutrition.foodName);
            todayCalories += e.nutrition.calories;
            todayMealDetails.add('${e.nutrition.foodName} (${e.nutrition.calories}kcal, ${e.nutrition.protein.toStringAsFixed(1)}g protein)');
          }
        }
      } catch (_) {}
    }
    final streak = StreakService().currentStreak;
    final mealSummary = todayMealDetails.isEmpty 
        ? 'No meals logged today'
        : 'Today\'s meals: ${todayMealDetails.join(", ")}';
    return '$mealCount meals in last 3 days, $totalCals kcal total. $mealSummary. Total today: $todayCalories kcal. Streak: $streak days.';
  }

  Future<HealthSnapshot> _fetchRecentHealthSnapshot() async {
    // Requires importing health_service.dart at top, wait I'll add it in another chunk
    return await HealthService().fetchDeepSnapshot();
  }

  Future<void> archiveCurrentChat() async {
    final prefs = await SharedPreferences.getInstance();
    if (chatHistory.length <= 1) return; // Only greeting exists
    
    final archives = prefs.getStringList('coach_archives') ?? [];
    
    // Convert current chat to a text block
    final sessionLog = chatHistory.map((m) => '${m.role == 'ai' ? 'Mann' : 'User'}: ${m.text}').join('\n');
    
    if (_resumeSessionId != null) {
      // Update existing archive with new messages
      for (var i = 0; i < archives.length; i++) {
        if (archives[i].contains(_resumeSessionId!)) {
          archives[i] = '--- Session on $_resumeSessionId ---\n$sessionLog';
          break;
        }
      }
    } else {
      // Create new archive
      final sessionId = DateTime.now().toIso8601String();
      archives.add('--- Session on $sessionId ---\n$sessionLog');
    }
    
    // Keep only last 10 sessions
    if (archives.length > 10) {
      archives.removeAt(0);
    }
    
    await prefs.setStringList('coach_archives', archives);
    
    // Clear active chat
    chatHistory.clear();
    _resumeSessionId = null;
    await prefs.remove('coach_chat_history');
    _chat = null;
    _initialized = false;
    await initializeChat();
  }

  Future<void> runDailyAutomationIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final toggle = prefs.getBool('auto_recalculate') ?? false;
    if (!toggle) return;
    final lastRun = prefs.getString('last_automation_run');
    final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    if (lastRun == today) return;
    final profileStr = prefs.getString('profile');
    if (profileStr != null) {
      try {
        final profile = BiometricProfile.fromJson(jsonDecode(profileStr));
        final conditions = prefs.getString('conditions') ?? 'None';
        final goals = prefs.getString('goals') ?? '';
        final newGoals = await GoalEngine.computeGoals(profile, conditions, goals);
        await prefs.setString('goals_json', jsonEncode(newGoals.toJson()));
        await prefs.setString('last_automation_run', today);
        // Reset coach so it picks up new goals
        _initialized = false;
      } catch (_) {}
    }
  }

  Future<String> getHypeMessage(double effectiveCals, double consumed, double burnt) async {
    final isDeficit = effectiveCals < 0;
    // Assuming 2000 is a rough goal if we don't have the exact one here
    final isOver = effectiveCals > 2000; 
    
    final List<String> deficitHypes = [
      "in your deficit era 🔥", "burning it up bestie 🔥", "calorie deficit secured 💅",
      "we love a fat burning queen 👑", "shredding season activated ⚔️", "giving main character energy ✨",
      "deficit goes brrrr 🥶", "literally melting 🫠🔥", "it's giving skinny legend 💅",
      "ate that deficit up 🍽️", "negative calories positive vibes 🧘‍♀️", "understood the assignment 💯",
      "deficit slayage 💅", "fat is literally crying rn 😭", "body goals loading... ⏳",
      "the math is mathing 🧮🔥", "deficit game too strong 😤", "snatching that waist ⏳",
      "rent free in the deficit zone 🏠", "iconic behavior only ✨",
      "serving deficit realness 💅", "slaying the game 🔥", "untouchable vibes 🛑",
      "we did it joe 😭👏", "the discipline is loud 📢", "no crumbs left 🧹",
      "periodt. 💅", "living my best deficit life ✨", "watch me shrink 👁️👄👁️",
      "immaculate vibes only 🧘‍♀️"
    ];

    final List<String> grindingHypes = [
      "keep grinding 💪", "stay locked in 🔒", "you got this bestie 💖",
      "trust the process ⏳", "getting those steps in 👟", "keep pushing ✨",
      "consistency is key 🔑", "one step at a time 🚶‍♀️", "fueling the machine ⛽",
      "don't stop now 🛑", "putting in the work 💼", "slow and steady wins 🐢",
      "making moves 📈", "small wins add up 💯", "staying on track 🚂",
      "doing the damn thing 👏", "protecting your peace and macros 🧘‍♀️", "building better habits 🧱",
      "the glow up is real ✨", "focus on you until the focus is on you 👁️",
      "romanticizing the grind ☕", "hustle hard 😤", "sweat now shine later ✨",
      "maintaining the vibe 🌊", "steady as she goes 🚢", "in the zone 🎯",
      "eye on the prize 🏆", "working on myself for myself 💖", "growth mindset 🌱",
      "just keep swimming 🐟"
    ];

    final List<String> overHypes = [
      "a little treat never hurt nobody 🍩", "tomorrow is a new day 🌅", "we'll get em next time 🥊",
      "bulking season? 🏋️‍♀️", "rest day energy 🛋️", "enjoy the fuel ⛽",
      "progress not perfection 📈", "it's giving bulk 🦍", "extra fuel for tomorrow 🔥",
      "don't stress it bestie 💖", "a minor setback for a major comeback 😤", "we bounce back 🏀",
      "calories don't define you 👑", "feed the soul sometimes ✨", "back on the grind tomorrow 💪",
      "all good vibes here 🌈", "no guilt just gains 📈", "keep your head up 👑",
      "one off day is nothing 🤏", "you're still doing great 💖",
      "it be like that sometimes 🤷‍♀️", "we move 🚶‍♀️", "soft life era ☁️",
      "treating myself ✨", "vibes were too good to track 🎶", "fueling the soul > fueling the body 🍕",
      "living a little 🎉", "it's called balance look it up ⚖️", "we go agane tomorrow 🔁",
      "nothing to see here 🙈"
    ];

    final List<String> listToUse = isDeficit ? deficitHypes : (isOver ? overHypes : grindingHypes);
    listToUse.shuffle();
    return listToUse.first;
  }
}
