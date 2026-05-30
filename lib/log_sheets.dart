import 'dart:io';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'models.dart';
import 'widgets.dart';
import 'services/storage_service.dart';
import 'services/health_service.dart';
import 'services/api_service.dart';
import 'state.dart';

// ==========================================
// SAVED MEALS PICKER
// ==========================================
class SavedMealsPickerScreen extends StatefulWidget {
  final VoidCallback onLogged;
  const SavedMealsPickerScreen({super.key, required this.onLogged});

  @override
  State<SavedMealsPickerScreen> createState() => _SavedMealsPickerScreenState();
}

class _SavedMealsPickerScreenState extends State<SavedMealsPickerScreen> {
  final _searchCtrl = TextEditingController();
  List<SavedMeal> _allMeals = [];
  List<SavedMeal> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeals();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeals() async {
    final meals = await StorageService().getSavedMeals();
    meals.sort((a, b) => b.useCount.compareTo(a.useCount));
    setState(() { _allMeals = meals; _filtered = meals; _isLoading = false; });
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allMeals
          : _allMeals.where((m) =>
              m.nutrition.foodName.toLowerCase().contains(q) ||
              m.aiDescription.toLowerCase().contains(q) ||
              m.chatContext.toLowerCase().contains(q)).toList();
    });
  }

  void _logMeal(SavedMeal meal) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final sel = globalSelectedDate.value;
    final ts = DateTime(sel.year, sel.month, sel.day, now.hour, now.minute, now.second);
    final entry = MealEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: ts,
      nutrition: meal.nutrition,
      note: meal.nutrition.foodName,
      savedMealId: meal.id,
    );
    final historyList = prefs.getStringList('history') ?? [];
    historyList.add(jsonEncode(entry.toJson()));
    await prefs.setStringList('history', historyList);
    await StorageService().incrementSavedMealUse(meal.id);
    widget.onLogged();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: CupertinoPageScaffold(
        backgroundColor: kBg,
        navigationBar: const CupertinoNavigationBar(
          backgroundColor: Color(0x00000000),
          border: null,
          middle: Text('Saved Meals', style: TextStyle(color: CupertinoColors.white)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: CupertinoSearchTextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: CupertinoColors.white),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CupertinoActivityIndicator())
                    : _filtered.isEmpty
                        ? const Center(child: Text('No saved meals found.', style: TextStyle(color: CupertinoColors.systemGrey)))
                        : ListView.builder(
                            itemCount: _filtered.length,
                            padding: const EdgeInsets.all(16),
                            itemBuilder: (context, index) {
                              final m = _filtered[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16)),
                                child: CupertinoButton(
                                  padding: const EdgeInsets.all(16),
                                  onPressed: () => _logMeal(m),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                      Expanded(child: Text(m.nutrition.foodName, style: const TextStyle(color: CupertinoColors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: kNeon.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                                        child: Text('${m.useCount} uses', style: const TextStyle(color: kNeon, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ]),
                                    const SizedBox(height: 6),
                                    Text(m.aiDescription, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 13, height: 1.4)),
                                    const SizedBox(height: 10),
                                    Row(children: [
                                      Text('${m.nutrition.calories} kcal', style: const TextStyle(color: kNeon, fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(width: 12),
                                      Text('${m.nutrition.protein.round()}g protein', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
                                    ]),
                                  ]),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SAVED SUPPLEMENTS PICKER
// ==========================================
class SavedSupplementsPickerScreen extends StatefulWidget {
  final VoidCallback onLogged;
  const SavedSupplementsPickerScreen({super.key, required this.onLogged});

  @override
  State<SavedSupplementsPickerScreen> createState() => _SavedSupplementsPickerScreenState();
}

class _SavedSupplementsPickerScreenState extends State<SavedSupplementsPickerScreen> {
  List<SavedSupplement> _supps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await StorageService().getSavedSupplements();
    setState(() { _supps = data; _isLoading = false; });
  }

  void _log(SavedSupplement s) async {
    final now = DateTime.now();
    final sel = globalSelectedDate.value;
    final ts = DateTime(sel.year, sel.month, sel.day, now.hour, now.minute, now.second);
    final entry = SupplementEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: ts,
      type: s.type,
      brand: s.brand,
      proteinG: s.proteinG,
      carbsG: s.carbsG,
      fatG: s.fatG,
      servingG: s.servingG,
      calories: s.calories,
      note: s.note,
    );
    await StorageService().addSupplementLog(entry);
    if (entry.calories > 0) await HealthService().writeCalories(entry.calories.toDouble(), entry.timestamp);
    widget.onLogged();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kBg,
      navigationBar: const CupertinoNavigationBar(backgroundColor: Color(0x00000000), border: null, middle: Text('Saved Supplements', style: TextStyle(color: CupertinoColors.white))),
      child: SafeArea(
        child: _isLoading ? const Center(child: CupertinoActivityIndicator()) : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _supps.length,
          itemBuilder: (ctx, i) {
            final s = _supps[i];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16)),
              child: CupertinoButton(
                onPressed: () => _log(s),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.brand, style: const TextStyle(color: CupertinoColors.white, fontWeight: FontWeight.bold)),
                  Text('${s.calories} kcal • ${s.type}', style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 13)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==========================================
// WEIGHT LOG SHEET
// ==========================================
void showWeightLogSheet(BuildContext context, VoidCallback onLogged) {
  showCupertinoModalPopup(
    context: context,
    builder: (BuildContext context) => _WeightLogSheet(onLogged: onLogged),
  );
}

class _WeightLogSheet extends StatefulWidget {
  final VoidCallback onLogged;
  const _WeightLogSheet({required this.onLogged});

  @override
  State<_WeightLogSheet> createState() => _WeightLogSheetState();
}

class _WeightLogSheetState extends State<_WeightLogSheet> {
  final _weightCtrl = TextEditingController();
  String _note = 'Morning fasted';
  String _unit = 'metric';

  @override
  void initState() {
    super.initState();
    _loadInitData();
  }

  void _loadInitData() async {
    final prefs = await SharedPreferences.getInstance();
    final unit = prefs.getString('unit_system') ?? 'metric';
    final currentWeight = prefs.getDouble('weight_kg') ?? 70.0;
    if (mounted) {
      setState(() {
        _unit = unit;
        _weightCtrl.text = unit == 'imperial'
            ? (currentWeight * 2.20462).toStringAsFixed(1)
            : currentWeight.toStringAsFixed(1);
      });
    }
  }

  void _save() async {
    final val = double.tryParse(_weightCtrl.text);
    if (val == null || val <= 0) return;
    final weightKg = _unit == 'imperial' ? val / 2.20462 : val;
    final now = DateTime.now();
    final sel = globalSelectedDate.value;
    final ts = DateTime(sel.year, sel.month, sel.day, now.hour, now.minute, now.second);
    final entry = WeightEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: ts,
      weightKg: weightKg,
      note: _note,
      unitSystem: _unit,
    );
    await StorageService().addWeightLog(entry);
    await HealthService().writeWeight(weightKg, entry.timestamp);
    widget.onLogged();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: 420,
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Log Today\'s Weight', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: CupertinoColors.white), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              Center(
                child: SizedBox(
                  width: 180,
                  child: CupertinoTextField(
                    controller: _weightCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, color: kNeon),
                    decoration: const BoxDecoration(),
                    suffix: Text(_unit == 'imperial' ? ' lbs' : ' kg', style: const TextStyle(fontSize: 20, color: CupertinoColors.systemGrey)),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text('Note', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Morning fasted', 'Post-workout', 'Evening', 'Other'].map((note) {
                    final sel = _note == note;
                    return GestureDetector(
                      onTap: () => setState(() => _note = note),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? kNeon.withValues(alpha: 0.2) : kCard,
                          border: Border.all(color: sel ? kNeon : kBorder),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(note, style: TextStyle(color: sel ? kNeon : CupertinoColors.white, fontSize: 14)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Spacer(),
              NeonButton(text: 'Save Weight', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SUPPLEMENT LOG SHEET – 3 INPUT MODES
// ==========================================
void showSupplementLogSheet(BuildContext context, VoidCallback onLogged) {
  showCupertinoModalPopup(
    context: context,
    builder: (BuildContext context) => _SupplementLogSheet(onLogged: onLogged),
  );
}

class _SupplementLogSheet extends StatefulWidget {
  final VoidCallback onLogged;
  const _SupplementLogSheet({required this.onLogged});

  @override
  State<_SupplementLogSheet> createState() => _SupplementLogSheetState();
}

class _SupplementLogSheetState extends State<_SupplementLogSheet> {
  // Mode: 'manual', 'scan', 'search'
  String _mode = 'manual';
  String _type = 'Whey';
  bool _isBusy = false;
  bool _saveToLibrary = false;

  // Manual fields
  final _brandCtrl = TextEditingController(text: 'ON Gold Standard Whey');
  final _servingCtrl = TextEditingController(text: '30');
  final _proteinCtrl = TextEditingController(text: '24');
  final _carbsCtrl = TextEditingController(text: '3');
  final _fatCtrl = TextEditingController(text: '1');
  final _caloriesCtrl = TextEditingController(text: '120');

  // Search
  final _searchCtrl = TextEditingController();
  Map<String, dynamic>? _searchResult;

  // Scan
  final _picker = ImagePicker();
  XFile? _scannedImage;
  Map<String, dynamic>? _scanResult;

  @override
  void dispose() {
    for (final c in [_brandCtrl, _servingCtrl, _proteinCtrl, _carbsCtrl, _fatCtrl, _caloriesCtrl, _searchCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  // --- SEARCH BY NAME ---
  Future<void> _searchByName() async {
    final name = _searchCtrl.text.trim();
    if (name.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _isBusy = true; _searchResult = null; });

    try {
      final apiService = ApiService();
      final model = await apiService.getModel('supplement_lookup');
      
      final prompt = '''
Lookup nutritional information for this supplement product: "$name"
Return ONLY this JSON (no markdown):
{
  "brand": "Full Product Name",
  "type": "Whey / Creatine / BCAA / Vitamin / Other",
  "proteinG": 24.0,
  "carbsG": 3.0,
  "fatG": 1.0,
  "servingG": 30.4,
  "calories": 120,
  "found": true
}
If the product is not recognizable, set "found": false and estimate based on the category.
''';
      
      final response = await model.generateContent([Content.text(prompt)]);
      await apiService.recordUsage();
      
      final raw = response.text?.trim() ?? '{}';
      String jsonStr = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final first = jsonStr.indexOf('{');
      final last = jsonStr.lastIndexOf('}');
      if (first != -1 && last != -1) jsonStr = jsonStr.substring(first, last + 1);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (mounted) {
        setState(() { _searchResult = data; _isBusy = false; });
        // Autofill manual fields
        _brandCtrl.text = data['brand'] ?? name;
        _proteinCtrl.text = (data['proteinG'] ?? 0).toStringAsFixed(1);
        _carbsCtrl.text = (data['carbsG'] ?? 0).toStringAsFixed(1);
        _fatCtrl.text = (data['fatG'] ?? 0).toStringAsFixed(1);
        _servingCtrl.text = (data['servingG'] ?? 0).toStringAsFixed(1);
        _caloriesCtrl.text = (data['calories'] ?? 0).toString();
        final t = (data['type'] ?? 'Other').toString();
        if (['Whey', 'Creatine', 'BCAA', 'Vitamin', 'Other'].contains(t)) {
          _type = t;
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isBusy = false);
      _showError('Search failed: $e');
    }
  }

  // --- SCAN LABEL ---
  Future<void> _scanLabel(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    setState(() { _scannedImage = picked; _isBusy = true; _scanResult = null; });

    try {
      final apiService = ApiService();
      final model = await apiService.getModel('supplement_lookup', hasImage: true);
      final bytes = await File(picked.path).readAsBytes();

      final prompt = '''
This is a nutrition label from a supplement product.
Extract the nutritional information per serving and return ONLY this JSON:
{
  "brand": "Product Name",
  "type": "Whey / Creatine / BCAA / Vitamin / Other",
  "proteinG": 24.0,
  "carbsG": 3.0,
  "fatG": 1.0,
  "servingG": 30.4,
  "calories": 120
}
''';
      
      final response = await model.generateContent([
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', bytes),
        ])
      ]);
      await apiService.recordUsage();
      
      final raw = response.text?.trim() ?? '{}';
      String jsonStr = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      final first = jsonStr.indexOf('{');
      final last = jsonStr.lastIndexOf('}');
      if (first != -1 && last != -1) jsonStr = jsonStr.substring(first, last + 1);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      if (mounted) {
        setState(() { _scanResult = data; _isBusy = false; });
        // Autofill
        _brandCtrl.text = data['brand'] ?? '';
        _proteinCtrl.text = (data['proteinG'] ?? 0).toStringAsFixed(1);
        _carbsCtrl.text = (data['carbsG'] ?? 0).toStringAsFixed(1);
        _fatCtrl.text = (data['fatG'] ?? 0).toStringAsFixed(1);
        _servingCtrl.text = (data['servingG'] ?? 0).toStringAsFixed(1);
        _caloriesCtrl.text = (data['calories'] ?? 0).toString();
      }
    } catch (e) {
      if (mounted) setState(() => _isBusy = false);
      _showError('Scan failed: $e');
    }
  }

  void _showError(String msg) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(msg),
        actions: [CupertinoDialogAction(child: const Text('OK'), onPressed: () => Navigator.pop(context))],
      ),
    );
  }

  void _save() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final sel = globalSelectedDate.value;
    final ts = DateTime(sel.year, sel.month, sel.day, now.hour, now.minute, now.second);
    final entry = SupplementEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: ts,
      type: _type,
      brand: _brandCtrl.text,
      proteinG: double.tryParse(_proteinCtrl.text) ?? 0.0,
      carbsG: double.tryParse(_carbsCtrl.text) ?? 0.0,
      fatG: double.tryParse(_fatCtrl.text) ?? 0.0,
      servingG: double.tryParse(_servingCtrl.text) ?? 0.0,
      calories: int.tryParse(_caloriesCtrl.text) ?? 0,
      note: '',
    );
    await StorageService().addSupplementLog(entry);
    
    if (_saveToLibrary) {
      final savedSup = SavedSupplement(
        id: entry.id,
        savedAt: DateTime.now(),
        type: entry.type,
        brand: entry.brand,
        proteinG: entry.proteinG,
        carbsG: entry.carbsG,
        fatG: entry.fatG,
        servingG: entry.servingG,
        calories: entry.calories,
        note: entry.note,
      );
      await StorageService().saveSupplementToLibrary(savedSup);
    }
    
    if (entry.calories > 0) {
      await HealthService().writeCalories(entry.calories.toDouble(), entry.timestamp);
    }
    widget.onLogged();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Log Supplement', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: CupertinoColors.white)),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.push(context, CupertinoPageRoute(builder: (_) => SavedSupplementsPickerScreen(
                            onLogged: () {
                              widget.onLogged();
                              if (mounted) Navigator.pop(context); // close sheet
                            }
                          )));
                        },
                        child: const Text('Saved', style: TextStyle(color: kNeon, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                    // Mode toggle
                    Container(
                      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          _modeTab('✍️ Manual', 'manual'),
                          _modeTab('📷 Scan Label', 'scan'),
                          _modeTab('🔍 Search', 'search'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_mode == 'manual') _buildManualMode(),
                      if (_mode == 'scan') _buildScanMode(),
                      if (_mode == 'search') _buildSearchMode(),
                    ],
                  ),
                ),
              ),

              // Save button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: NeonButton(
                  text: 'Log Supplement',
                  onPressed: _isBusy ? null : _save,
                  isLoading: _isBusy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeTab(String label, String mode) {
    final selected = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kNeon.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: selected ? Border.all(color: kNeon) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? kNeon : CupertinoColors.systemGrey,
              fontSize: 12,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManualMode() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type chips
        const Text('TYPE', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['Whey', 'Creatine', 'BCAA', 'Vitamin', 'Other'].map((t) {
              final sel = _type == t;
              return GestureDetector(
                onTap: () => setState(() => _type = t),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? kNeon.withValues(alpha: 0.2) : kCard,
                    border: Border.all(color: sel ? kNeon : kBorder),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(t, style: TextStyle(color: sel ? kNeon : CupertinoColors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        _field('PRODUCT NAME / BRAND', _brandCtrl, isNum: false),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field('SERVING (g)', _servingCtrl)),
          const SizedBox(width: 10),
          Expanded(child: _field('CALORIES', _caloriesCtrl)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _field('PROTEIN (g)', _proteinCtrl)),
          const SizedBox(width: 10),
          Expanded(child: _field('CARBS (g)', _carbsCtrl)),
          const SizedBox(width: 10),
          Expanded(child: _field('FAT (g)', _fatCtrl)),
        ]),
      const SizedBox(height: 24),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Save to Library', style: TextStyle(color: CupertinoColors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          CupertinoSwitch(
            value: _saveToLibrary,
            activeColor: kNeon,
            onChanged: (val) {
              setState(() { _saveToLibrary = val; });
            },
          ),
        ],
      ),
      const SizedBox(height: 32),
    ],
  );
}

  Widget _buildScanMode() {
    return Column(
      children: [
        // Image preview
        GestureDetector(
          onTap: () => _scanLabel(ImageSource.camera),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorder),
            ),
            child: _scannedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(File(_scannedImage!.path), fit: BoxFit.cover, width: double.infinity),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('📷', style: TextStyle(fontSize: 48)),
                      SizedBox(height: 12),
                      Text('Tap to scan label with camera', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 14)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: CupertinoButton(
              color: kCard,
              borderRadius: BorderRadius.circular(14),
              onPressed: () => _scanLabel(ImageSource.camera),
              child: const Text('📷 Camera', style: TextStyle(color: kNeon, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: CupertinoButton(
              color: kCard,
              borderRadius: BorderRadius.circular(14),
              onPressed: () => _scanLabel(ImageSource.gallery),
              child: const Text('🖼 Gallery', style: TextStyle(color: kTeal, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        if (_isBusy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        if (_scanResult != null) ...[
          BentoCard(
            glowColor: const Color(0x3300FFD1),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('✅ LABEL READ SUCCESSFULLY', style: TextStyle(color: kTeal, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
              const SizedBox(height: 10),
              Text(_scanResult!['brand'] ?? '', style: const TextStyle(color: CupertinoColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                _pill('${_scanResult!['calories']} kcal', kNeon),
                const SizedBox(width: 8),
                _pill('${_scanResult!['proteinG']}g prot', const Color(0xFFFF9500)),
                const SizedBox(width: 8),
                _pill('${_scanResult!['carbsG']}g carbs', const Color(0xFF30D158)),
              ]),
              const SizedBox(height: 8),
              const Text('Fields auto-filled in Manual tab ↑', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
            ]),
          ),
        ],
        const SizedBox(height: 20),
        // Also show the manual fields for editing
        _buildManualMode(),
      ],
    );
  }

  Widget _buildSearchMode() {
    return Column(
      children: [
        Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16), border: Border.all(color: kBorder)),
              child: CupertinoTextField(
                controller: _searchCtrl,
                placeholder: 'e.g. MyProtein Impact Whey Chocolate',
                placeholderStyle: const TextStyle(color: Color(0xFF555555)),
                style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
                decoration: const BoxDecoration(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchByName(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _isBusy ? null : _searchByName,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: kNeon, borderRadius: BorderRadius.circular(14)),
              child: _isBusy
                  ? const CupertinoActivityIndicator(color: kBg, radius: 10)
                  : const Icon(CupertinoIcons.search, color: kBg, size: 22),
            ),
          ),
        ]),
        const SizedBox(height: 8),
        const Text('AI will look up the nutritional profile and auto-fill your log.',
            style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
        const SizedBox(height: 20),

        if (_searchResult != null) ...[
          BentoCard(
            glowColor: const Color(0x3300FFD1),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                (_searchResult!['found'] == true) ? '✅ FOUND IN DATABASE' : '⚠️ ESTIMATED (not found)',
                style: TextStyle(
                  color: _searchResult!['found'] == true ? kTeal : kPink,
                  fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              Text(_searchResult!['brand'] ?? '', style: const TextStyle(color: CupertinoColors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                _pill('${_searchResult!['calories']} kcal', kNeon),
                const SizedBox(width: 8),
                _pill('${_searchResult!['proteinG']}g prot', const Color(0xFFFF9500)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                _pill('${_searchResult!['carbsG']}g carbs', const Color(0xFF30D158)),
                const SizedBox(width: 8),
                _pill('${_searchResult!['fatG']}g fat', const Color(0xFF5E5CE6)),
              ]),
              const SizedBox(height: 8),
              const Text('Fields auto-filled below', style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 20),
          _buildManualMode(),
        ],
      ],
    );
  }

  Widget _pill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {bool isNum = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: CupertinoColors.systemGrey, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        CupertinoTextField(
          controller: ctrl,
          keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        ),
      ],
    );
  }
}

// Hack to resolve Colors reference
class Colors {
  static const transparent = Color(0x00000000);
}
