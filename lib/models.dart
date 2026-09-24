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
  final double protein;         // grams
  final double carbs;           // grams
  final double fat;             // grams
  final double sugar;           // grams
  final double fiber;           // grams
  final double sodium;          // mg
  final double vitaminC;        // mg
  final double vitaminD;        // mcg
  final double calcium;         // mg
  final double iron;            // mg
  
  // Extended nutrients
  final double saturatedFat;    // grams
  final double transFat;        // grams
  final double cholesterol;     // mg
  final double potassium;       // mg
  final double magnesium;       // mg
  final double zinc;            // mg
  final double vitaminA;        // mcg
  final double vitaminB6;       // mg
  final double vitaminB12;      // mcg
  final double folate;          // mcg
  final double phosphorus;      // mg
  final double iodine;          // mcg
  
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
    this.saturatedFat = 0.0,
    this.transFat = 0.0,
    this.cholesterol = 0.0,
    this.potassium = 0.0,
    this.magnesium = 0.0,
    this.zinc = 0.0,
    this.vitaminA = 0.0,
    this.vitaminB6 = 0.0,
    this.vitaminB12 = 0.0,
    this.folate = 0.0,
    this.phosphorus = 0.0,
    this.iodine = 0.0,
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
    'saturatedFat': saturatedFat,
    'transFat': transFat,
    'cholesterol': cholesterol,
    'potassium': potassium,
    'magnesium': magnesium,
    'zinc': zinc,
    'vitaminA': vitaminA,
    'vitaminB6': vitaminB6,
    'vitaminB12': vitaminB12,
    'folate': folate,
    'phosphorus': phosphorus,
    'iodine': iodine,
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
    saturatedFat: (json['saturatedFat'] ?? 0.0).toDouble(),
    transFat: (json['transFat'] ?? 0.0).toDouble(),
    cholesterol: (json['cholesterol'] ?? 0.0).toDouble(),
    potassium: (json['potassium'] ?? 0.0).toDouble(),
    magnesium: (json['magnesium'] ?? 0.0).toDouble(),
    zinc: (json['zinc'] ?? 0.0).toDouble(),
    vitaminA: (json['vitaminA'] ?? 0.0).toDouble(),
    vitaminB6: (json['vitaminB6'] ?? 0.0).toDouble(),
    vitaminB12: (json['vitaminB12'] ?? 0.0).toDouble(),
    folate: (json['folate'] ?? 0.0).toDouble(),
    phosphorus: (json['phosphorus'] ?? 0.0).toDouble(),
    iodine: (json['iodine'] ?? 0.0).toDouble(),
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
  final String? savedMealId;
  final String? mealType;

  MealEntry({
    required this.id,
    required this.timestamp,
    required this.nutrition,
    required this.note,
    this.savedMealId,
    this.mealType,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'nutrition': nutrition.toJson(),
    'note': note,
    'savedMealId': savedMealId,
    'mealType': mealType,
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
      savedMealId: json['savedMealId'],
      mealType: json['mealType'],
    );
  }
}

// ==========================================
// PHASE 1: BIOMETRICS & GOALS
// ==========================================

class BiometricProfile {
  final double heightCm;
  final double weightKg;
  final double goalWeightKg;
  final double initialWeightKg;
  final int age;
  final String gender;
  final String activityLevel;
  final String unitSystem;

  BiometricProfile({
    required this.heightCm,
    required this.weightKg,
    required this.goalWeightKg,
    required this.initialWeightKg,
    required this.age,
    required this.gender,
    required this.activityLevel,
    required this.unitSystem,
  });

  double get bmr {
    if (gender == 'male') return 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
    return 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
  }

  double get tdee {
    const m = {'sedentary': 1.2, 'light': 1.375, 'moderate': 1.55, 'active': 1.725, 'very_active': 1.9};
    return bmr * (m[activityLevel] ?? 1.2);
  }

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));

  String get weightDisplay => unitSystem == 'imperial'
      ? '${(weightKg * 2.20462).toStringAsFixed(1)} lbs'
      : '${weightKg.toStringAsFixed(1)} kg';

  String get heightDisplay => unitSystem == 'imperial'
      ? "${(heightCm / 30.48).floor()}' ${((heightCm / 2.54) % 12).round()}\""
      : '${heightCm.toStringAsFixed(0)} cm';

  Map<String, dynamic> toJson() => {
    'heightCm': heightCm,
    'weightKg': weightKg,
    'goalWeightKg': goalWeightKg,
    'initialWeightKg': initialWeightKg,
    'age': age,
    'gender': gender,
    'activityLevel': activityLevel,
    'unitSystem': unitSystem,
  };

  factory BiometricProfile.fromJson(Map<String, dynamic> json) => BiometricProfile(
    heightCm: (json['heightCm'] ?? 170.0).toDouble(),
    weightKg: (json['weightKg'] ?? 70.0).toDouble(),
    goalWeightKg: (json['goalWeightKg'] ?? 70.0).toDouble(),
    initialWeightKg: (json['initialWeightKg'] ?? 70.0).toDouble(),
    age: json['age'] ?? 30,
    gender: json['gender'] ?? 'other',
    activityLevel: json['activityLevel'] ?? 'sedentary',
    unitSystem: json['unitSystem'] ?? 'metric',
  );
}

class GoalProfile {
  int calorieGoal;
  double proteinGoalG;
  double carbsGoalG;
  double fatGoalG;
  double fiberGoalG;
  double sugarLimitG;
  double sodiumLimitMg;
  double vitaminCGoalMg;
  double vitaminDGoalMcg;
  double calciumGoalMg;
  double ironGoalMg;
  double waterGoalMl;
  String aiRationale;
  DateTime computedAt;
  Map<String, String> conditionAdjustments;

  GoalProfile({
    required this.calorieGoal, required this.proteinGoalG, required this.carbsGoalG, required this.fatGoalG, required this.fiberGoalG,
    required this.sugarLimitG, required this.sodiumLimitMg, required this.vitaminCGoalMg, required this.vitaminDGoalMcg,
    required this.calciumGoalMg, required this.ironGoalMg, required this.waterGoalMl, required this.aiRationale,
    required this.computedAt, required this.conditionAdjustments,
  });

  Map<String, dynamic> toJson() => {
    'calorieGoal': calorieGoal, 'proteinGoalG': proteinGoalG, 'carbsGoalG': carbsGoalG, 'fatGoalG': fatGoalG, 'fiberGoalG': fiberGoalG,
    'sugarLimitG': sugarLimitG, 'sodiumLimitMg': sodiumLimitMg, 'vitaminCGoalMg': vitaminCGoalMg, 'vitaminDGoalMcg': vitaminDGoalMcg,
    'calciumGoalMg': calciumGoalMg, 'ironGoalMg': ironGoalMg, 'waterGoalMl': waterGoalMl, 'aiRationale': aiRationale,
    'computedAt': computedAt.toIso8601String(), 'conditionAdjustments': conditionAdjustments,
  };

  factory GoalProfile.fromJson(Map<String, dynamic> json) => GoalProfile(
    calorieGoal: json['calorieGoal'] ?? 2000,
    proteinGoalG: (json['proteinGoalG'] ?? 50.0).toDouble(),
    carbsGoalG: (json['carbsGoalG'] ?? 260.0).toDouble(),
    fatGoalG: (json['fatGoalG'] ?? 65.0).toDouble(),
    fiberGoalG: (json['fiberGoalG'] ?? 25.0).toDouble(),
    sugarLimitG: (json['sugarLimitG'] ?? 50.0).toDouble(),
    sodiumLimitMg: (json['sodiumLimitMg'] ?? 2300.0).toDouble(),
    vitaminCGoalMg: (json['vitaminCGoalMg'] ?? 90.0).toDouble(),
    vitaminDGoalMcg: (json['vitaminDGoalMcg'] ?? 20.0).toDouble(),
    calciumGoalMg: (json['calciumGoalMg'] ?? 1000.0).toDouble(),
    ironGoalMg: (json['ironGoalMg'] ?? 18.0).toDouble(),
    waterGoalMl: (json['waterGoalMl'] ?? 2500.0).toDouble(),
    aiRationale: json['aiRationale'] ?? '',
    computedAt: json['computedAt'] != null ? DateTime.parse(json['computedAt']) : DateTime.now(),
    conditionAdjustments: Map<String, String>.from(json['conditionAdjustments'] ?? {}),
  );
}

class NutrientOverride {
  final String nutrientKey;
  final double userValue;
  final double aiValue;
  final String warningShown;
  final DateTime setAt;

  NutrientOverride({required this.nutrientKey, required this.userValue, required this.aiValue, required this.warningShown, required this.setAt});

  Map<String, dynamic> toJson() => {
    'nutrientKey': nutrientKey, 'userValue': userValue, 'aiValue': aiValue, 'warningShown': warningShown, 'setAt': setAt.toIso8601String(),
  };

  factory NutrientOverride.fromJson(Map<String, dynamic> json) => NutrientOverride(
    nutrientKey: json['nutrientKey'] ?? '',
    userValue: (json['userValue'] ?? 0.0).toDouble(),
    aiValue: (json['aiValue'] ?? 0.0).toDouble(),
    warningShown: json['warningShown'] ?? '',
    setAt: json['setAt'] != null ? DateTime.parse(json['setAt']) : DateTime.now(),
  );
}

// ==========================================
// PHASE 2 & BEYOND: LOGS & HISTORY
// ==========================================

class WeightEntry {
  final String id;
  final DateTime timestamp;
  final double weightKg;
  final String note;
  final String unitSystem;

  WeightEntry({required this.id, required this.timestamp, required this.weightKg, required this.note, required this.unitSystem});

  Map<String, dynamic> toJson() => {
    'id': id, 'timestamp': timestamp.toIso8601String(), 'weightKg': weightKg, 'note': note, 'unitSystem': unitSystem,
  };

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
    id: json['id'] ?? '',
    timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    weightKg: (json['weightKg'] ?? 0.0).toDouble(),
    note: json['note'] ?? '',
    unitSystem: json['unitSystem'] ?? 'metric',
  );
}

class SupplementEntry {
  final String id;
  final DateTime timestamp;
  final String type;
  final String brand;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double servingG;
  final int calories;
  final String note;

  SupplementEntry({required this.id, required this.timestamp, required this.type, required this.brand, required this.proteinG, required this.carbsG, required this.fatG, required this.servingG, required this.calories, required this.note});

  Map<String, dynamic> toJson() => {
    'id': id, 'timestamp': timestamp.toIso8601String(), 'type': type, 'brand': brand, 'proteinG': proteinG, 'carbsG': carbsG, 'fatG': fatG, 'servingG': servingG, 'calories': calories, 'note': note,
  };

  factory SupplementEntry.fromJson(Map<String, dynamic> json) => SupplementEntry(
    id: json['id'] ?? '',
    timestamp: json['timestamp'] != null ? DateTime.parse(json['timestamp']) : DateTime.now(),
    type: json['type'] ?? '',
    brand: json['brand'] ?? '',
    proteinG: (json['proteinG'] ?? 0.0).toDouble(),
    carbsG: (json['carbsG'] ?? 0.0).toDouble(),
    fatG: (json['fatG'] ?? 0.0).toDouble(),
    servingG: (json['servingG'] ?? 0.0).toDouble(),
    calories: json['calories'] ?? 0,
    note: json['note'] ?? '',
  );
}


class SavedMeal {
  final String id;
  final DateTime savedAt;
  final NutritionData nutrition;
  final String aiDescription;
  final String chatContext;
  int useCount;

  SavedMeal({required this.id, required this.savedAt, required this.nutrition, required this.aiDescription, required this.chatContext, this.useCount = 0});

  Map<String, dynamic> toJson() => {
    'id': id, 'savedAt': savedAt.toIso8601String(), 'nutrition': nutrition.toJson(), 'aiDescription': aiDescription, 'chatContext': chatContext, 'useCount': useCount,
  };

  factory SavedMeal.fromJson(Map<String, dynamic> json) => SavedMeal(
    id: json['id'] ?? '',
    savedAt: json['savedAt'] != null ? DateTime.parse(json['savedAt']) : DateTime.now(),
    nutrition: json['nutrition'] != null ? NutritionData.fromJson(json['nutrition']) : NutritionData.zero(),
    aiDescription: json['aiDescription'] ?? '',
    chatContext: json['chatContext'] ?? '',
    useCount: json['useCount'] ?? 0,
  );
}

class SavedSupplement {
  final String id;
  final DateTime savedAt;
  final String type;
  final String brand;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double servingG;
  final int calories;
  final String note;
  int useCount;

  SavedSupplement({required this.id, required this.savedAt, required this.type, required this.brand, required this.proteinG, required this.carbsG, required this.fatG, required this.servingG, required this.calories, required this.note, this.useCount = 0});

  Map<String, dynamic> toJson() => {
    'id': id, 'savedAt': savedAt.toIso8601String(), 'type': type, 'brand': brand, 'proteinG': proteinG, 'carbsG': carbsG, 'fatG': fatG, 'servingG': servingG, 'calories': calories, 'note': note, 'useCount': useCount,
  };

  factory SavedSupplement.fromJson(Map<String, dynamic> json) => SavedSupplement(
    id: json['id'] ?? '',
    savedAt: json['savedAt'] != null ? DateTime.parse(json['savedAt']) : DateTime.now(),
    type: json['type'] ?? '',
    brand: json['brand'] ?? '',
    proteinG: (json['proteinG'] ?? 0.0).toDouble(),
    carbsG: (json['carbsG'] ?? 0.0).toDouble(),
    fatG: (json['fatG'] ?? 0.0).toDouble(),
    servingG: (json['servingG'] ?? 0.0).toDouble(),
    calories: json['calories'] ?? 0,
    note: json['note'] ?? '',
    useCount: json['useCount'] ?? 0,
  );
}

class FastingSession {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final double targetHours;
  final bool completed;
  final double? actualHours;
  final String? aiNote;

  FastingSession({required this.id, required this.startTime, this.endTime, required this.targetHours, required this.completed, this.actualHours, this.aiNote});

  Map<String, dynamic> toJson() => {
    'id': id, 'startTime': startTime.toIso8601String(), 'endTime': endTime?.toIso8601String(), 'targetHours': targetHours, 'completed': completed, 'actualHours': actualHours, 'aiNote': aiNote,
  };

  factory FastingSession.fromJson(Map<String, dynamic> json) => FastingSession(
    id: json['id'] ?? '',
    startTime: json['startTime'] != null ? DateTime.parse(json['startTime']) : DateTime.now(),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    targetHours: (json['targetHours'] ?? 0.0).toDouble(),
    completed: json['completed'] ?? false,
    actualHours: json['actualHours'] != null ? (json['actualHours'] as num).toDouble() : null,
    aiNote: json['aiNote'],
  );
}

