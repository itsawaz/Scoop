# Real-Time Calorie Burn Feature

## Overview
Implemented a real-time health data integration feature where the calorie donut visualization updates every second with active and resting calories fetched from Apple Health. This creates a dynamic experience where users can watch their effective calories decrease as they burn more calories throughout the day.

## Key Features

### 1. Real-Time Health Data Streaming
- **File**: `lib/services/health_service.dart`
- Added `getRealtimeHealthStream()` method that fetches calorie data every 1 second
- Implemented `_fetchAndBroadcastHealth()` to continuously stream active and basal calorie data
- Added `_fetchQuickSnapshot()` for fast, lightweight health data retrieval (only calories and steps)

### 2. Enhanced Calorie Visualization (Triple Ring Donut)
- **File**: `lib/widgets.dart`
- Updated `CalorieDonut` widget to accept both `burnt` (active) and `resting` (basal) calories
- Redesigned `_DonutPainter` with three concentric rings:
  - **Outer Ring (Green/Pink)**: Consumed calories (dynamic color based on goal)
  - **Middle Ring (Amber/Orange)**: Active calories from movement/exercise
  - **Inner Ring (Teal)**: Resting/Basal calories (metabolic burn at rest)
- Added "🔥 XXX burned" indicator showing total calorie burn
- Real-time percentage calculations for each ring based on goal

### 3. Dashboard Integration
- **File**: `lib/screens.dart`
- Added `StreamSubscription<HealthSnapshot>` for real-time updates
- Implemented `_startRealtimeHealthStream()` that listens to health data updates every second
- Updated `dispose()` to properly clean up stream subscriptions
- Modified `CalorieDonut` instantiation to pass resting calories:
  ```dart
  CalorieDonut(
    consumed: _totals.calories, 
    goal: _getGoal('calories', _goals.calorieGoal.toDouble()).round(), 
    burnt: _health.activeCals.round(),
    resting: _health.basalCals.round(),
  )
  ```
- Maintains 10-minute deep snapshot refresh for extended metrics

## User Experience

### The Goal Achievement Flow
1. **User eats 400 kcal** at breakfast
2. **Each passing second**:
   - Active calories increase from movement
   - Resting calories increase from metabolic burn (~1-2 kcal/min baseline)
3. **Effective calories decrease** dynamically:
   - Effective = Consumed - (Active + Resting)
4. **End of day goal**: Reach 0 or **negative effective calories** (total burn ≥ consumed)

### Visual Feedback
- Three-ring system shows breakdown:
  - Outer ring = what you ate
  - Middle ring = active burn (exercise, movement)
  - Inner ring = passive burn (metabolism at rest)
- As rings fill (from inner to outer), effective calorie count decreases
- Color changes: Green when ahead of goal, Pink when over effective calories

## Technical Details

### Real-Time Refresh Strategy
- **Frequency**: Every 1 second (configurable via `refreshInterval` parameter)
- **Lightweight**: Only fetches calories and steps (not extended metrics)
- **Efficient**: Uses `StreamController.broadcast()` for multiple listeners
- **Graceful Cleanup**: Disposes subscriptions and timers on widget disposal

### Apple Health Integration
- Fetches:
  - `ACTIVE_ENERGY_BURNED`: Energy from exercise/intentional activity
  - `BASAL_ENERGY_BURNED`: Resting metabolic rate
  - `STEPS`: Daily step count
- Permission already configured via existing health service flow

### Performance Optimizations
- Separate quick snapshot fetch (`_fetchQuickSnapshot`) vs. deep snapshot (`fetchDeepSnapshot`)
- Stream-based updates prevent redundant calculations
- Proper cleanup prevents memory leaks

## Files Modified

1. **lib/services/health_service.dart**
   - Added `fetchedAt` timestamp to `HealthSnapshot`
   - Added stream-based methods for real-time updates
   - Implemented timer-based periodic fetching

2. **lib/widgets.dart**
   - Enhanced `CalorieDonut` widget signature
   - Updated `_DonutPainter` for three-ring visualization
   - Added "🔥 XXX burned" display

3. **lib/screens.dart**
   - Added stream subscription management
   - Implemented `_startRealtimeHealthStream()`
   - Updated `initState()` and `dispose()` for proper lifecycle
   - Modified `CalorieDonut` instantiation

## Testing & Debugging

### Debug Mode Connection
- **Device**: Mansi's iPhone (USB connected)
- **Device ID**: 00008120-000431990ABBA01E
- **iOS Version**: 26.5 (23F77)
- **Status**: ✅ Running successfully in debug mode

### Debugging Access
- Dart VM Service: `http://127.0.0.1:51674/1uJe7xM0VEc=/`
- Flutter DevTools: `http://127.0.0.1:51674/1uJe7xM0VEc=/devtools/?uri=ws://127.0.0.1:51674/1uJe7xM0VEc=/ws`
- Hot reload available with `r` command

### How to Test
1. **Apple Health Data**: Ensure iPhone has some activity data or manually enter calories
2. **Watch the Dashboard**: 
   - Check the calorie donut in the main dashboard
   - Observe the three rings updating in real-time
   - The center value shows effective calories decreasing
   - The "🔥 XXX burned" updates every second
3. **Monitor Logs**: Check console for any health data fetch errors

## Future Enhancements

1. **Configurable Refresh Rate**: Allow users to adjust real-time update frequency
2. **Historical Tracking**: Store hourly snapshots for analytics
3. **Predictive Analysis**: Estimate when user will reach 0 effective calories
4. **Goal Celebration**: Animation when reaching 0 or negative effective calories
5. **Apple Watch Support**: Direct integration with watchOS health data
6. **Notifications**: Alert when user hits goal or negative calories
