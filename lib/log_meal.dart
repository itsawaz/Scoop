import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'widgets.dart';

class ChatMessage {
  final String role; // 'user' or 'ai'
  final String text;
  final NutritionData? nutrition;
  ChatMessage({required this.role, required this.text, this.nutrition});
}

class LogMealScreen extends StatefulWidget {
  const LogMealScreen({super.key});
  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  final ImagePicker _picker = ImagePicker();
  final _descController = TextEditingController();
  final _chatScrollController = ScrollController();
  XFile? _image;
  bool _isAnalyzing = false;
  bool _chatStarted = false;
  final List<ChatMessage> _chatHistory = [];
  NutritionData? _latestNutrition;
  GenerativeModel? _model;
  String _apiKey = '';
  String _conditions = '';
  String _goals = '';

  @override
  void initState() {
    super.initState();
    _initAI();
  }

  Future<void> _initAI() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key') ?? '';
    _conditions = prefs.getString('conditions') ?? 'None';
    _goals = prefs.getString('goals') ?? 'None';
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 800);
    if (picked != null) setState(() => _image = picked);
  }

  String _buildSystemPrompt() => """
You are a medical-grade nutritional AI. Your user's health profile:
- Medical Conditions: $_conditions
- Dietary Goals: $_goals

Analyze the food described/shown and return ONLY a valid JSON object with these exact keys:
{
  "foodName": "Meal Name",
  "calories": 450,
  "protein": 25.0,
  "carbs": 60.0,
  "fat": 15.0,
  "sugar": 8.0,
  "fiber": 4.0,
  "sodium": 800.0,
  "vitaminC": 20.0,
  "vitaminD": 2.0,
  "calcium": 150.0,
  "iron": 3.5,
  "reasoning": "Detailed explanation of why you estimated these values, portion size assumptions, etc.",
  "medicalAlert": "ALERT: This food is high in sugar which is dangerous for your Diabetes. Or empty string if no alert."
}

All numeric values are per-serving amounts in grams (g) or standard units.
Return ONLY the JSON. No markdown. No backticks. No extra text.
""";

  Future<void> _analyzeFirstTime() async {
    if (_image == null && _descController.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _isAnalyzing = true; _chatStarted = true; });

    try {
      final prompt = TextPart("${_buildSystemPrompt()}\n\nUser description: ${_descController.text}");
      final List<Part> parts = [prompt];
      if (_image != null) {
        final bytes = await File(_image!.path).readAsBytes();
        parts.add(DataPart('image/jpeg', bytes));
      }

      final response = await _model!.generateContent([Content.multi(parts)]);
      final raw = response.text?.trim() ?? '{}';
      await _processResponse(raw, isFirstTime: true);
    } catch (e) {
      _chatHistory.add(ChatMessage(role: 'ai', text: 'Error: $e'));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
      _scrollToBottom();
    }
  }

  Future<void> _sendFollowUp() async {
    final userText = _descController.text.trim();
    if (userText.isEmpty) return;
    FocusScope.of(context).unfocus();
    _chatHistory.add(ChatMessage(role: 'user', text: userText));
    _descController.clear();
    setState(() => _isAnalyzing = true);

    // Build follow-up prompt - repeat FULL schema so the AI sticks to exact keys
    final chatContext = _chatHistory.map((m) => "${m.role}: ${m.text}").join('\n');
    final newPrompt = """
You are a medical-grade nutritional AI. The conversation so far:
$chatContext

The user just gave you a correction or more context. Recalculate your estimate.
Return ONLY a valid JSON object with EXACTLY these keys (no others):
{
  "foodName": "Meal Name",
  "calories": 400,
  "protein": 4.0,
  "carbs": 105.0,
  "fat": 1.0,
  "sugar": 79.0,
  "fiber": 11.0,
  "sodium": 3.0,
  "vitaminC": 134.0,
  "vitaminD": 0.0,
  "calcium": 80.0,
  "iron": 2.0,
  "reasoning": "Your detailed reasoning here.",
  "medicalAlert": ""
}
Do NOT wrap in backticks. Do NOT add extra keys. Return raw JSON only.
""";
    try {
      final response = await _model!.generateContent([Content.text(newPrompt)]);
      final raw = response.text?.trim() ?? '{}';
      await _processResponse(raw, isFirstTime: false);
    } catch (e) {
      _chatHistory.add(ChatMessage(role: 'ai', text: 'Error: $e'));
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
      _scrollToBottom();
    }
  }

  Future<void> _processResponse(String raw, {required bool isFirstTime}) async {
    try {
      // Robustly extract JSON: strip markdown fences, find first { to last }
      String jsonStr = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final firstBrace = jsonStr.indexOf('{');
      final lastBrace = jsonStr.lastIndexOf('}');
      if (firstBrace != -1 && lastBrace != -1) {
        jsonStr = jsonStr.substring(firstBrace, lastBrace + 1);
      }
      final data = jsonDecode(jsonStr);
      final nutrition = NutritionData.fromJson(data);
      _latestNutrition = nutrition;

      String aiText = "Updated to **${nutrition.calories} kcal** for \"${nutrition.foodName}\".\n\n${nutrition.reasoning}";
      if (nutrition.medicalAlert.isNotEmpty) {
        aiText += "\n\n⚠️ ${nutrition.medicalAlert}";
      }
      aiText += "\n\nAnything else to correct?";

      _chatHistory.add(ChatMessage(role: 'ai', text: aiText, nutrition: nutrition));
    } catch (e) {
      // Friendly fallback — show what went wrong
      _chatHistory.add(ChatMessage(role: 'ai', text: "Hmm, I couldn't re-parse that. Try rephrasing — e.g. 'it was 500g, not 200g'."));
    }
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _confirmEntry() async {
    if (_latestNutrition == null) return;
    final prefs = await SharedPreferences.getInstance();

    final entry = MealEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      nutrition: _latestNutrition!,
      note: _latestNutrition!.foodName,
    );

    final historyList = prefs.getStringList('history') ?? [];
    historyList.add(jsonEncode(entry.toJson()));
    await prefs.setStringList('history', historyList);

    // API limit counter
    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month}-${now.day}";
    final apiDate = prefs.getString('api_date') ?? todayStr;
    int apiCount = (apiDate == todayStr) ? (prefs.getInt('api_count') ?? 0) : 0;
    await prefs.setString('api_date', todayStr);
    await prefs.setInt('api_count', apiCount + 1);

    if (mounted) Navigator.pop(context, entry);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CupertinoPageScaffold(
        backgroundColor: kBg,
        navigationBar: const CupertinoNavigationBar(backgroundColor: Color(0x00000000), border: null, middle: Text('Log Meal', style: TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold))),
        child: SafeArea(
          child: Column(
            children: [
              if (!_chatStarted) _buildInputArea(),
              if (_chatStarted) _buildChatArea(),
              _buildBottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Expanded(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          const SizedBox(height: 10),
          BentoCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                children: [
                  if (_image != null)
                    Image.file(File(_image!.path), height: 260, width: double.infinity, fit: BoxFit.cover)
                  else
                    Container(height: 180, color: const Color(0xFF1A1A1A), child: const Center(child: Icon(CupertinoIcons.camera, size: 50, color: Color(0xFF333333)))),
                  Row(
                    children: [
                      Expanded(child: CupertinoButton(borderRadius: BorderRadius.zero, color: kCard, child: const Text('CAMERA', style: TextStyle(color: kTeal, fontWeight: FontWeight.bold, fontSize: 13)), onPressed: () => _pickImage(ImageSource.camera))),
                      Expanded(child: CupertinoButton(borderRadius: BorderRadius.zero, color: kCard, child: const Text('GALLERY', style: TextStyle(color: kPink, fontWeight: FontWeight.bold, fontSize: 13)), onPressed: () => _pickImage(ImageSource.gallery))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          BentoCard(
            child: CupertinoTextField(
              controller: _descController,
              placeholder: 'Describe your meal (or tap 🎤 for voice)...',
              textInputAction: TextInputAction.done,
              placeholderStyle: const TextStyle(color: Color(0xFF444444)),
              style: const TextStyle(color: CupertinoColors.white),
              maxLines: 3,
              decoration: const BoxDecoration(),
            ),
          ),
          const SizedBox(height: 20),
          NeonButton(
            text: _isAnalyzing ? 'Asking AI...' : 'Analyze ⚡️',
            isLoading: _isAnalyzing,
            onPressed: _analyzeFirstTime,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Expanded(
      child: ListView.builder(
        controller: _chatScrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _chatHistory.length + (_isAnalyzing ? 1 : 0),
        itemBuilder: (context, index) {
          if (_isAnalyzing && index == _chatHistory.length) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Row(children: [
                CupertinoActivityIndicator(color: kNeon),
                SizedBox(width: 10),
                Text('Thinking...', style: TextStyle(color: CupertinoColors.systemGrey)),
              ]),
            );
          }
          final msg = _chatHistory[index];
          final isUser = msg.role == 'user';

          if (!isUser && msg.nutrition != null) {
            return _buildNutritionBubble(msg);
          }

          return Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF1E1E1E) : const Color(0xFF1A1A2E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 20),
                ),
                border: Border.all(color: isUser ? kBorder : const Color(0xFF2A2A4E)),
              ),
              child: Text(msg.text, style: TextStyle(color: isUser ? CupertinoColors.white : const Color(0xFFCCCCFF), fontSize: 14, height: 1.5)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNutritionBubble(ChatMessage msg) {
    final n = msg.nutrition!;
    final hasAlert = n.medicalAlert.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasAlert)
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2A0A0A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kPink.withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  const Text('⚠️ ', style: TextStyle(fontSize: 20)),
                  Expanded(child: Text(n.medicalAlert, style: const TextStyle(color: kPink, fontSize: 13, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          BentoCard(
            glowColor: const Color(0x22E5FF00),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.foodName, style: const TextStyle(color: CupertinoColors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(n.reasoning, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12, height: 1.4)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _macroChip('CAL', '${n.calories}', 'kcal', kNeon)),
                  const SizedBox(width: 8),
                  Expanded(child: _macroChip('PROTEIN', '${n.protein.round()}g', '', const Color(0xFFFF9500))),
                  const SizedBox(width: 8),
                  Expanded(child: _macroChip('CARBS', '${n.carbs.round()}g', '', const Color(0xFF30D158))),
                  const SizedBox(width: 8),
                  Expanded(child: _macroChip('FAT', '${n.fat.round()}g', '', const Color(0xFF5E5CE6))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _macroChip('SUGAR', '${n.sugar.round()}g', '', hasAlert ? kPink : CupertinoColors.systemGrey)),
                  const SizedBox(width: 8),
                  Expanded(child: _macroChip('FIBER', '${n.fiber.round()}g', '', CupertinoColors.systemGrey)),
                  const SizedBox(width: 8),
                  Expanded(child: _macroChip('SODIUM', '${n.sodium.round()}mg', '', CupertinoColors.systemGrey)),
                  const SizedBox(width: 8),
                  Expanded(child: _macroChip('VIT-C', '${n.vitaminC.round()}mg', '', kTeal)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroChip(String label, String value, String unit, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: CupertinoColors.white, fontSize: 13, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    if (!_chatStarted) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: kBg,
      child: Column(
        children: [
          if (_latestNutrition != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: NeonButton(text: "✓ Log ${_latestNutrition!.calories} kcal", onPressed: _confirmEntry),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kBorder),
                  ),
                  child: CupertinoTextField(
                    controller: _descController,
                    placeholder: 'Correct me or add context...',
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendFollowUp(),
                    placeholderStyle: const TextStyle(color: Color(0xFF444444)),
                    style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
                    decoration: const BoxDecoration(),
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sendFollowUp,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: kNeon, borderRadius: BorderRadius.circular(50)),
                  child: const Icon(CupertinoIcons.arrow_up, color: kBg, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
