import 'package:flutter/foundation.dart';

/// Global selected date for the "Time Machine" feature.
/// Defaults to today. When changed to a past date, the dashboard
/// shows data for that day. Logging to a past date does NOT
/// affect streaks, achievements, or XP.
final ValueNotifier<DateTime> globalSelectedDate = ValueNotifier(DateTime.now());

/// Returns true if [a] and [b] fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Returns true if the currently selected date is today.
bool get isSelectedDateToday => isSameDay(globalSelectedDate.value, DateTime.now());
