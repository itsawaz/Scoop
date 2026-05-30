import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  // === Saved Meals ===
  Future<List<SavedMeal>> getSavedMeals() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_meals') ?? [];
    return list.map((e) => SavedMeal.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveMealToLibrary(SavedMeal meal) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_meals') ?? [];
    list.add(jsonEncode(meal.toJson()));
    await prefs.setStringList('saved_meals', list);
  }

  Future<void> incrementSavedMealUse(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_meals') ?? [];
    final meals = list.map((e) => SavedMeal.fromJson(jsonDecode(e))).toList();
    for (int i = 0; i < meals.length; i++) {
      if (meals[i].id == id) {
        meals[i].useCount += 1;
        list[i] = jsonEncode(meals[i].toJson());
        await prefs.setStringList('saved_meals', list);
        break;
      }
    }
  }

  // === Weight Log ===
  Future<List<WeightEntry>> getWeightLog() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('weight_log') ?? [];
    return list.map((e) => WeightEntry.fromJson(jsonDecode(e))).toList();
  }

  Future<void> addWeightLog(WeightEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('weight_log') ?? [];
    // Check if logged today already to replace or add
    final today = entry.timestamp.toIso8601String().split('T').first;
    bool found = false;
    for (int i = 0; i < list.length; i++) {
      final existing = WeightEntry.fromJson(jsonDecode(list[i]));
      if (existing.timestamp.toIso8601String().split('T').first == today) {
        list[i] = jsonEncode(entry.toJson());
        found = true;
        break;
      }
    }
    if (!found) {
      list.add(jsonEncode(entry.toJson()));
    }
    await prefs.setStringList('weight_log', list);
    
    // Also update current profile weight
    await prefs.setDouble('weight_kg', entry.weightKg);
  }

  // === Supplement Log ===
  Future<List<SupplementEntry>> getSupplementLog() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('supplement_log') ?? [];
    return list.map((e) => SupplementEntry.fromJson(jsonDecode(e))).toList();
  }

  Future<void> addSupplementLog(SupplementEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('supplement_log') ?? [];
    list.add(jsonEncode(entry.toJson()));
    await prefs.setStringList('supplement_log', list);
  }

  Future<void> deleteSupplementLog(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('supplement_log') ?? [];
    list.removeWhere((e) {
      try {
        return SupplementEntry.fromJson(jsonDecode(e)).id == id;
      } catch (_) { return false; }
    });
    await prefs.setStringList('supplement_log', list);
  }

  // === Saved Supplements ===
  Future<List<SavedSupplement>> getSavedSupplements() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_supplements') ?? [];
    return list.map((e) => SavedSupplement.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveSupplementToLibrary(SavedSupplement supplement) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_supplements') ?? [];
    list.add(jsonEncode(supplement.toJson()));
    await prefs.setStringList('saved_supplements', list);
  }

  Future<void> incrementSavedSupplementUse(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('saved_supplements') ?? [];
    final sups = list.map((e) => SavedSupplement.fromJson(jsonDecode(e))).toList();
    for (int i = 0; i < sups.length; i++) {
      if (sups[i].id == id) {
        sups[i].useCount += 1;
        list[i] = jsonEncode(sups[i].toJson());
        await prefs.setStringList('saved_supplements', list);
        break;
      }
    }
  }
}
