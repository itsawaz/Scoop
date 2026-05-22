import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'models.dart';
import 'widgets.dart';
import 'tabs.dart';

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
  final _conditionsController = TextEditingController();
  final _goalsController = TextEditingController();

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
    if (mounted) Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const ApiKeyScreen()));
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
      await prefs.setString('api_key', _apiController.text.trim());
      if (!prefs.containsKey('history')) await prefs.setStringList('history', []);
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
  bool _showApiKey = false;

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
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('name') ?? 'Bestie';
    final apiKey = prefs.getString('api_key') ?? '';
    final condStr = prefs.getString('conditions') ?? 'None';
    final goalStr = prefs.getString('goals') ?? '';

    _nameCtrl.text = name;
    _apiCtrl.text = apiKey;

    final loadedConds = condStr.split(', ').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final loadedGoals = goalStr.split(', ').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();

    setState(() {
      _selectedConditions = loadedConds.isEmpty ? {'None'} : loadedConds;
      _selectedGoals = loadedGoals;
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', _nameCtrl.text.trim().isEmpty ? 'Bestie' : _nameCtrl.text.trim());
    await prefs.setString('api_key', _apiCtrl.text.trim());
    final conds = _selectedConditions.where((c) => c != 'None').join(', ');
    await prefs.setString('conditions', conds.isEmpty ? 'None' : conds);
    await prefs.setString('goals', _selectedGoals.join(', '));

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

              // API KEY
              BentoCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('GEMINI API KEY', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: _apiCtrl,
                        placeholder: 'AIzaSy...',
                        obscureText: !_showApiKey,
                        textInputAction: TextInputAction.done,
                        style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
                        decoration: const BoxDecoration(),
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.only(left: 8),
                      onPressed: () => setState(() => _showApiKey = !_showApiKey),
                      child: Icon(_showApiKey ? CupertinoIcons.eye_slash : CupertinoIcons.eye, color: CupertinoColors.systemGrey, size: 20),
                    )
                  ]),
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
              const SizedBox(height: 28),

              NeonButton(text: 'Save Changes ✓', onPressed: _save),
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
}
