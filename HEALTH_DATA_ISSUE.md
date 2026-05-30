# Resting Calories Showing 0 - Issue Analysis

## Problem
Resting calories (basal metabolic rate) are showing as 0 in the UI even though they exist in the Apple Health app.

## Root Cause

### 1. HealthKit Permission Issue
The app requests permissions for `BASAL_ENERGY_BURNED` type, but iOS 14+ requires **explicit user permission** for each HealthKit type. The permission request may be failing silently or the user may not have granted permission for basal energy data.

### 2. Data Availability in Apple Health
- **Active Energy Burned**: Readily available from activity tracking (steps, workouts, Apple Watch)
- **Basal Energy Burned (Resting Calories)**: Only available if:
  - User has an Apple Watch with metabolic data enabled
  - User has manually entered basal metabolic rate data
  - User has connected apps that share basal energy data (like MyFitnessPal, Lose It!)

### 3. iOS HealthKit Query Behavior
The `getHealthDataFromTypes` function in `SwiftHealthPlugin.swift` uses `HKStatisticsCollectionQuery` which:
- Returns cumulative sums over time intervals
- May return empty results if no data points exist for the requested date
- Requires proper date range predicates

## How Apple Health Stores Basal Energy

### Source Types:
1. **Apple Watch** (primary source):
   - Requires watchOS 7+ with metabolic rate tracking enabled
   - Needs user profile data (age, weight, height, gender)
   - Must have "Activity" and "Health" permissions enabled

2. **Manual Entry**:
   - User can manually enter BMR in Health app
   - Typically stored as "Basal Energy Burned"

3. **Third-party Apps**:
   - Apps like MyFitnessPal, Lose It!, Fitbit may share basal data

## Debug Steps

### 1. Check Health Data Availability
Open the Health app on your iPhone and navigate to:
- **Health app** → **Browse** → **Activity** → **Basal Energy Burned**
- Check if any data exists for today

### 2. Verify App Permissions
Go to **Settings** → **Privacy & Security** → **Health** → **Scoop**
- Ensure "Basal Energy Burned" has **Read** permission enabled

### 3. Check Apple Watch Settings
If using Apple Watch:
- **Watch app** → **Privacy** → **Health** → **Scoop**
- Ensure all health data permissions are granted

### 4. Enable Developer Mode (iOS 16+)
- **Settings** → **Privacy & Security** → **Developer Mode**
- Enable Developer Mode and restart device

## Solution Options

### Option 1: Fix Permission Handling (Recommended)
Update the permission request to handle basal energy properly:

```dart
// In health_service.dart, ensure BASAL_ENERGY_BURNED is in the read types
static const _readTypes = [
  HealthDataType.STEPS,
  HealthDataType.ACTIVE_ENERGY_BURNED,
  HealthDataType.BASAL_ENERGY_BURNED,  // Already present
  // ... other types
];
```

### Option 2: Add Fallback Calculation
If basal energy data is unavailable, calculate it using Mifflin-St Jeor equation:

```dart
double calculateBasalMetabolicRate(double weightKg, double heightCm, int age, bool isMale) {
  // Mifflin-St Jeor Equation
  if (isMale) {
    return (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
  } else {
    return (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
  }
}
```

### Option 3: Improve Data Fetching
Update the iOS HealthKit query to handle empty results gracefully:

```swift
// In SwiftHealthPlugin.swift, getIntervalData function
// Add better error handling and fallback logic
```

## Testing Checklist

- [ ] Open Health app → Browse → Activity → Basal Energy Burned
- [ ] Verify data exists for today
- [ ] Check Settings → Privacy → Health → Scoop permissions
- [ ] If using Apple Watch, verify Watch app permissions
- [ ] Enable Developer Mode on iPhone
- [ ] Rebuild and reinstall the debug version
- [ ] Check Flutter DevTools console for health data logs

## Logs to Check

When running with `flutter run --debug`, look for these log messages:
```
[HealthService] Basal energy point: X (cumulative: Y)
[HealthService] Totals - Active: X, Basal: Y, Steps: Z
```

If you see `Basal: 0.0`, the data is not being retrieved from HealthKit.

## Next Steps

1. Check if basal energy data exists in Health app
2. Verify app permissions are granted
3. If data exists but still shows 0, there may be a query issue
4. Consider implementing fallback BMR calculation
## Fix Applied

### Root Cause
The issue was that `getHealthDataFromTypes` uses `HKSampleQuery` on iOS, which may not return results for energy types (`ACTIVE_ENERGY_BURNED` and `BASAL_ENERGY_BURNED`). This is a known limitation of the Flutter health plugin.

### Solution Implemented
Created a new helper function `_fetchEnergyData` that uses `getIntervalData` instead, which uses `HKStatisticsCollectionQuery`. This approach:
- Returns cumulative sums over time intervals
- Works reliably for energy data on iOS
- Properly handles source separation

### Changes Made
1. Added `_fetchEnergyData` helper function that uses `getIntervalData` with `interval: 0` for cumulative data
2. Updated `_fetchQuickSnapshot` to use the new helper for energy data
3. Updated `fetchDeepSnapshot` to use the new helper for energy data

### Testing
Run the app and check the logs:
```
[HealthService] === Health Data Summary ===
[HealthService] Active energy points: X
[HealthService] Basal energy points: X
[HealthService] Active calories: X.X
[HealthService] Basal calories: X.X
```

If you still see `WARNING: No basal energy data found in HealthKit!`, it means:
1. No basal energy data exists in Apple Health
2. You need an Apple Watch with metabolic tracking or manual entry

### Next Steps
1. Check Apple Health app → Browse → Activity → Basal Energy Burned
2. If data exists, verify app permissions in Settings → Privacy → Health
3. If using Apple Watch, ensure metabolic tracking is enabled
