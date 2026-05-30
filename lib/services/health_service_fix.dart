// This file contains the fix for fetching health data from Apple Health
// The issue is that getHealthDataFromTypes uses HKSampleQuery which may not return energy data
// The solution is to use getIntervalData with interval: 0 to get cumulative data

// In health_service.dart, replace the getHealthDataFromTypes call with this approach:

Future<List<HealthDataPoint>> _fetchEnergyData({
  required HealthDataType type,
  required DateTime startTime,
  required DateTime endTime,
}) async {
  try {
    final result = await Health().getIntervalData(
      dataTypeKey: type.toString(),
      dataUnitKey: 'KILOCALORIE',
      startTime: startTime.millisecondsSinceEpoch,
      endTime: endTime.millisecondsSinceEpoch,
      interval: 0, // 0 means get cumulative sum for the entire period
    );
    
    if (result == null) return [];
    
    return result.map((item) {
      return HealthDataPoint(
        type: type,
        value: item['value'] as double,
        dateFrom: DateTime.fromMillisecondsSinceEpoch(item['date_from'] as int),
        dateTo: DateTime.fromMillisecondsSinceEpoch(item['date_to'] as int),
        sourceId: item['source_id'] as String,
        sourceName: item['source_name'] as String,
      );
    }).toList();
  } catch (e) {
    print('[HealthService] Error fetching energy data for $type: $e');
    return [];
  }
}

// Then in _fetchQuickSnapshot and fetchDeepSnapshot, replace:
// var todayData = await Health().getHealthDataFromTypes(...)
// 
// With:
// final activePoints = await _fetchEnergyData(
//   type: HealthDataType.ACTIVE_ENERGY_BURNED,
//   startTime: midnight,
//   endTime: now,
// );
// final basalPoints = await _fetchEnergyData(
//   type: HealthDataType.BASAL_ENERGY_BURNED,
//   startTime: midnight,
//   endTime: now,
// );
