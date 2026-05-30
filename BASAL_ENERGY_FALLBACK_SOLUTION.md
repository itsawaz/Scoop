# Basal Energy Fallback Solution

## Problem Solved
Resting calories (basal energy) show as 0 because Apple Health only tracks this data when:
- An Apple Watch is actively tracking workouts/activity
- User manually enters data
- Third-party apps share data

## Solution Implemented
**Smart Fallback System** that:
1. ✅ **Tries to get real data from Apple Health first**
2. ✅ **Falls back to estimated calculation if no data exists**
3. ✅ **Updates in real-time** based on time elapsed since midnight

## How It Works

### Real-Time Basal Calorie Calculation
```
Daily BMR: 2400 calories/day (customizable)
Calories per second: 2400 ÷ 86400 = 0.0278 cal/sec
Elapsed time: Current time - Midnight
Estimated basal: 0.0278 × elapsed seconds
```

### Example
If it's 12:00 PM (noon):
- Elapsed time: 12 hours = 43,200 seconds
- Estimated basal: 0.0278 × 43,200 = **1,200 calories**

The circle updates every 5 seconds, so you'll see it grow throughout the day!

## Code Changes

### 1. Added Estimated BMR Setting
```dart
// Default: 2400 cal/day
double _estimatedDailyBMR = 2400.0;

// User can customize this
void setEstimatedDailyBMR(double caloriesPerDay) {
  _estimatedDailyBMR = caloriesPerDay;
}
```

### 2. Real-Time Calculation Function
```dart
double _calculateEstimatedBasalCalories(DateTime midnight, DateTime now) {
  final secondsSinceMidnight = now.difference(midnight).inSeconds;
  final caloriesPerSecond = _estimatedDailyBMR / 86400.0;
  return caloriesPerSecond * secondsSinceMidnight;
}
```

### 3. Smart Fallback Logic
```dart
if (basalCals > 0) {
  // Use real HealthKit data
  basalIsEstimated = false;
} else {
  // Fall back to estimated calculation
  basalCals = _calculateEstimatedBasalCalories(midnight, now);
  basalIsEstimated = true;
}
```

### 4. Added Flag to Track Data Source
```dart
class HealthSnapshot {
  final bool basalIsEstimated; // true = estimated, false = from HealthKit
  // ...
}
```

## Usage

### Default Behavior
The app now automatically uses 2400 cal/day as the default BMR when no HealthKit data is available.

### Customizing BMR
To set a custom daily BMR (e.g., 2800 calories/day):
```dart
HealthService().setEstimatedDailyBMR(2800.0);
```

### Checking Data Source
```dart
final snapshot = await HealthService().fetchDeepSnapshot();
if (snapshot.basalIsEstimated) {
  print('Using estimated basal calories');
} else {
  print('Using real HealthKit data');
}
```

## Benefits

1. **Always Shows Data**: Circle never stays at 0
2. **Real-Time Updates**: Updates every 5 seconds as time passes
3. **Smooth Animation**: Circle grows gradually throughout the day
4. **Accurate When Possible**: Uses real HealthKit data when available
5. **Graceful Fallback**: Estimates when real data isn't available

## Calculating Your Personal BMR

Use the **Mifflin-St Jeor Equation**:

### For Men:
```
BMR = (10 × weight_kg) + (6.25 × height_cm) - (5 × age) + 5
```

### For Women:
```
BMR = (10 × weight_kg) + (6.25 × height_cm) - (5 × age) - 161
```

### Example Calculations:

**30-year-old male, 75kg, 175cm:**
- BMR = (10 × 75) + (6.25 × 175) - (5 × 30) + 5
- BMR = 750 + 1,093.75 - 150 + 5
- BMR = **1,698.75 ≈ 1,700 cal/day**

**30-year-old female, 60kg, 165cm:**
- BMR = (10 × 60) + (6.25 × 165) - (5 × 30) - 161
- BMR = 600 + 1,031.25 - 150 - 161
- BMR = **1,320.25 ≈ 1,320 cal/day**

### Total Daily Energy Expenditure (TDEE)
Multiply BMR by activity level:
- **Sedentary** (little/no exercise): BMR × 1.2
- **Lightly active** (1-3 days/week): BMR × 1.375
- **Moderately active** (3-5 days/week): BMR × 1.55
- **Very active** (6-7 days/week): BMR × 1.725
- **Extremely active** (athlete): BMR × 1.9

Example: 1,700 BMR × 1.55 (moderately active) = **2,635 cal/day**

## Next Steps

### Option 1: Add User Profile Settings
Create a settings screen where users can enter:
- Age
- Weight
- Height
- Gender
- Activity level

Then calculate personalized BMR automatically.

### Option 2: Use Default for Now
The default 2400 cal/day is a reasonable estimate for an average adult male.

### Option 3: Get Apple Watch
For the most accurate tracking, an Apple Watch will provide real-time basal and active energy data.

## Testing

Run the app and check the logs:
```
[HealthService] Basal calories: 1200.0 (ESTIMATED)
[HealthService] Using estimated basal calories: 1200.0 (2400 cal/day)
```

The circle should now show basal calories growing throughout the day!
