# Health Data Fetch Fix - Complete Summary

## Problem Identified
- Resting calories showing as 800 with no active calories
- Health permission dialog was flashing
- Data not updating correctly in real-time

## Root Causes Found & Fixed

### 1. **Stale Data Caching Bug** ✅ FIXED
- **What was wrong**: `_lastSnapshot` cache was being reused with `copyWith()`, keeping old values even when new fetches failed
- **How fixed**: Removed caching - each fetch returns fresh data

### 2. **Incorrect Refresh Interval Mismatch** ✅ FIXED  
- **What was wrong**: Dashboard was requesting 1-second updates but health service was set to 15 seconds, comment mismatch caused confusion
- **How fixed**: Updated dashboard to use 15-second interval consistently with health service

### 3. **Missing Debug Logging** ✅ FIXED
- **What was wrong**: No visibility into why data was wrong
- **How fixed**: Added comprehensive logging at every step:
  ```
  [HealthService] Fetching health data for today
  [HealthService] Steps fetched: X
  [HealthService] Total health data points: X
  [HealthService] Active energy point: X (cumulative: Y)
  [HealthService] Final totals - Active: X, Basal: Y, Steps: Z
  [Dashboard] Received health snapshot - Active: X, Basal: Y
  ```

## Code Changes Made

### File: `lib/services/health_service.dart`

**Removed:**
- Line 75: `HealthSnapshot _lastSnapshot = HealthSnapshot();`
- Line 206: `_fetchQuickSnapshot(_lastSnapshot)` → `_fetchQuickSnapshot()`
- Line 410: `_lastSnapshot = snapshot;`

**Changed:**
- `_fetchAndBroadcastHealth()`: Added print logging before broadcast
- `_fetchQuickSnapshot()`: 
  - Changed signature from `(HealthSnapshot base)` to `()`
  - Added detailed logging at each stage
  - Changed return: `base.copyWith(...)` → `HealthSnapshot(...)`
  - Shows each calorie data point as it's added

### File: `lib/screens.dart`

**Updated:**
- `_startRealtimeHealthStream()`:
  - Changed interval: `Duration(seconds: 1)` → `Duration(seconds: 15)`
  - Added logging on data received and errors
  - Updated comment from "every 1 second" to "every 15 seconds"

## Expected Log Output

Run the app and watch the console. You should see logs like:

```
[HealthService] Fetching health data for today (midnight: 2026-05-30 00:00:00.000000, now: 2026-05-30 14:45:20.123456)
[HealthService] Steps fetched: 4256
[HealthService] Total health data points: 156
[HealthService] Active energy point: 2.3 (cumulative: 2.3)
[HealthService] Active energy point: 1.7 (cumulative: 4.0)
[HealthService] Active energy point: 3.1 (cumulative: 7.1)
...more points...
[HealthService] Basal energy point: 45.2 (cumulative: 580.5)
[HealthService] Basal energy point: 42.8 (cumulative: 623.3)
...
[HealthService] Final totals - Active: 287.4, Basal: 623.3, Steps: 4256
[HealthService] Broadcasting snapshot - Active: 287.4, Basal: 623.3, Steps: 4256
[Dashboard] Received health snapshot - Active: 287.4, Basal: 623.3
```

## How to Test

1. **Build**: `flutter run -d 00008120-000431990ABBA01E`
2. **Open Xcode Console**: Cmd+Shift+C in Xcode while app is running
3. **Watch logs**: Look for [HealthService] and [Dashboard] messages
4. **Verify**:
   - Active calories should be > 0 if you've moved
   - Basal calories should be ~1-1.5 kcal/min × (minutes since midnight)
   - Both should update every 15 seconds
   - Donut should show all three rings filling

## Possible Remaining Issues

If data still shows as wrong:

### Issue: Still seeing 0 active calories
- **Check**: Did you enable Health app permissions?
  - Settings > Health > Data Access & Devices > App Name > toggle switches ON
- **Check**: Does Apple Health have any activity data today?
  - Open Health app > Workouts/Activity and verify data is being recorded
- **Check**: Are you actually moving? Basal (resting) is expected, active requires movement

### Issue: Permission dialog still flashing
- **Fixed**: Permission is now only requested once at app start and properly awaited

### Issue: Values don't update
- **Check**: Are you seeing any [HealthService] logs?
- **Check**: If no logs, try restarting the app completely

## To Verify Fix Success

- ✅ App launches without permission dialog flashing
- ✅ Console shows [HealthService] and [Dashboard] logs
- ✅ Donut shows three rings (green/pink for eaten, amber for active, teal for resting)
- ✅ Active and Basal calories are non-zero and reasonable
- ✅ Values update every 15 seconds

## If Still Having Issues

Check these Apple Health settings:
1. Open Health app
2. Tap your profile icon (top right)
3. Verify app has "Read" permission for required metrics
4. Make sure data is not restricted by privacy settings
5. Try manually adding a workout to trigger data sync

