# Basal Energy (Resting Calories) Showing 0 - Root Cause & Solution

## Root Cause Identified

After debugging with detailed logs, the issue is clear:

**Apple Health does NOT automatically track basal energy (resting calories).** 

The logs show:
```
[HealthService] Active energy points: 0
[HealthService] Basal energy points: 0
[HealthService] Steps: 144
```

Steps are being tracked (144 steps), but **both active and basal energy points are 0**. This means:
1. The app has proper HealthKit permissions ✅
2. The app can read health data (steps work) ✅
3. **Apple Health simply doesn't have energy data to read** ❌

## Why Apple Health Doesn't Have Basal Energy Data

### Basal Energy Requires:
1. **Apple Watch with metabolic tracking** (most common source)
   - Requires watchOS 7+ 
   - Needs user profile data (age, weight, height, gender)
   - Must have "Activity" and "Health" permissions enabled
   - Watch must be worn regularly for accurate tracking

2. **Manual entry in Health app**
   - User can manually add basal metabolic rate
   - Go to Health app → Browse → Activity → Basal Energy Burned → Add Data

3. **Third-party apps** that share basal energy data
   - Apps like MyFitnessPal, Lose It!, Fitbit
   - These apps calculate BMR and share it with Health

### Active Energy Also Shows 0
Active energy (calories burned from activity) also shows 0, which suggests:
- No Apple Watch is connected, OR
- Apple Watch is not tracking activity, OR
- Activity tracking permissions are not granted

## Solution Options

### Option 1: Get an Apple Watch (Recommended)
An Apple Watch will automatically track:
- Basal energy (resting calories)
- Active energy (activity calories)
- Heart rate, workouts, and more

### Option 2: Manual Entry
Manually enter basal energy in the Health app:
1. Open Health app
2. Go to **Browse** → **Activity** → **Basal Energy Burned**
3. Tap **Add Data**
4. Enter your estimated BMR (use calculator below)

**BMR Calculator (Mifflin-St Jeor Equation):**
- **Men**: BMR = (10 × weight in kg) + (6.25 × height in cm) - (5 × age) + 5
- **Women**: BMR = (10 × weight in kg) + (6.25 × height in cm) - (5 × age) - 161

Example: 30-year-old male, 75kg, 175cm:
- BMR = (10 × 75) + (6.25 × 175) - (5 × 30) + 5 = 1,700 kcal/day

### Option 3: Implement Fallback BMR Calculation in App
Add a feature to calculate and display estimated BMR when Health data is unavailable.

## Verification Steps

### Check if Data Exists in Health App
1. Open **Health** app on iPhone
2. Go to **Browse** → **Activity**
3. Check these sections:
   - **Active Energy**: Should show calories burned from activity
   - **Basal Energy Burned**: Should show resting calories
   - **Resting Energy**: Alternative name for basal energy

### Check App Permissions
1. Go to **Settings** → **Privacy & Security** → **Health** → **Scoop**
2. Ensure these are enabled:
   - ✅ Active Energy Burned (Read)
   - ✅ Basal Energy Burned (Read)
   - ✅ Steps (Read)

### If Using Apple Watch
1. Open **Watch** app on iPhone
2. Go to **Privacy** → **Health** → **Scoop**
3. Ensure all permissions are granted
4. Check **Watch** app → **My Watch** → **Activity**
5. Ensure Activity tracking is enabled

## Current App Behavior

The app now:
1. ✅ Properly requests HealthKit permissions
2. ✅ Fetches health data from Apple Health
3. ✅ Logs detailed information for debugging
4. ✅ Shows warning when no basal energy data is found
5. ✅ Handles missing data gracefully (shows 0 instead of crashing)

## Next Steps

1. **Check if you have an Apple Watch**
   - If yes: Ensure it's paired and tracking activity
   - If no: Consider getting one or use manual entry

2. **Verify Health app has data**
   - Open Health app and check Activity section
   - If no data exists, Apple Watch or manual entry is needed

3. **Consider implementing fallback BMR calculation**
   - Ask user for age, weight, height, gender
   - Calculate estimated BMR using Mifflin-St Jeor equation
   - Display estimated value when Health data is unavailable

## Technical Details

### Why getHealthDataFromTypes Returns Empty
On iOS, `getHealthDataFromTypes` uses `HKSampleQuery` which:
- Returns individual health data samples
- Returns empty array if no samples exist in HealthKit
- Cannot "create" data that doesn't exist

### Why Steps Work But Energy Doesn't
- **Steps**: iPhone has built-in motion sensors that track steps automatically
- **Energy**: Requires Apple Watch or manual calculation - iPhone alone cannot measure calorie burn accurately

## Conclusion

**This is not a bug in the app.** The app is working correctly. The issue is that Apple Health doesn't have basal energy data to read because:
1. No Apple Watch is connected/tracking
2. No manual entries have been made
3. No third-party apps are sharing energy data

The solution is to either get an Apple Watch, manually enter BMR data, or implement a fallback BMR calculator in the app.
