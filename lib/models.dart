import 'dart:convert';

class UserProfile {
  final String name;
  final String conditions; // e.g. "Diabetes, Hypertension"
  final String goals; // e.g. "Lose weight, Build muscle"
  final String apiKey;

  UserProfile({required this.name, required this.conditions, required this.goals, required this.apiKey});

  Map<String, dynamic> toJson() => {
    'name': name,
    'conditions': conditions,
    'goals': goals,
    'api_key': apiKey,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] ?? '',
    conditions: json['conditions'] ?? '',
    goals: json['goals'] ?? '',
    apiKey: json['api_key'] ?? '',
  );
}

class NutritionData {
  final int calories;
  final double protein;    // grams
  final double carbs;      // grams
  final double fat;        // grams
  final double sugar;      // grams
  final double fiber;      // grams
  final double sodium;     // mg
  final double vitaminC;   // mg
  final double vitaminD;   // mcg
  final double calcium;    // mg
  final double iron;       // mg
  final String reasoning;
  final String medicalAlert; // empty if none
  final String foodName;

  NutritionData({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.sugar,
    required this.fiber,
    required this.sodium,
    required this.vitaminC,
    required this.vitaminD,
    required this.calcium,
    required this.iron,
    required this.reasoning,
    required this.medicalAlert,
    required this.foodName,
  });

  Map<String, dynamic> toJson() => {
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'sugar': sugar,
    'fiber': fiber,
    'sodium': sodium,
    'vitaminC': vitaminC,
    'vitaminD': vitaminD,
    'calcium': calcium,
    'iron': iron,
    'reasoning': reasoning,
    'medicalAlert': medicalAlert,
    'foodName': foodName,
  };

  factory NutritionData.fromJson(Map<String, dynamic> json) => NutritionData(
    calories: (json['calories'] ?? 0) is int ? json['calories'] : (json['calories'] as double).round(),
    protein: (json['protein'] ?? 0.0).toDouble(),
    carbs: (json['carbs'] ?? 0.0).toDouble(),
    fat: (json['fat'] ?? 0.0).toDouble(),
    sugar: (json['sugar'] ?? 0.0).toDouble(),
    fiber: (json['fiber'] ?? 0.0).toDouble(),
    sodium: (json['sodium'] ?? 0.0).toDouble(),
    vitaminC: (json['vitaminC'] ?? 0.0).toDouble(),
    vitaminD: (json['vitaminD'] ?? 0.0).toDouble(),
    calcium: (json['calcium'] ?? 0.0).toDouble(),
    iron: (json['iron'] ?? 0.0).toDouble(),
    reasoning: json['reasoning'] ?? '',
    medicalAlert: json['medicalAlert'] ?? '',
    foodName: json['foodName'] ?? 'Meal',
  );

  factory NutritionData.zero() => NutritionData(
    calories: 0, protein: 0, carbs: 0, fat: 0, sugar: 0, fiber: 0,
    sodium: 0, vitaminC: 0, vitaminD: 0, calcium: 0, iron: 0,
    reasoning: '', medicalAlert: '', foodName: '',
  );

  NutritionData operator +(NutritionData other) => NutritionData(
    calories: calories + other.calories,
    protein: protein + other.protein,
    carbs: carbs + other.carbs,
    fat: fat + other.fat,
    sugar: sugar + other.sugar,
    fiber: fiber + other.fiber,
    sodium: sodium + other.sodium,
    vitaminC: vitaminC + other.vitaminC,
    vitaminD: vitaminD + other.vitaminD,
    calcium: calcium + other.calcium,
    iron: iron + other.iron,
    reasoning: reasoning,
    medicalAlert: medicalAlert,
    foodName: foodName,
  );
}

class MealEntry {
  final String id;
  final DateTime timestamp;
  final NutritionData nutrition;
  final String note;

  MealEntry({required this.id, required this.timestamp, required this.nutrition, required this.note});

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'nutrition': nutrition.toJson(),
    'note': note,
  };

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    // Support legacy entries that only have calories
    NutritionData nutrition;
    if (json.containsKey('nutrition')) {
      nutrition = NutritionData.fromJson(json['nutrition']);
    } else {
      nutrition = NutritionData(
        calories: json['calories'] ?? 0,
        protein: 0, carbs: 0, fat: 0, sugar: 0, fiber: 0,
        sodium: 0, vitaminC: 0, vitaminD: 0, calcium: 0, iron: 0,
        reasoning: 'Legacy entry', medicalAlert: '', foodName: json['note'] ?? 'Meal',
      );
    }
    return MealEntry(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      nutrition: nutrition,
      note: json['note'] ?? '',
    );
  }
}
