import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import '../models.dart';

class HealthSnapshot {
  final int steps;
  final double activeCals;
  final double basalCals;
  final double sleepHours;
  final double mindfulMinutes;
  final DateTime fetchedAt;
  
  // Extended metrics for Apple Watch/iPhone tracking
  final Map<String, dynamic> extendedMetrics;
  
  // Flag to indicate if basal calories are estimated vs actual from HealthKit
  final bool basalIsEstimated;
  
  // BMR (Basal Metabolic Rate) for real-time calorie increment calculation
  final double bmr;

  HealthSnapshot({
    this.steps = 0,
    this.activeCals = 0,
    this.basalCals = 0,
    this.sleepHours = 0,
    this.mindfulMinutes = 0,
    this.extendedMetrics = const {},
    this.basalIsEstimated = false,
    this.bmr = 2400.0,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  HealthSnapshot copyWith({
    int? steps,
    double? activeCals,
    double? basalCals,
    double? sleepHours,
    double? mindfulMinutes,
    Map<String, dynamic>? extendedMetrics,
    bool? basalIsEstimated,
    double? bmr,
    DateTime? fetchedAt,
  }) {
    return HealthSnapshot(
      steps: steps ?? this.steps,
      activeCals: activeCals ?? this.activeCals,
      basalCals: basalCals ?? this.basalCals,
      sleepHours: sleepHours ?? this.sleepHours,
      mindfulMinutes: mindfulMinutes ?? this.mindfulMinutes,
      extendedMetrics: extendedMetrics ?? this.extendedMetrics,
      basalIsEstimated: basalIsEstimated ?? this.basalIsEstimated,
      bmr: bmr ?? this.bmr,
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
  
  // Estimated daily basal metabolic rate (calories per day)
  // Will be loaded from user's biometric profile
  double _estimatedDailyBMR = 2400.0;
  bool _bmrLoaded = false;
  
  // Real-time streaming for calorie data
  StreamController<HealthSnapshot>? _calorieStreamController;
  Timer? _calorieRefreshTimer;

  void _configure() {
    if (!_isConfigured) {
      Health().configure();
      _isConfigured = true;
    }
  }
  
  /// Load user's BMR from their biometric profile
  Future<void> _loadUserBMR() async {
    if (_bmrLoaded) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final profileStr = prefs.getString('profile');
      
      if (profileStr != null) {
        final profile = BiometricProfile.fromJson(jsonDecode(profileStr));
        _estimatedDailyBMR = profile.bmr;
        _bmrLoaded = true;
        print('[HealthService] Loaded user BMR from profile: ${_estimatedDailyBMR.toStringAsFixed(0)} cal/day');
      } else {
        // Fallback: try to calculate from individual fields
        final heightCm = prefs.getDouble('height_cm');
        final weightKg = prefs.getDouble('weight_kg');
        final age = prefs.getInt('age');
        final gender = prefs.getString('gender');
        
        if (heightCm != null && weightKg != null && age != null && gender != null) {
          // Mifflin-St Jeor Equation
          if (gender == 'male') {
            _estimatedDailyBMR = 10 * weightKg + 6.25 * heightCm - 5 * age + 5;
          } else {
            _estimatedDailyBMR = 10 * weightKg + 6.25 * heightCm - 5 * age - 161;
          }
          _bmrLoaded = true;
          print('[HealthService] Calculated user BMR: ${_estimatedDailyBMR.toStringAsFixed(0)} cal/day');
        } else {
          print('[HealthService] No profile data found, using default BMR: 2400 cal/day');
        }
      }
    } catch (e) {
      print('[HealthService] Error loading BMR: $e, using default: 2400 cal/day');
    }
  }
  
  /// Set the estimated daily BMR for fallback calculation
  /// This is used when Apple Health doesn't have basal energy data
  void setEstimatedDailyBMR(double caloriesPerDay) {
    _estimatedDailyBMR = caloriesPerDay;
    _bmrLoaded = true;
    print('[HealthService] Estimated daily BMR set to: ${caloriesPerDay.toStringAsFixed(0)} cal/day');
  }
  
  /// Calculate estimated basal calories burned since midnight based on time elapsed
  double _calculateEstimatedBasalCalories(DateTime midnight, DateTime now) {
    final secondsSinceMidnight = now.difference(midnight).inSeconds;
    final caloriesPerSecond = _estimatedDailyBMR / 86400.0; // 86400 seconds in a day
    final estimatedBasal = caloriesPerSecond * secondsSinceMidnight;
    return estimatedBasal;
  }

  /// Safely read a numeric value from a HealthDataPoint. Returns 0 for any
  /// non-numeric sample instead of throwing, so one odd point can't abort the
  /// whole aggregation loop (which would silently drop calories/steps).
  double _numVal(HealthDataPoint data) {
    final v = data.value;
    if (v is NumericHealthValue) return v.numericValue.toDouble();
    return 0.0;
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

  /// Fetch energy data using getHealthDataFromTypes
  /// Note: On iOS, basal energy data may not be available unless:
  /// - User has an Apple Watch with metabolic tracking enabled
  /// - User has manually entered basal energy data
  /// - A third-party app has shared basal energy data
  Future<List<HealthDataPoint>> _fetchEnergyData({
    required HealthDataType type,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      print('[HealthService] Fetching $type from $startTime to $endTime');
      final result = await Health().getHealthDataFromTypes(
        types: [type],
        startTime: startTime,
        endTime: endTime,
      );
      
      // Remove exact-duplicate samples (e.g. iPhone + Apple Watch both
      // reporting the same energy) so calorie/step totals aren't inflated.
      final deduped = _dedupePoints(result);

      print('[HealthService] Received ${result.length} data points for $type (${deduped.length} after dedupe)');
      if (deduped.isNotEmpty) {
        for (var point in deduped.take(3)) {
          print('[HealthService]   - ${point.value} from ${point.sourceName} (${point.sourceId})');
        }
      }
      
      return deduped;
    } catch (e) {
      print('[HealthService] Error fetching energy data for $type: $e');
      return [];
    }
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
      
      print('[HealthService] Requesting permissions for ${types.length} health data types');
      print('[HealthService] Including: ACTIVE_ENERGY_BURNED, BASAL_ENERGY_BURNED, STEPS');
      
      bool authorized = await Health().requestAuthorization(types, permissions: permissions);
      _isRequestingPermissions = false;
      _permissionsRequested = true;
      
      print('[HealthService] Authorization result: $authorized');
      
      // Check specific permissions
      try {
        final hasActive = await Health().hasPermissions([HealthDataType.ACTIVE_ENERGY_BURNED]);
        final hasBasal = await Health().hasPermissions([HealthDataType.BASAL_ENERGY_BURNED]);
        final hasSteps = await Health().hasPermissions([HealthDataType.STEPS]);
        print('[HealthService] Permission check - Active: $hasActive, Basal: $hasBasal, Steps: $hasSteps');
      } catch (e) {
        print('[HealthService] Could not check individual permissions: $e');
      }
      
      return authorized;
    } catch (e) {
      print('[HealthService] Error requesting permissions: $e');
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
    bool basalIsEstimated = false;
    
    try {
      if (_verboseHealthLogs) {
        print('[HealthService] Fetching health data for today (midnight: $midnight, now: $now)');
      }
      
      steps = await Health().getTotalStepsInInterval(midnight, now) ?? 0;
      if (_verboseHealthLogs) {
        print('[HealthService] Steps fetched: $steps');
      }
      
      // Use getIntervalData for energy data - this uses HKStatisticsCollectionQuery
      // which is more reliable for getting cumulative energy data on iOS
      final activePoints = await _fetchEnergyData(
        type: HealthDataType.ACTIVE_ENERGY_BURNED,
        startTime: midnight,
        endTime: now,
      );
      final basalPoints = await _fetchEnergyData(
        type: HealthDataType.BASAL_ENERGY_BURNED,
        startTime: midnight,
        endTime: now,
      );
      
      if (_verboseHealthLogs) {
        print('[HealthService] Active energy points: ${activePoints.length}');
        print('[HealthService] Basal energy points: ${basalPoints.length}');
      }
      
      final activeBySource = <String, double>{};
      final basalBySource = <String, double>{};

      for (var data in activePoints) {
        final val = _numVal(data);
        activeCals += val;
        final key = '${data.sourceName} (${data.sourceId})';
        activeBySource[key] = (activeBySource[key] ?? 0) + val;
        if (_verboseHealthLogs) {
          print('[HealthService] Active energy point: $val (cumulative: $activeCals)');
        }
      }
      for (var data in basalPoints) {
        final val = _numVal(data);
        basalCals += val;
        final key = '${data.sourceName} (${data.sourceId})';
        basalBySource[key] = (basalBySource[key] ?? 0) + val;
        if (_verboseHealthLogs) {
          print('[HealthService] Basal energy point: $val (cumulative: $basalCals)');
        }
      }

      // If Health data is slow to update, interpolate resting calories in real time.
      final minutesSinceMidnight = math.max(1, now.difference(midnight).inMinutes);
      
      if (basalCals > 0) {
        _lastBasalRatePerMin = basalCals / minutesSinceMidnight;
        _lastBasalCals = basalCals;
        _lastBasalAt = now;
      } else if (_lastBasalAt != null && _lastBasalRatePerMin > 0) {
        // Interpolate from last known value
        final elapsedMin = now.difference(_lastBasalAt!).inMinutes;
        final estimated = _lastBasalCals + (_lastBasalRatePerMin * elapsedMin);
        if (estimated > basalCals) {
          basalCals = estimated;
          basalIsEstimated = true;
        }
      } else {
        // No HealthKit data available - use estimated BMR calculation
        await _loadUserBMR(); // Load user's actual BMR first
        basalCals = _calculateEstimatedBasalCalories(midnight, now);
        basalIsEstimated = true;
        print('[HealthService] Using estimated basal calories: ${basalCals.toStringAsFixed(1)} (${_estimatedDailyBMR.toStringAsFixed(0)} cal/day)');
      }

      // Log detailed information for debugging
      print('[HealthService] === Health Data Summary ===');
      print('[HealthService] Active energy points: ${activePoints.length}');
      print('[HealthService] Basal energy points: ${basalPoints.length}');
      print('[HealthService] Active calories: ${activeCals.toStringAsFixed(1)}');
      print('[HealthService] Basal calories: ${basalCals.toStringAsFixed(1)} ${basalIsEstimated ? "(ESTIMATED)" : "(FROM HEALTHKIT)"}');
      print('[HealthService] Steps: $steps');
      
      if (activeBySource.isNotEmpty) {
        final parts = activeBySource.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}').join(' | ');
        print('[HealthService] Active by source -> $parts');
      }
      if (basalBySource.isNotEmpty) {
        final parts = basalBySource.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(1)}').join(' | ');
        print('[HealthService] Basal by source -> $parts');
      } else if (!basalIsEstimated) {
        print('[HealthService] WARNING: No basal energy data found in HealthKit!');
        print('[HealthService] Note: Basal energy requires Apple Watch with metabolic tracking or manual entry');
      }
      print('[HealthService] ===============================');
      
    } catch (e) {
      print('[HealthService] Error fetching health data: $e');
    }
    
    return HealthSnapshot(
      steps: steps,
      activeCals: activeCals,
      basalCals: basalCals,
      basalIsEstimated: basalIsEstimated,
      bmr: _estimatedDailyBMR,
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
    bool basalIsEstimated = false;
    
    try {
      steps = await Health().getTotalStepsInInterval(midnight, now) ?? 0;
      
      // Use getIntervalData for energy data - this uses HKStatisticsCollectionQuery
      // which is more reliable for getting cumulative energy data on iOS
      final activePoints = await _fetchEnergyData(
        type: HealthDataType.ACTIVE_ENERGY_BURNED,
        startTime: midnight,
        endTime: now,
      );
      final basalPoints = await _fetchEnergyData(
        type: HealthDataType.BASAL_ENERGY_BURNED,
        startTime: midnight,
        endTime: now,
      );
      final mindfulPoints = await _fetchEnergyData(
        type: HealthDataType.MINDFULNESS,
        startTime: midnight,
        endTime: now,
      );

      for (var data in activePoints) {
        activeCals += _numVal(data);
      }
      for (var data in basalPoints) {
        basalCals += _numVal(data);
      }
      for (var data in mindfulPoints) {
        final diff = data.dateTo.difference(data.dateFrom);
        mindfulMinutes += diff.inSeconds / 60.0;
      }

      // Apply fallback basal calculation if no HealthKit data
      if (basalCals == 0) {
        await _loadUserBMR(); // Load user's actual BMR first
        basalCals = _calculateEstimatedBasalCalories(midnight, now);
        basalIsEstimated = true;
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

      // Log detailed information for debugging
      print('[HealthService] === Deep Snapshot Summary ===');
      print('[HealthService] Active energy points: ${activePoints.length}');
      print('[HealthService] Basal energy points: ${basalPoints.length}');
      print('[HealthService] Active calories: ${activeCals.toStringAsFixed(1)}');
      print('[HealthService] Basal calories: ${basalCals.toStringAsFixed(1)} ${basalIsEstimated ? "(ESTIMATED)" : "(FROM HEALTHKIT)"}');
      print('[HealthService] Steps: $steps');
      print('[HealthService] Sleep hours: ${sleepHours.toStringAsFixed(2)}');
      print('[HealthService] Mindful minutes: ${mindfulMinutes.toStringAsFixed(1)}');
      
      if (basalPoints.isEmpty && !basalIsEstimated) {
        print('[HealthService] WARNING: No basal energy data found in HealthKit!');
        print('[HealthService] Note: Basal energy requires Apple Watch with metabolic tracking or manual entry');
      }
      print('[HealthService] ===============================');

    } catch (e) {
      // Return whatever we have so far
      print('[HealthService] Error in fetchDeepSnapshot: $e');
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
        grouped[data.type]!.add(_numVal(data));
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

    } catch (e) {
      print('[HealthService] Error fetching extended metrics: $e');
    }

    final snapshot = HealthSnapshot(
      steps: steps,
      activeCals: activeCals,
      basalCals: basalCals,
      sleepHours: sleepHours,
      mindfulMinutes: mindfulMinutes,
      extendedMetrics: extended,
      basalIsEstimated: basalIsEstimated,
    );
    return snapshot;
  }
}
