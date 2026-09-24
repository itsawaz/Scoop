import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'widgets.dart';
import 'tabs.dart';
import 'services/goal_engine.dart';
import 'services/health_service.dart';
import 'services/api_key_manager.dart';
import 'widgets/api_usage_indicator.dart';


// ==========================================
// ONBOARDING - NAME
// ==========================================
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();

  void _next() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _nameController.text.trim().isEmpty ? 'Bestie' : _nameController.text.trim());
    if (mounted) Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const MedicalProfileScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CupertinoPageScaffold(
        backgroundColor: kBg,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 40),
              const Text("WHAT'S\nYOUR\nVIBE?", style: TextStyle(fontSize: 60, fontWeight: FontWeight.w900, height: 0.9, letterSpacing: -2, color: CupertinoColors.white)),
              const SizedBox(height: 40),
              BentoCard(
                glowColor: const Color(0x33FF0055),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CALL ME', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 10),
                    CupertinoTextField(
                      controller: _nameController,
                      placeholder: 'Your Name',
                      textInputAction: TextInputAction.done,
                      placeholderStyle: const TextStyle(color: Color(0xFF444444)),
                      style: const TextStyle(color: CupertinoColors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const BoxDecoration(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 100),
              NeonButton(text: "Next →", onPressed: _next),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ONBOARDING - MEDICAL PROFILE
// ==========================================
class MedicalProfileScreen extends StatefulWidget {
  const MedicalProfileScreen({super.key});
  @override
  State<MedicalProfileScreen> createState() => _MedicalProfileScreenState();
}

class _MedicalProfileScreenState extends State<MedicalProfileScreen> {

  final _conditions = [
    'None', 'Type 2 Diabetes', 'Type 1 Diabetes', 'Hypertension',
    'High Cholesterol', 'Celiac Disease', 'Lactose Intolerance', 'Nut Allergy',
  ];
  final _goals = [
    'Lose Weight', 'Maintain Weight', 'Build Muscle', 'Improve Energy',
    'Better Heart Health', 'Manage Blood Sugar', 'Reduce Inflammation',
  ];

  final Set<String> _selectedConditions = {'None'};
  final Set<String> _selectedGoals = {};

  void _next() async {
    final prefs = await SharedPreferences.getInstance();
    final conditions = _selectedConditions.where((c) => c != 'None').join(', ');
    await prefs.setString('conditions', conditions.isEmpty ? 'None' : conditions);
    await prefs.setString('goals', _selectedGoals.join(', '));
    if (mounted) Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const BiometricOnboardingScreen()));
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kNeon : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? kNeon : kBorder),
        ),
        child: Text(label, style: TextStyle(color: selected ? kBg : CupertinoColors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CupertinoPageScaffold(
        backgroundColor: kBg,
        navigationBar: const CupertinoNavigationBar(backgroundColor: Color(0x00000000), border: null),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text("YOUR\nHEALTH\nPROFILE", style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, height: 0.9, letterSpacing: -2, color: CupertinoColors.white)),
              const SizedBox(height: 8),
              const Text("This helps AI give you personalized alerts and advice.", style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13)),
              const SizedBox(height: 32),
              BentoCard(
                glowColor: const Color(0x33FF0055),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DO YOU HAVE ANY CONDITIONS?', style: TextStyle(color: kPink, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 14),
                    Wrap(
                      children: _conditions.map((c) => _chip(c, _selectedConditions.contains(c), () {
                        setState(() {
                          if (c == 'None') {
                            _selectedConditions.clear();
                            _selectedConditions.add('None');
                          } else {
                            _selectedConditions.remove('None');
                            if (_selectedConditions.contains(c)) {
                              _selectedConditions.remove(c);
                              if (_selectedConditions.isEmpty) _selectedConditions.add('None');
                            } else {
                              _selectedConditions.add(c);
                            }
                          }
                        });
                      })).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              BentoCard(
                glowColor: const Color(0x3300FFD1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('YOUR GOALS', style: TextStyle(color: kTeal, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 14),
                    Wrap(
                      children: _goals.map((g) => _chip(g, _selectedGoals.contains(g), () {
                        setState(() {
                          if (_selectedGoals.contains(g)) _selectedGoals.remove(g);
                          else _selectedGoals.add(g);
                        });
                      })).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              NeonButton(text: "Next →", onPressed: _next),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ONBOARDING - BIOMETRICS
// ==========================================
class BiometricOnboardingScreen extends StatefulWidget {
  const BiometricOnboardingScreen({super.key});
  @override
  State<BiometricOnboardingScreen> createState() => _BiometricOnboardingScreenState();
}

class _BiometricOnboardingScreenState extends State<BiometricOnboardingScreen> {
  String _unitSystem = 'metric';
  final _heightCtrl = TextEditingController(text: '170');
  final _weightCtrl = TextEditingController(text: '70');
  final _goalWeightCtrl = TextEditingController(text: '65');
  final _ageCtrl = TextEditingController(text: '30');
  String _gender = 'male';
  String _activity = 'sedentary';

  void _next() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Convert to metric if imperial was selected
    double h = double.tryParse(_heightCtrl.text) ?? 170.0;
    double w = double.tryParse(_weightCtrl.text) ?? 70.0;
    double gw = double.tryParse(_goalWeightCtrl.text) ?? 70.0;

    if (_unitSystem == 'imperial') {
      h = h * 2.54; // Assume inches for simplicity in this MVP, normally ft+in
      w = w / 2.20462;
      gw = gw / 2.20462;
    }

    await prefs.setString('unit_system', _unitSystem);
    await prefs.setDouble('height_cm', h);
    await prefs.setDouble('weight_kg', w);
    await prefs.setDouble('initial_weight_kg', w);
    await prefs.setDouble('goal_weight_kg', gw);
    await prefs.setInt('age', int.tryParse(_ageCtrl.text) ?? 30);
    await prefs.setString('gender', _gender);
    await prefs.setString('activity_level', _activity);

    if (mounted) Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const HealthAppConnectScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CupertinoPageScaffold(
        backgroundColor: kBg,
        navigationBar: const CupertinoNavigationBar(backgroundColor: Color(0x00000000), border: null),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text("YOUR\nBODY", style: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, height: 0.9, letterSpacing: -2, color: CupertinoColors.white)),
              const SizedBox(height: 24),
              
              CupertinoSlidingSegmentedControl<String>(
                groupValue: _unitSystem,
                children: const {
                  'metric': Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Metric (kg/cm)')),
                  'imperial': Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Text('Imperial (lbs/in)')),
                },
                onValueChanged: (v) => setState(() => _unitSystem = v!),
              ),
              const SizedBox(height: 24),
              
              BentoCard(
                child: Column(children: [
                  CupertinoTextField(controller: _ageCtrl, placeholder: 'Age', keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  CupertinoTextField(controller: _heightCtrl, placeholder: _unitSystem == 'metric' ? 'Height (cm)' : 'Height (inches)', keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  CupertinoTextField(controller: _weightCtrl, placeholder: _unitSystem == 'metric' ? 'Current Weight (kg)' : 'Current Weight (lbs)', keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  CupertinoTextField(controller: _goalWeightCtrl, placeholder: _unitSystem == 'metric' ? 'Goal Weight (kg)' : 'Goal Weight (lbs)', keyboardType: TextInputType.number),
                ]),
              ),
              const SizedBox(height: 16),
              
              BentoCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('GENDER', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  CupertinoSlidingSegmentedControl<String>(
                    groupValue: _gender,
                    children: const {'male': Text('Male'), 'female': Text('Female'), 'other': Text('Other')},
                    onValueChanged: (v) => setState(() => _gender = v!),
                  ),
                ]),
              ),
              const SizedBox(height: 16),

              BentoCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('ACTIVITY LEVEL', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...['sedentary', 'light', 'moderate', 'active', 'very_active'].map((level) {
                    final selected = _activity == level;
                    return GestureDetector(
                      onTap: () => setState(() => _activity = level),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: selected ? kNeon.withOpacity(0.2) : kBg,
                          border: Border.all(color: selected ? kNeon : kBorder),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          Icon(selected ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.circle, color: selected ? kNeon : CupertinoColors.systemGrey, size: 20),
                          const SizedBox(width: 12),
                          Text(level.toUpperCase().replaceAll('_', ' '), style: TextStyle(color: selected ? kNeon : CupertinoColors.white, fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    );
                  }).toList(),
                ]),
              ),

              const SizedBox(height: 40),
              NeonButton(text: "Next →", onPressed: _next),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ONBOARDING - HEALTH APP
// ==========================================
class HealthAppConnectScreen extends StatelessWidget {
  const HealthAppConnectScreen({super.key});

  void _next(BuildContext context) {
    Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ApiKeyScreen()));
  }

  void _connect(BuildContext context) async {
    final health = HealthService();
    try {
      final success = await health.requestPermissions();
      final prefs = await SharedPreferences.getInstance();
      if (Platform.isIOS) {
        await prefs.setBool('health_connected_ios', success);
      } else {
        await prefs.setBool('health_connected_android', success);
      }
    } catch (e) {
      debugPrint("Health Connect Error: \$e");
    }
    _next(context);
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    return CupertinoPageScaffold(
      backgroundColor: kBg,
      navigationBar: const CupertinoNavigationBar(backgroundColor: Color(0x00000000), border: null),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.heart_circle_fill, size: 100, color: kPink),
              const SizedBox(height: 24),
              Text(isIOS ? "CONNECT\nAPPLE HEALTH" : "CONNECT\nHEALTH CONNECT", style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, height: 0.9, letterSpacing: -1, color: CupertinoColors.white), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              const Text("We read your steps, sleep, and active calories to compute your goals and daily score.", style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 60),
              NeonButton(text: "Connect", onPressed: () => _connect(context), color: kPink),
              const SizedBox(height: 16),
              CupertinoButton(child: const Text('Skip for now', style: TextStyle(color: CupertinoColors.systemGrey)), onPressed: () => _next(context)),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ONBOARDING - API KEY
// ==========================================

class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({super.key});
  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final _apiController = TextEditingController();
  bool _isValidating = false;
  String _errorMsg = '';

  Future<void> _launchUrl() async {
    final url = Uri.parse('https://aistudio.google.com/app/apikey');
    if (!await launchUrl(url)) debugPrint('Could not launch $url');
  }

  void _finish() async {
    if (_apiController.text.trim().isEmpty) return;
    setState(() { _isValidating = true; _errorMsg = ''; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final apiKey = _apiController.text.trim();
      
      // Validate API key
      try {
        final testModel = GenerativeModel(model: 'gemini-3.5-flash-lite', apiKey: apiKey);
        await testModel.generateContent([Content.text("hi")]);
      } catch (e) {
        if (mounted) {
          setState(() { _errorMsg = 'Invalid or unauthorized API Key. Please check and try again.'; });
        }
        return;
      }

      await prefs.setString('api_key', apiKey);
      if (!prefs.containsKey('history')) await prefs.setStringList('history', []);
      
      // Attempt to calculate goals using GoalEngine
      try {
        final bio = BiometricProfile(
          heightCm: prefs.getDouble('height_cm') ?? 170.0,
          weightKg: prefs.getDouble('weight_kg') ?? 70.0,
          goalWeightKg: prefs.getDouble('goal_weight_kg') ?? 70.0,
          initialWeightKg: prefs.getDouble('initial_weight_kg') ?? 70.0,
          age: prefs.getInt('age') ?? 30,
          gender: prefs.getString('gender') ?? 'other',
          activityLevel: prefs.getString('activity_level') ?? 'sedentary',
          unitSystem: prefs.getString('unit_system') ?? 'metric',
        );
        final conds = prefs.getString('conditions') ?? '';
        final goals = prefs.getString('goals') ?? '';
        await GoalEngine.computeGoals(bio, conds, goals);
      } catch (e) {
        debugPrint("Initial goal compute failed: \$e");
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          CupertinoPageRoute(builder: (_) => const MainTabScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() { _errorMsg = 'Error saving: $e'; });
    } finally {
      if (mounted) setState(() => _isValidating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CupertinoPageScaffold(
        backgroundColor: kBg,
        navigationBar: const CupertinoNavigationBar(backgroundColor: Color(0x00000000), border: null),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text("UNLOCK\nTHE AI", style: TextStyle(fontSize: 60, fontWeight: FontWeight.w900, height: 0.9, letterSpacing: -2, color: CupertinoColors.white)),
              const SizedBox(height: 40),
              BentoCard(
                glowColor: const Color(0x3300FFD1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GEMINI API KEY (FREE)', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    const Text('1,500 free AI calls per day. No credit card needed.', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
                    const SizedBox(height: 16),
                    CupertinoTextField(
                      controller: _apiController,
                      placeholder: 'AIzaSy...',
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(color: CupertinoColors.white, fontSize: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(14)),
                    ),
                    if (_errorMsg.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(_errorMsg, style: const TextStyle(color: kPink, fontSize: 12)),
                      ),
                    const SizedBox(height: 16),
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: _launchUrl,
                      child: const Text('Get a free key at Google AI Studio ↗', style: TextStyle(color: kTeal, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              NeonButton(text: "LFG 🚀", isLoading: _isValidating, onPressed: _finish),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PROFILE SCREEN — Fully Editable
// ==========================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _apiCtrl = TextEditingController();
  final _apiCtrl2 = TextEditingController();
  final _apiCtrl3 = TextEditingController();
  
  // Biometrics
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _goalWeightCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String _gender = 'male';
  String _activity = 'sedentary';
  String _unitSystem = 'metric';

  bool _showApiKey = false;
  bool _showApiKey2 = false;
  bool _showApiKey3 = false;
  bool _isRecalculating = false;
  bool _autoRecalculate = false;
  bool _healthConnected = false;
  bool _requestingHealthPermission = false;

  final _conditions = [
    'None', 'Type 2 Diabetes', 'Type 1 Diabetes', 'Hypertension',
    'High Cholesterol', 'Celiac Disease', 'Lactose Intolerance', 'Nut Allergy',
  ];
  final _goals = [
    'Lose Weight', 'Maintain Weight', 'Build Muscle', 'Improve Energy',
    'Better Heart Health', 'Manage Blood Sugar', 'Reduce Inflammation',
  ];

  Set<String> _selectedConditions = {'None'};
  Set<String> _selectedGoals = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkHealthConnection();
  }

  Future<void> _checkHealthConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final connected = prefs.getBool('health_connected') ?? false;
    if (mounted) {
      setState(() => _healthConnected = connected);
    }
  }

  Future<void> _connectAppleHealth() async {
    setState(() => _requestingHealthPermission = true);
    try {
      final authorized = await HealthService().requestPermissions();
      if (authorized) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('health_connected', true);
        if (mounted) {
          setState(() => _healthConnected = true);
          showCupertinoDialog(
            context: context,
            builder: (_) => CupertinoAlertDialog(
              title: const Text('Connected! ✅'),
              content: const Text('Apple Health is now connected. Your fitness data will sync automatically.'),
              actions: [CupertinoDialogAction(child: const Text('Great'), onPressed: () => Navigator.pop(context))],
            ),
          );
        }
      } else {
        if (mounted) {
          showCupertinoDialog(
            context: context,
            builder: (_) => CupertinoAlertDialog(
              title: const Text('Permission Denied'),
              content: const Text('Apple Health permissions are required to sync your fitness data. Please enable them in Settings.'),
              actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(context))],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Could not connect to Apple Health: $e'),
            actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(context))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requestingHealthPermission = false);
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? 'Bestie';
    final apiKey = prefs.getString('api_key') ?? '';
    final apiKey2 = prefs.getString('api_key_2') ?? '';
    final apiKey3 = prefs.getString('api_key_3') ?? '';
    final condStr = prefs.getString('conditions') ?? 'None';
    final goalStr = prefs.getString('goals') ?? '';

    _nameCtrl.text = name;
    _apiCtrl.text = apiKey;
    _apiCtrl2.text = apiKey2;
    _apiCtrl3.text = apiKey3;
    _heightCtrl.text = (prefs.getDouble('height_cm') ?? 170.0).toStringAsFixed(0);
    _weightCtrl.text = (prefs.getDouble('weight_kg') ?? 70.0).toStringAsFixed(1);
    _goalWeightCtrl.text = (prefs.getDouble('goal_weight_kg') ?? 70.0).toStringAsFixed(1);
    _ageCtrl.text = (prefs.getInt('age') ?? 30).toString();
    
    final loadedConds = condStr.split(', ').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final loadedGoals = goalStr.split(', ').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();

    setState(() {
      _selectedConditions = loadedConds.isEmpty ? {'None'} : loadedConds;
      _selectedGoals = loadedGoals;
      _gender = prefs.getString('gender') ?? 'male';
      _activity = prefs.getString('activity_level') ?? 'sedentary';
      _unitSystem = prefs.getString('unit_system') ?? 'metric';
      _autoRecalculate = prefs.getBool('auto_recalculate') ?? false;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _nameCtrl.text.trim().isEmpty ? 'Bestie' : _nameCtrl.text.trim());
    await prefs.setString('api_key', _apiCtrl.text.trim());
    await prefs.setString('api_key_2', _apiCtrl2.text.trim());
    await prefs.setString('api_key_3', _apiCtrl3.text.trim());
    final conds = _selectedConditions.where((c) => c != 'None').join(', ');
    await prefs.setString('conditions', conds.isEmpty ? 'None' : conds);
    await prefs.setString('goals', _selectedGoals.join(', '));
    
    await prefs.setDouble('height_cm', double.tryParse(_heightCtrl.text) ?? 170.0);
    await prefs.setDouble('weight_kg', double.tryParse(_weightCtrl.text) ?? 70.0);
    await prefs.setDouble('goal_weight_kg', double.tryParse(_goalWeightCtrl.text) ?? 70.0);
    await prefs.setInt('age', int.tryParse(_ageCtrl.text) ?? 30);
    await prefs.setString('gender', _gender);
    await prefs.setString('activity_level', _activity);
    await prefs.setString('unit_system', _unitSystem);
    await prefs.setBool('auto_recalculate', _autoRecalculate);

    // Reload API keys in the manager
    await ApiKeyManager().loadApiKeys();

    if (mounted) {
      showCupertinoDialog(
        context: context,
        builder: (_) => CupertinoAlertDialog(
          title: const Text('Saved! ✅'),
          content: const Text('Your profile has been updated.'),
          actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(context))],
        ),
      );
    }
  }

  Future<void> _recalculateGoals() async {
    setState(() => _isRecalculating = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final bio = BiometricProfile(
        heightCm: prefs.getDouble('height_cm') ?? 170.0,
        weightKg: prefs.getDouble('weight_kg') ?? 70.0,
        goalWeightKg: prefs.getDouble('goal_weight_kg') ?? 70.0,
        initialWeightKg: prefs.getDouble('initial_weight_kg') ?? 70.0,
        age: prefs.getInt('age') ?? 30,
        gender: prefs.getString('gender') ?? 'other',
        activityLevel: prefs.getString('activity_level') ?? 'sedentary',
        unitSystem: prefs.getString('unit_system') ?? 'metric',
      );
      final conds = prefs.getString('conditions') ?? '';
      final goals = prefs.getString('goals') ?? '';
      await GoalEngine.computeGoals(bio, conds, goals);
      
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Goals Recalculated 🎯'),
            content: const Text('Your nutritional targets have been updated based on your profile.'),
            actions: [CupertinoDialogAction(child: const Text('Awesome'), onPressed: () => Navigator.pop(context))],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text(e.toString()),
            actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(context))],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRecalculating = false);
    }
  }

  Future<void> _resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) Navigator.of(context, rootNavigator: true).pushReplacement(CupertinoPageRoute(builder: (_) => const OnboardingScreen()));
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kNeon : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? kNeon : kBorder),
        ),
        child: Text(label, style: TextStyle(color: selected ? kBg : CupertinoColors.white, fontWeight: FontWeight.bold, fontSize: 12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CupertinoPageScaffold(
        backgroundColor: kBg,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text("PROFILE", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: CupertinoColors.white)),
              const SizedBox(height: 28),

              // NAME
              BentoCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('YOUR NAME', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _nameCtrl,
                    placeholder: 'Your name',
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: CupertinoColors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    decoration: const BoxDecoration(),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // API KEYS SECTION
              const ApiUsageIndicator(),
              const SizedBox(height: 14),
              
              BentoCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('PRIMARY API KEY', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(() => _showApiKey = !_showApiKey),
                        child: Icon(_showApiKey ? CupertinoIcons.eye_slash : CupertinoIcons.eye, color: CupertinoColors.systemGrey, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _apiCtrl,
                    placeholder: 'AIzaSy...',
                    obscureText: !_showApiKey,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
                    decoration: const BoxDecoration(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.info_circle, color: kTeal, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Get your free API key from aistudio.google.com',
                            style: TextStyle(color: kTeal, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // BACKUP API KEY 2
              BentoCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('BACKUP API KEY 2 (OPTIONAL)', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(() => _showApiKey2 = !_showApiKey2),
                        child: Icon(_showApiKey2 ? CupertinoIcons.eye_slash : CupertinoIcons.eye, color: CupertinoColors.systemGrey, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _apiCtrl2,
                    placeholder: 'AIzaSy... (from different project)',
                    obscureText: !_showApiKey2,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
                    decoration: const BoxDecoration(),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // BACKUP API KEY 3
              BentoCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('BACKUP API KEY 3 (OPTIONAL)', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(() => _showApiKey3 = !_showApiKey3),
                        child: Icon(_showApiKey3 ? CupertinoIcons.eye_slash : CupertinoIcons.eye, color: CupertinoColors.systemGrey, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CupertinoTextField(
                    controller: _apiCtrl3,
                    placeholder: 'AIzaSy... (from different project)',
                    obscureText: !_showApiKey3,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
                    decoration: const BoxDecoration(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kNeon.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(CupertinoIcons.lightbulb, color: kNeon, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Add 2-3 API keys from different Google Cloud projects to multiply your daily limit to 2,000-3,000 requests/day',
                            style: TextStyle(color: kNeon, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // CONDITIONS
              BentoCard(
                glowColor: const Color(0x22FF0055),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('HEALTH CONDITIONS', style: TextStyle(color: kPink, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Wrap(
                    children: _conditions.map((c) => _chip(c, _selectedConditions.contains(c), () {
                      setState(() {
                        if (c == 'None') {
                          _selectedConditions = {'None'};
                        } else {
                          _selectedConditions.remove('None');
                          if (_selectedConditions.contains(c)) _selectedConditions.remove(c);
                          else _selectedConditions.add(c);
                          if (_selectedConditions.isEmpty) _selectedConditions.add('None');
                        }
                      });
                    })).toList(),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // GOALS
              BentoCard(
                glowColor: const Color(0x2200FFD1),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('YOUR GOALS', style: TextStyle(color: kTeal, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Wrap(
                    children: _goals.map((g) => _chip(g, _selectedGoals.contains(g), () {
                      setState(() {
                        if (_selectedGoals.contains(g)) _selectedGoals.remove(g);
                        else _selectedGoals.add(g);
                      });
                    })).toList(),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // BIOMETRICS
              BentoCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('BIOMETRICS', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    CupertinoSlidingSegmentedControl<String>(
                      groupValue: _unitSystem,
                      children: const {'metric': Text('  Metric  ', style: TextStyle(fontSize: 12)), 'imperial': Text(' Imperial ', style: TextStyle(fontSize: 12))},
                      onValueChanged: (v) => setState(() => _unitSystem = v!),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  
                  Row(children: [
                    Expanded(child: _buildBioField('AGE', _ageCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildBioField('HEIGHT', _heightCtrl)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _buildBioField('WEIGHT', _weightCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildBioField('GOAL WT', _goalWeightCtrl)),
                  ]),
                  
                  const SizedBox(height: 16),
                  const Text('GENDER', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  CupertinoSlidingSegmentedControl<String>(
                    groupValue: _gender,
                    children: const {'male': Text('Male'), 'female': Text('Female'), 'other': Text('Other')},
                    onValueChanged: (v) => setState(() => _gender = v!),
                  ),
                  
                  const SizedBox(height: 16),
                  const Text('ACTIVITY LEVEL', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: CupertinoPicker(
                      itemExtent: 32,
                      scrollController: FixedExtentScrollController(initialItem: ['sedentary','light','moderate','active','very_active'].indexOf(_activity)),
                      onSelectedItemChanged: (i) => setState(() => _activity = ['sedentary','light','moderate','active','very_active'][i]),
                      children: ['sedentary','light','moderate','active','very_active'].map((e) => Center(child: Text(e.toUpperCase().replaceAll('_', ' '), style: const TextStyle(color: CupertinoColors.white, fontSize: 14)))).toList(),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),

              // APPLE HEALTH CONNECTION
              BentoCard(
                glowColor: _healthConnected ? const Color(0x2200FF00) : const Color(0x22FF9500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('APPLE HEALTH & FITNESS', style: TextStyle(color: CupertinoColors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                _healthConnected 
                                  ? '✅ Connected - Your health data is syncing'
                                  : '⚠️ Not connected - Tap to enable',
                                style: TextStyle(
                                  color: _healthConnected ? const Color(0xFF30D158) : CupertinoColors.systemGrey,
                                  fontSize: 11
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                    if (!_healthConnected) ...[
                      const SizedBox(height: 12),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: _requestingHealthPermission ? null : _connectAppleHealth,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_requestingHealthPermission)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CupertinoActivityIndicator(),
                              )
                            else
                              const Icon(CupertinoIcons.heart_fill, size: 16, color: CupertinoColors.destructiveRed),
                            const SizedBox(width: 8),
                            Text(
                              _requestingHealthPermission ? 'Connecting...' : 'Connect Apple Health',
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // AUTOMATION
              BentoCard(
                glowColor: const Color(0x22FFFFFF),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('AUTO RECALCULATE GOALS', style: TextStyle(color: CupertinoColors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('Daily AI check based on last 7-10 days', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11)),
                      ],
                    ),
                    CupertinoSwitch(
                      value: _autoRecalculate,
                      activeColor: kNeon,
                      onChanged: (val) => setState(() => _autoRecalculate = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              NeonButton(text: 'Save Changes ✓', onPressed: _save),
              const SizedBox(height: 14),
              NeonButton(text: 'Recalculate AI Goals 🎯', onPressed: _recalculateGoals, color: kTeal, isLoading: _isRecalculating),
              const SizedBox(height: 14),
              CupertinoButton(
                onPressed: _resetAll,
                child: const Text('Reset App & All Data', style: TextStyle(color: CupertinoColors.destructiveRed, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBioField(String label, TextEditingController ctrl) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      CupertinoTextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: CupertinoColors.white, fontSize: 14, fontWeight: FontWeight.bold),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8)),
      ),
    ]);
  }
}
