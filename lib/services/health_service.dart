import 'package:health/health.dart';
import 'dart:async';
import 'dart:math' as math;

class HealthSnapshot {
  final int steps;
  final double activeCals;
  final double basalCals;
  final double sleepHours;
  final double mindfulMinutes;
  final DateTime fetchedAt;
  
  // Extended metrics for Apple Watch/iPhone tracking
  final Map<String, dynamic> extendedMetrics;

  HealthSnapshot({
    this.steps = 0,
    this.activeCals = 0,
    this.basalCals = 0,
    this.sleepHours = 0,
    this.mindfulMinutes = 0,
    this.extendedMetrics = const {},
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  HealthSnapshot copyWith({
    int? steps,
    double? activeCals,
    double? basalCals,
    double? sleepHours,
    double? mindfulMinutes,
    Map<String, dynamic>? extendedMetrics,
    DateTime? fetchedAt,
  }) {
    return HealthSnapshot(
      steps: steps ?? this.steps,
      activeCals: activeCals ?? this.activeCals,
      basalCals: basalCals ?? this.basalCals,
      sleepHours: sleepHours ?? this.sleepHours,
      mindfulMinutes: mindfulMinutes ?? this.mindfulMinutes,
      extendedMetrics: extendedMetrics ?? this.extendedMetrics,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  // Score from 0 to 100 based on standard health metrics
  int get healthScore {
    double score = 50; // base
    
    if (steps > 10000) score += 30;
    else if (steps > 5000) score += 15;
    else if (steps < 3000) score -= 10;

    if (sleepHours >= 7 && sleepHours <= 9) score += 20;
    else if (sleepHours >= 6) score += 10;
    else if (sleepHours > 0 && sleepHours < 5) score -= 15;

    if (mindfulMinutes > 10) score += 10;

    return score.clamp(0, 100).toInt();
  }
}

class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  bool _isConfigured = false;
  bool _isRequestingPermissions = false;
  bool _permissionsRequested = false;
  bool _verboseHealthLogs = false;

  double _lastBasalCals = 0;
  DateTime? _lastBasalAt;
  double _lastBasalRatePerMin = 0;
  
  // Real-time streaming for calorie data
  StreamController<HealthSnapshot>? _calorieStreamController;
  Timer? _calorieRefreshTimer;

  void _configure() {
    if (!_isConfigured) {
      Health().configure();
      _isConfigured = true;
    }
  }

  List<HealthDataPoint> _dedupePoints(List<HealthDataPoint> points) {
    final seen = <String>{};
    final deduped = <HealthDataPoint>[];
    for (final p in points) {
      final key = '${p.type}|${p.dateFrom.millisecondsSinceEpoch}|${p.dateTo.millisecondsSinceEpoch}|${p.value}|${p.sourceId}|${p.sourceName}';
      if (seen.add(key)) {
        deduped.add(p);
      }
    }
    return deduped;
  }

  static const _readTypes = [
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
  ];

  static const _writeTypes = [
    HealthDataType.DIETARY_ENERGY_CONSUMED,
    HealthDataType.WEIGHT,
  ];

  Future<bool> requestPermissions() async {
    // If already requested, don't request again
    if (_permissionsRequested) return true;
    if (_isRequestingPermissions) return false;
    
    _isRequestingPermissions = true;
    _configure();
    try {
      final types = <HealthDataType>[];
      final permissions = <HealthDataAccess>[];
      
      for (var type in _readTypes) {
        if (!types.contains(type)) {
          types.add(type);
          permissions.add(HealthDataAccess.READ);
        }
      }
      for (var type in _writeTypes) {
        if (!types.contains(type)) {
          types.add(type);
          permissions.add(HealthDataAccess.READ_WRITE);
        } else {
          // Upgrade to READ_WRITE if it was just READ
          int index = types.indexOf(type);
          permissions[index] = HealthDataAccess.READ_WRITE;
        }
      }
      
      bool authorized = await Health().requestAuthorization(types, permissions: permissions);
      _isRequestingPermissions = false;
      _permissionsRequested = true;
      return authorized;
    } catch (e) {
      _isRequestingPermissions = false;
      _permissionsRequested = true;
      return false;
    }
  }

  Future<void> writeWeight(double weightKg, DateTime time) async {
    _configure();
    try {
      await Health().writeHealthData(
        value: weightKg,
        type: HealthDataType.WEIGHT,
        startTime: time,
        endTime: time,
      );
    } catch (_) {}
  }

  Future<void> writeCalories(double calories, DateTime time) async {
    _configure();
    try {
      await Health().writeHealthData(
        value: calories,
        type: HealthDataType.DIETARY_ENERGY_CONSUMED,
        startTime: time,
        endTime: time,
      );
    } catch (_) {}
  }

  /// Get a stream of real-time health data updates (active and basal calories)
  /// Fetches every [refreshInterval] seconds to show real-time calorie burn
  Stream<HealthSnapshot> getRealtimeHealthStream({
    Duration refreshInterval = const Duration(seconds: 5), // More real-time feel
  }) {
    _calorieStreamController ??= StreamController<HealthSnapshot>.broadcast();
    
    // Cancel existing timer to avoid multiple subscriptions
    _calorieRefreshTimer?.cancel();
    
    // Fetch immediately
    _fetchAndBroadcastHealth();
    
    // Then refresh at interval
    _calorieRefreshTimer = Timer.periodic(refreshInterval, (_) {
      _fetchAndBroadcastHealth();
    });
    
    return _calorieStreamController!.stream;
  }

  Future<void> _fetchAndBroadcastHealth() async {
    try {
      final snap = await _fetchQuickSnapshot();
      if (_calorieStreamController != null && !_calorieStreamController!.isClosed) {
        print('[HealthService] Snapshot - Active: ${snap.activeCals.toStringAsFixed(1)}, Basal: ${snap.basalCals.toStringAsFixed(1)}, Steps: ${snap.steps}');
        _calorieStreamController!.add(snap);
      }
    } catch (e) {
      print('[HealthService] Error in _fetchAndBroadcastHealth: $e');
    }
  }

  /// Quick snapshot fetch - only calories and steps, no extended metrics
  Future<HealthSnapshot> _fetchQuickSnapshot({DateTime? targetDate}) async {
    _configure();
    final now = targetDate != null
        ? DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59)
        : DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    
    int steps = 0;
    double activeCals = 0;
    double basalCals = 0;
    
    try {
      if (_verboseHealthLogs) {
        print('[HealthService] Fetching health data for today (midnight: $midnight, now: $now)');
      }
      
      steps = await Health().getTotalStepsInInterval(midnight, now) ?? 0;
      if (_verboseHealthLogs) {
        print('[HealthService] Steps fetched: $steps');
      }
      
      var todayData = await Health().getHealthDataFromTypes(
        types: [
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.BASAL_ENERGY_BURNED,
        ],
        startTime: midnight,
        endTime: now,
      );
      if (_verboseHealthLogs) {
        print('[HealthService] Total health data points: ${todayData.length}');
      }
      
      // Apple Health active energy samples can be tiny (e.g. 0.05 kcal) and frequent.
      // removeDuplicates aggressively drops them if they match in value and time!
      // We skip removeDuplicates here to avoid zeroing out active energy.
      
      final activePoints = _dedupePoints(
        todayData.where((d) => d.type == HealthDataType.ACTIVE_ENERGY_BURNED).toList(),
      );
      final basalPoints = _dedupePoints(
        todayData.where((d) => d.type == HealthDataType.BASAL_ENERGY_BURNED).toList(),
      );

      final activeBySource = <String, double>{};
      final basalBySource = <String, double>{};

      for (var data in activePoints) {
        final val = (data.value as NumericHealthValue).numericValue.toDouble();
        activeCals += val;
        final key = '${data.sourceName} (${data.sourceId})';
        activeBySource[key] = (activeBySource[key] ?? 0) + val;
        if (_verboseHealthLogs) {
          print('[HealthService] Active energy point: ${(data.value as NumericHealthValue).numericValue} (cumulative: $activeCals)');
        }
      }
      for (var data in basalPoints) {
        final val = (data.value as NumericHealthValue).numericValue.toDouble();
        basalCals += val;
        final key = '${data.sourceName} (${data.sourceId})';
        basalBySource[key] = (basalBySource[key] ?? 0) + val;
        if (_verboseHealthLogs) {
          print('[HealthService] Basal energy point: ${(data.value as NumericHealthValue).numericValue} (cumulative: $basalCals)');
        }
      }

      // If Health data is slow to update, interpolate resting calories in real time.
      final minutesSinceMidnight = math.max(1, now.difference(midnight).inMinutes);
      if (basalCals > 0) {
        _lastBasalRatePerMin = basalCals / minutesSinceMidnight;
        _lastBasalCals = basalCals;
        _lastBasalAt = now;
      } else if (_lastBasalAt != null && _lastBasalRatePerMin > 0) {
        final elapsedMin = now.difference(_lastBasalAt!).inMinutes;
        final estimated = _lastBasalCals + (_lastBasalRatePerMin * elapsedMin);
        if (estimated > basalCals) {
          basalCals = estimated;
        }
      }

      print('[HealthService] Totals - Active: ${activeCals.toStringAsFixed(1)}, Basal: ${basalCals.toStringAsFixed(1)}, Steps: $steps | points A:${activePoints.length} B:${basalPoints.length}');
      if (activeBySource.isNotEmpty) {
        final parts = activeBySource.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}').join(' | ');
        print('[HealthService] Active by source -> $parts');
      }
      if (basalBySource.isNotEmpty) {
        final parts = basalBySource.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}').join(' | ');
        print('[HealthService] Basal by source -> $parts');
      }
      
    } catch (e) {
      print('[HealthService] Error fetching health data: $e');
    }
    
    return HealthSnapshot(
      steps: steps,
      activeCals: activeCals,
      basalCals: basalCals,
      fetchedAt: DateTime.now(),
    );
  }

  /// Dispose the real-time stream
  void disposeRealtimeStream() {
    _calorieRefreshTimer?.cancel();
    _calorieRefreshTimer = null;
    _calorieStreamController?.close();
    _calorieStreamController = null;
  }

  Future<HealthSnapshot> fetchDeepSnapshot({DateTime? targetDate}) async {
    _configure();
    final now = targetDate != null
        ? DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59)
        : DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    final yesterday = midnight.subtract(const Duration(days: 1));
    
    // Request permissions once if not already done
    if (!_permissionsRequested) {
      await requestPermissions();
    }
    
    int steps = 0;
    double activeCals = 0;
    double basalCals = 0;
    double sleepHours = 0;
    double mindfulMinutes = 0;
    
    try {
      steps = await Health().getTotalStepsInInterval(midnight, now) ?? 0;
      
      var todayData = await Health().getHealthDataFromTypes(
        types: [
          HealthDataType.ACTIVE_ENERGY_BURNED,
          HealthDataType.BASAL_ENERGY_BURNED,
          HealthDataType.MINDFULNESS,
        ],
        startTime: midnight,
        endTime: now,
      );
      // Removed Health().removeDuplicates(todayData) because it wipes active energy
      
      final activePoints = _dedupePoints(
        todayData.where((d) => d.type == HealthDataType.ACTIVE_ENERGY_BURNED).toList(),
      );
      final basalPoints = _dedupePoints(
        todayData.where((d) => d.type == HealthDataType.BASAL_ENERGY_BURNED).toList(),
      );

      for (var data in activePoints) {
        activeCals += (data.value as NumericHealthValue).numericValue.toDouble();
      }
      for (var data in basalPoints) {
        basalCals += (data.value as NumericHealthValue).numericValue.toDouble();
      }
      for (var data in todayData.where((d) => d.type == HealthDataType.MINDFULNESS)) {
        final diff = data.dateTo.difference(data.dateFrom);
        mindfulMinutes += diff.inSeconds / 60.0;
      }


      // Sleep (check yesterday 6pm to now)
      final sleepStart = DateTime(yesterday.year, yesterday.month, yesterday.day, 18, 0);
      var sleepData = await Health().getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: sleepStart,
        endTime: now,
      );
      sleepData = Health().removeDuplicates(sleepData);
      for (var data in sleepData) {
        final diff = data.dateTo.difference(data.dateFrom);
        sleepHours += diff.inMinutes / 60.0;
      }

    } catch (e) {
      // Return whatever we have so far
    }
    
    
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

    final snapshot = HealthSnapshot(
      steps: steps,
      activeCals: activeCals,
      basalCals: basalCals,
      sleepHours: sleepHours,
      mindfulMinutes: mindfulMinutes,
      extendedMetrics: extended,
    );
    return snapshot;
  }
}
