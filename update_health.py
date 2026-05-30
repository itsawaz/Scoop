import re

with open('lib/services/health_service.dart', 'r') as f:
    content = f.read()

# Update HealthSnapshot
new_snapshot = """class HealthSnapshot {
  final int steps;
  final double activeCals;
  final double basalCals;
  final double sleepHours;
  final double mindfulMinutes;
  
  // Extended metrics for Apple Watch/iPhone tracking
  final Map<String, dynamic> extendedMetrics;

  HealthSnapshot({
    this.steps = 0,
    this.activeCals = 0,
    this.basalCals = 0,
    this.sleepHours = 0,
    this.mindfulMinutes = 0,
    this.extendedMetrics = const {},
  });"""

content = re.sub(r'class HealthSnapshot \{[\s\S]*?this\.mindfulMinutes = 0,\n  \}\);', new_snapshot, content)

# Expand _readTypes
old_read_types = """  static const _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.MINDFULNESS,
  ];"""

new_read_types = """  static const _readTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.MINDFULNESS,
    
    // Vitals
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.BODY_TEMPERATURE,
    
    // Body Measurements
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.BODY_MASS_INDEX,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.LEAN_BODY_MASS,
    
    // Activity
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.FLIGHTS_CLIMBED,
    HealthDataType.EXERCISE_TIME,
    
    // Wellbeing
    HealthDataType.WATER,
  ];"""

content = content.replace(old_read_types, new_read_types)

# Update fetchDeepSnapshot
# We will use a script to rewrite fetchDeepSnapshot to loop through _readTypes dynamically for the extra types

old_fetch = r'(Future<HealthSnapshot> fetchDeepSnapshot\(\) async \{[\s\S]+?)(return HealthSnapshot\(\n      steps: steps,\n      activeCals: activeCals,\n      basalCals: basalCals,\n      sleepHours: sleepHours,\n      mindfulMinutes: mindfulMinutes,\n    \);)'

new_fetch_body = r"""\1
    // Fetch Extended Metrics
    Map<String, dynamic> extended = {};
    try {
      final extendedTypes = [
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.BLOOD_OXYGEN,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
        HealthDataType.RESPIRATORY_RATE,
        HealthDataType.BODY_TEMPERATURE,
        HealthDataType.WEIGHT,
        HealthDataType.HEIGHT,
        HealthDataType.BODY_MASS_INDEX,
        HealthDataType.BODY_FAT_PERCENTAGE,
        HealthDataType.LEAN_BODY_MASS,
        HealthDataType.DISTANCE_WALKING_RUNNING,
        HealthDataType.FLIGHTS_CLIMBED,
        HealthDataType.EXERCISE_TIME,
        HealthDataType.WATER,
      ];
      
      var exData = await Health().getHealthDataFromTypes(
        types: extendedTypes,
        startTime: yesterday,
        endTime: now,
      );
      exData = Health().removeDuplicates(exData);
      
      // Calculate averages or latest values
      Map<HealthDataType, List<double>> grouped = {};
      for (var data in exData) {
        if (!grouped.containsKey(data.type)) grouped[data.type] = [];
        grouped[data.type]!.add((data.value as NumericHealthValue).numericValue.toDouble());
      }
      
      double avg(List<double> list) => list.reduce((a, b) => a + b) / list.length;
      double sum(List<double> list) => list.reduce((a, b) => a + b);
      double latest(List<double> list) => list.last;
      
      if (grouped.containsKey(HealthDataType.HEART_RATE)) extended['Heart Rate'] = {'value': avg(grouped[HealthDataType.HEART_RATE]!).round(), 'unit': 'bpm', 'emoji': '❤️'};
      if (grouped.containsKey(HealthDataType.RESTING_HEART_RATE)) extended['Resting HR'] = {'value': avg(grouped[HealthDataType.RESTING_HEART_RATE]!).round(), 'unit': 'bpm', 'emoji': '🫀'};
      if (grouped.containsKey(HealthDataType.BLOOD_OXYGEN)) extended['Blood O₂'] = {'value': (avg(grouped[HealthDataType.BLOOD_OXYGEN]!) * 100).round(), 'unit': '%', 'emoji': '🩸'};
      if (grouped.containsKey(HealthDataType.RESPIRATORY_RATE)) extended['Resp. Rate'] = {'value': avg(grouped[HealthDataType.RESPIRATORY_RATE]!).round(), 'unit': 'rpm', 'emoji': '🫁'};
      if (grouped.containsKey(HealthDataType.BODY_TEMPERATURE)) extended['Temp'] = {'value': avg(grouped[HealthDataType.BODY_TEMPERATURE]!).toStringAsFixed(1), 'unit': '°C', 'emoji': '🌡️'};
      
      if (grouped.containsKey(HealthDataType.BLOOD_PRESSURE_SYSTOLIC) && grouped.containsKey(HealthDataType.BLOOD_PRESSURE_DIASTOLIC)) {
        extended['Blood Pressure'] = {'value': '${avg(grouped[HealthDataType.BLOOD_PRESSURE_SYSTOLIC]!).round()}/${avg(grouped[HealthDataType.BLOOD_PRESSURE_DIASTOLIC]!).round()}', 'unit': 'mmHg', 'emoji': '🩺'};
      }
      
      if (grouped.containsKey(HealthDataType.WEIGHT)) extended['Weight'] = {'value': latest(grouped[HealthDataType.WEIGHT]!).toStringAsFixed(1), 'unit': 'kg', 'emoji': '⚖️'};
      if (grouped.containsKey(HealthDataType.HEIGHT)) extended['Height'] = {'value': latest(grouped[HealthDataType.HEIGHT]!).toStringAsFixed(2), 'unit': 'm', 'emoji': '📏'};
      if (grouped.containsKey(HealthDataType.BODY_MASS_INDEX)) extended['BMI'] = {'value': latest(grouped[HealthDataType.BODY_MASS_INDEX]!).toStringAsFixed(1), 'unit': '', 'emoji': '📊'};
      if (grouped.containsKey(HealthDataType.BODY_FAT_PERCENTAGE)) extended['Body Fat'] = {'value': (latest(grouped[HealthDataType.BODY_FAT_PERCENTAGE]!) * 100).toStringAsFixed(1), 'unit': '%', 'emoji': '🔬'};
      if (grouped.containsKey(HealthDataType.LEAN_BODY_MASS)) extended['Lean Mass'] = {'value': latest(grouped[HealthDataType.LEAN_BODY_MASS]!).toStringAsFixed(1), 'unit': 'kg', 'emoji': '💪'};
      
      if (grouped.containsKey(HealthDataType.DISTANCE_WALKING_RUNNING)) extended['Distance'] = {'value': sum(grouped[HealthDataType.DISTANCE_WALKING_RUNNING]!).toStringAsFixed(2), 'unit': 'km', 'emoji': '🏃'};
      if (grouped.containsKey(HealthDataType.FLIGHTS_CLIMBED)) extended['Flights'] = {'value': sum(grouped[HealthDataType.FLIGHTS_CLIMBED]!).round(), 'unit': 'floors', 'emoji': '🧗'};
      if (grouped.containsKey(HealthDataType.EXERCISE_TIME)) extended['Exercise'] = {'value': sum(grouped[HealthDataType.EXERCISE_TIME]!).round(), 'unit': 'min', 'emoji': '⏱️'};
      if (grouped.containsKey(HealthDataType.WATER)) extended['Water'] = {'value': sum(grouped[HealthDataType.WATER]!).toStringAsFixed(1), 'unit': 'L', 'emoji': '💧'};

    } catch (e) {}

    return HealthSnapshot(
      steps: steps,
      activeCals: activeCals,
      basalCals: basalCals,
      sleepHours: sleepHours,
      mindfulMinutes: mindfulMinutes,
      extendedMetrics: extended,
    );
  }
}
"""

content = re.sub(old_fetch, new_fetch_body, content)

with open('lib/services/health_service.dart', 'w') as f:
    f.write(content)
