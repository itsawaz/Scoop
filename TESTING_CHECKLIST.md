# ✅ Testing Checklist - API Rate Limit Solution

## Pre-Flight Check

Before testing, verify:
- [ ] Flutter is up to date: `flutter doctor`
- [ ] Dependencies are installed: `flutter pub get`
- [ ] No compilation errors: `flutter analyze`
- [ ] Device/simulator is ready

---

## Phase 1: Basic Functionality (15 minutes)

### Test 1: Meal Logging with Photo
- [ ] Open app → Log Meal tab
- [ ] Take/select a photo of food
- [ ] Add description (e.g., "grilled chicken breast 200g")
- [ ] Tap "Analyze"
- [ ] **Expected**: Meal analyzed successfully, shows nutrition data
- [ ] **Check**: No errors in console
- [ ] **Check**: Response time < 5 seconds

### Test 2: Meal Logging with Text Only
- [ ] Open Log Meal tab
- [ ] Enter text description only (no photo)
- [ ] Example: "2 eggs scrambled with cheese"
- [ ] Tap "Analyze"
- [ ] **Expected**: Meal analyzed successfully
- [ ] **Check**: Nutrition data looks reasonable

### Test 3: Meal Corrections
- [ ] After analyzing a meal, make a correction
- [ ] Example: "Actually it was 300g not 200g"
- [ ] Send correction
- [ ] **Expected**: Updated nutrition data
- [ ] **Check**: Calories adjusted proportionally

### Test 4: Supplement Search
- [ ] Open Log Supplement sheet
- [ ] Switch to "Search" tab
- [ ] Search for "whey protein"
- [ ] **Expected**: Results appear with nutrition info
- [ ] **Check**: Can log the supplement

### Test 5: Supplement Scan
- [ ] Open Log Supplement sheet
- [ ] Switch to "Scan Label" tab
- [ ] Take photo of supplement label
- [ ] **Expected**: Nutrition info extracted
- [ ] **Check**: Values look accurate

### Test 6: Coach Chat
- [ ] Open Coach tab
- [ ] Send a message (e.g., "What should I eat for dinner?")
- [ ] **Expected**: Mann responds with advice
- [ ] **Check**: Response is relevant and helpful

---

## Phase 2: API Usage Monitoring (10 minutes)

### Test 7: Check Usage Indicator
- [ ] Open Profile tab
- [ ] Scroll to API Usage section
- [ ] **Expected**: Shows "X of 1,000 requests remaining"
- [ ] **Check**: Number is reasonable (should be 990-995 after Phase 1 tests)
- [ ] **Check**: Progress bar is green
- [ ] **Check**: Shows correct percentage

### Test 8: Usage Updates After Actions
- [ ] Note current remaining requests
- [ ] Log a meal
- [ ] Return to Profile
- [ ] **Expected**: Remaining requests decreased by 1-2
- [ ] **Check**: Updates in real-time

### Test 9: Usage Indicator Colors
- [ ] **Green**: >50% remaining (normal state)
- [ ] **Yellow**: 20-50% remaining (approaching limit)
- [ ] **Red**: <20% remaining (near limit)
- [ ] **Note**: You'll see green initially, others require heavy usage

---

## Phase 3: Multi-Key Support (20 minutes)

### Test 10: Add Second API Key
- [ ] Create a new Google Cloud project at aistudio.google.com
- [ ] Generate API key for new project
- [ ] Open app → Profile tab
- [ ] Scroll to "Backup API Key 2"
- [ ] Paste the new key
- [ ] Tap "Save Profile"
- [ ] **Expected**: "Saved!" confirmation
- [ ] **Check**: Usage indicator now shows "X of 2,000 requests remaining"

### Test 11: Add Third API Key
- [ ] Create another Google Cloud project
- [ ] Generate API key
- [ ] Add to "Backup API Key 3" field
- [ ] Save Profile
- [ ] **Expected**: Usage indicator shows "X of 3,000 requests remaining"

### Test 12: Verify Key Rotation
- [ ] Log 5-10 meals in succession
- [ ] Check Google Cloud console for each project
- [ ] **Expected**: Usage distributed across all 3 keys
- [ ] **Check**: Each key shows 1-4 requests

### Test 13: Remove a Key
- [ ] Clear "Backup API Key 3" field
- [ ] Save Profile
- [ ] **Expected**: Usage indicator shows "X of 2,000 requests remaining"
- [ ] **Check**: App still works with 2 keys

---

## Phase 4: Rate Limiting (15 minutes)

### Test 14: Normal Rate Limiting
- [ ] Log 3-5 meals rapidly (within 1 minute)
- [ ] **Expected**: All succeed
- [ ] **Check**: No rate limit errors
- [ ] **Check**: Requests spread across keys

### Test 15: Usage Tracking
- [ ] Note starting remaining requests
- [ ] Log 10 meals
- [ ] Check remaining requests
- [ ] **Expected**: Decreased by ~10-15 (some corrections)
- [ ] **Check**: Math adds up

### Test 16: Approaching Limit Warning
- [ ] **Note**: This requires heavy usage (200+ requests)
- [ ] **Alternative**: Manually test by checking code
- [ ] **Expected**: Yellow/red indicator when <50% remaining
- [ ] **Expected**: Helpful tip appears suggesting more keys

---

## Phase 5: Error Handling (10 minutes)

### Test 17: Invalid API Key
- [ ] Open Profile
- [ ] Change primary key to "invalid_key_123"
- [ ] Save Profile
- [ ] Try to log a meal
- [ ] **Expected**: Clear error message
- [ ] **Check**: Suggests checking API key in Profile

### Test 18: No API Keys
- [ ] Clear all 3 API key fields
- [ ] Save Profile
- [ ] Try to log a meal
- [ ] **Expected**: "No API key configured" message
- [ ] **Check**: Directs user to Profile settings

### Test 19: Network Error
- [ ] Turn off WiFi/data
- [ ] Try to log a meal
- [ ] **Expected**: Network error message
- [ ] **Check**: App doesn't crash
- [ ] Turn WiFi back on
- [ ] Retry → should work

---

## Phase 6: Model Quality (10 minutes)

### Test 20: Simple Meal Quality
- [ ] Log a simple meal: "banana"
- [ ] **Expected**: ~105 calories, 27g carbs, 1g protein
- [ ] **Check**: Within 10% of actual values

### Test 21: Complex Meal Quality
- [ ] Log a complex meal with photo
- [ ] Example: "chicken stir fry with vegetables and rice"
- [ ] **Expected**: Reasonable calorie estimate (400-600)
- [ ] **Check**: Macros are balanced

### Test 22: Correction Quality
- [ ] Log a meal
- [ ] Make a correction: "double the portion"
- [ ] **Expected**: Calories roughly double
- [ ] **Check**: Proportions maintained

---

## Phase 7: Edge Cases (10 minutes)

### Test 23: Very Long Description
- [ ] Enter a very long meal description (200+ words)
- [ ] **Expected**: Still processes successfully
- [ ] **Check**: Response time < 10 seconds

### Test 24: Special Characters
- [ ] Log meal with emojis: "🍕 pizza 🍕"
- [ ] **Expected**: Works normally
- [ ] **Check**: Emojis don't break parsing

### Test 25: Multiple Rapid Requests
- [ ] Log 3 meals simultaneously (if possible)
- [ ] **Expected**: All process successfully
- [ ] **Check**: Keys rotate properly
- [ ] **Check**: No race conditions

---

## Phase 8: Performance (5 minutes)

### Test 26: Response Time
- [ ] Log 5 meals and time each one
- [ ] **Expected**: Average < 3 seconds
- [ ] **Check**: No timeouts
- [ ] **Check**: Consistent performance

### Test 27: Memory Usage
- [ ] Log 20 meals in one session
- [ ] **Expected**: No memory leaks
- [ ] **Check**: App remains responsive
- [ ] **Check**: No crashes

---

## Phase 9: Integration (10 minutes)

### Test 28: Saved Meals Library
- [ ] Log a meal and save to library
- [ ] Use saved meal later
- [ ] **Expected**: Zero API calls for saved meal
- [ ] **Check**: Usage counter doesn't increase

### Test 29: Coach Integration
- [ ] Log a meal
- [ ] Ask coach about the meal
- [ ] **Expected**: Coach knows about recent meals
- [ ] **Check**: Contextual responses

### Test 30: Health Data Sync
- [ ] Log a meal
- [ ] Check Apple Health (if connected)
- [ ] **Expected**: Calories written to Health
- [ ] **Check**: Data syncs correctly

---

## Final Verification

### Checklist Summary
- [ ] All 30 tests passed
- [ ] No critical errors
- [ ] Performance acceptable
- [ ] Multi-key support works
- [ ] Rate limiting works
- [ ] Error handling works
- [ ] Documentation complete

### Console Check
- [ ] No red errors in Flutter console
- [ ] Only expected warnings (if any)
- [ ] API calls succeed
- [ ] Usage tracking works

### User Experience Check
- [ ] App feels responsive
- [ ] No confusing error messages
- [ ] UI is intuitive
- [ ] Help text is clear

---

## Issue Tracking

### Issues Found

| # | Test | Issue | Severity | Status |
|---|------|-------|----------|--------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |

### Severity Levels:
- **Critical**: Blocks core functionality
- **High**: Major feature broken
- **Medium**: Minor feature issue
- **Low**: Cosmetic or edge case

---

## Sign-Off

### Testing Completed By:
- **Name**: _______________
- **Date**: _______________
- **Environment**: iOS / Android / Both
- **Flutter Version**: _______________

### Results:
- **Tests Passed**: ___ / 30
- **Tests Failed**: ___ / 30
- **Critical Issues**: ___
- **Ready for Production**: Yes / No

### Notes:
```
[Add any additional notes or observations here]
```

---

## Quick Test (5 minutes)

If you're short on time, run these essential tests:

1. [ ] Log a meal with photo → Works
2. [ ] Check API usage indicator → Shows correct count
3. [ ] Add 2nd API key → Saves and updates limit
4. [ ] Log 3 more meals → Keys rotate, all succeed
5. [ ] Check console → No errors

**If all 5 pass**: Ready to deploy! 🚀

---

## Automated Testing (Future)

Consider adding these automated tests:

```dart
// test/api_service_test.dart
test('ApiService rotates keys correctly', () async {
  // Test key rotation logic
});

test('ApiRateLimiter prevents exceeding limits', () async {
  // Test rate limiting
});

test('ApiKeyManager tracks usage correctly', () async {
  // Test usage tracking
});
```

**Estimated effort**: 4-6 hours for full test suite

---

**Last Updated**: May 31, 2026
**Version**: 1.0.0
**Status**: Ready for Testing
