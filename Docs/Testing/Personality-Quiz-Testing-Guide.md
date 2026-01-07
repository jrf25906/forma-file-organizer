# Personality Quiz Testing Guide

This document provides a comprehensive manual testing guide for the personality quiz onboarding system.

## Test Environment Setup

Before testing, ensure:
1. Build the app in Debug mode
2. Clear any existing personality data: `defaults delete com.forma.file-organizing userOrganizationPersonality`
3. Clear onboarding state if needed to retrigger
4. Launch the app

## Test Scenarios

### Scenario 1: First Launch - Visual Organizer (Piler)

**Profile**: Creative professional who works visually and likes to see files

**Steps**:
1. Launch app for the first time
2. **Step 1/2 - Permissions**:
   - Verify "Welcome to Forma" header appears
   - Verify step dots show (1 active, 1 inactive)
   - Grant all 5 permissions (Desktop, Downloads, Documents, Pictures, Music)
   - Click "Continue"
3. **Step 2/2 - Personality Quiz**:
   - Verify step dots updated (1 completed/green, 1 active/blue)
   - **Q1**: Select "Scan Desktop or Downloads visually"
   - **Q2**: Select "Covered with files I'm working on"
   - **Q3**: Select "Projects and clients"
   - Click "See Results"
4. **Result Screen**:
   - Verify personality title shows: "Visual Organizer"
   - Verify recommended template: "Minimal"
   - Click "Continue"
5. **Dashboard**:
   - Open view mode selector
   - Verify default view mode is **Grid** (pilers prefer visual grids)
   - Check Documents category - should also default to Grid
   
**Expected Personality**:
- Organization Style: Piler
- Thinking Style: Visual
- Mental Model: Project-Based
- Suggested Template: Minimal
- Suggested Folder Depth: 2 levels
- Preferred View Mode: Grid
- Suggestions Frequency: Frequent

---

### Scenario 2: First Launch - Systematic Organizer (Filer + Hierarchical)

**Profile**: Academic or knowledge worker who likes deep folder structures

**Steps**:
1. Clear personality data and relaunch
2. **Step 1/2 - Permissions**: Grant all, click Continue
3. **Step 2/2 - Personality Quiz**:
   - **Q1**: Select "Navigate through my folder structure"
   - **Q2**: Select "Empty, everything is organized away"
   - **Q3**: Select "Categories and topics"
   - Click "See Results"
4. **Result Screen**:
   - Verify personality title: "Systematic Organizer"
   - Verify recommended template: "Johnny Decimal"
   - Click "Continue"
5. **Dashboard**:
   - Verify default view mode is **List** (filers prefer details)
   - Check multiple categories - most should default to List

**Expected Personality**:
- Organization Style: Filer
- Thinking Style: Hierarchical
- Mental Model: Topic-Based
- Suggested Template: Johnny Decimal
- Suggested Folder Depth: 5 levels (deep hierarchies)
- Preferred View Mode: List
- Suggestions Frequency: Occasional

---

### Scenario 3: First Launch - Structured Organizer (Filer + Visual + Time)

**Profile**: Business professional who organizes by time periods

**Steps**:
1. Clear personality data and relaunch
2. **Step 1/2 - Permissions**: Grant all, click Continue
3. **Step 2/2 - Personality Quiz**:
   - **Q1**: Select "Check Recent Files or use Search"
   - **Q2**: Select "Empty, everything is organized away"
   - **Q3**: Select "Weeks, months, quarters"
   - Click "See Results"
4. **Result Screen**:
   - Verify personality title: "Structured Organizer"
   - Verify recommended template: "Chronological"
   - Click "Continue"
5. **Dashboard**:
   - Verify default view mode is **List**

**Expected Personality**:
- Organization Style: Filer
- Thinking Style: Visual
- Mental Model: Time-Based
- Suggested Template: Chronological
- Suggested Folder Depth: 3 levels
- Preferred View Mode: List
- Suggestions Frequency: Moderate

---

### Scenario 4: Skip Permissions

**Steps**:
1. Clear personality data and relaunch
2. **Step 1/2 - Permissions**:
   - Do NOT grant any permissions
   - Click "Skip for now"
3. **Step 2/2 - Personality Quiz**:
   - Verify quiz still appears
   - Answer any 3 questions
   - Complete quiz
4. **Dashboard**:
   - Verify personality preferences were applied
   - Note: File scanning won't work without permissions (expected)

**Expected**: Personality quiz is independent of permissions

---

### Scenario 5: Quiz Navigation - Back Button

**Steps**:
1. Clear personality data and relaunch
2. Grant permissions, proceed to quiz
3. **Question 1**: Select any answer
4. Click "Continue"
5. **Question 2**: Select any answer
6. Click "Continue"
7. **Question 3**: Click "Back" button
8. Verify Question 2 shows with previous answer selected
9. Change answer to Question 2
10. Click "Continue" twice
11. Verify new answers are reflected in result

**Expected**: Back navigation works, answers persist and can be changed

---

### Scenario 6: Subsequent Launch - No Quiz

**Steps**:
1. Complete onboarding once (any answers)
2. Quit app
3. Relaunch app
4. Verify onboarding does NOT appear
5. Verify personality preferences are still applied (check view modes)

**Expected**: Quiz only shows on first launch

---

### Scenario 7: Template Selection Pre-Selection

**Steps**:
1. Complete personality quiz (e.g., as Visual Organizer → Minimal template)
2. Navigate to Settings (if implemented) or template selection
3. Open template picker/selector
4. Verify "Minimal" template is pre-selected
5. Verify header says: "Based on your preferences, we recommend Minimal"
6. Verify user can still choose any other template

**Expected**: Template pre-selected but user has full control

---

## UI/UX Validation

### Visual Design
- [ ] Step dots animate smoothly between steps
- [ ] Quiz questions slide in from right, slide out to left
- [ ] Progress bar fills smoothly as user answers questions
- [ ] Answer cards have hover effects (scale, shadow)
- [ ] Selected answer shows blue highlight + checkmark
- [ ] Result screen shows celebration emoji (✨)
- [ ] All spacing uses FormaSpacing tokens
- [ ] All colors use FormaColors palette

### Accessibility
- [ ] Reduce Motion respected (animations disable)
- [ ] All buttons have clear focus states
- [ ] Tab navigation works through all answer cards
- [ ] VoiceOver announces question numbers correctly

### Animations
- [ ] Answer card selection animates smoothly
- [ ] "Continue" button enables/disables with fade
- [ ] Progress bar uses spring animation
- [ ] Step transitions use asymmetric slide+fade

---

## Data Persistence Tests

### Test 1: Personality Saved Correctly
```bash
# After completing quiz, check AppStorage
defaults read com.forma.file-organizing userOrganizationPersonality
```
**Expected**: JSON string containing organizationStyle, thinkingStyle, mentalModel

### Test 2: View Modes Applied
```bash
# After completing quiz as Piler:
defaults read com.forma.file-organizing | grep viewMode
```
**Expected**: Most viewMode values should be "grid"

### Test 3: Clear Personality
```bash
# Clear and verify it re-triggers onboarding
defaults delete com.forma.file-organizing userOrganizationPersonality
```
**Expected**: Onboarding appears again on next launch

---

## Edge Cases

### Test 1: Rapid Clicking
- Click "Continue" button multiple times rapidly
- **Expected**: Only one transition occurs, no duplicate state

### Test 2: Window Resize During Quiz
- Resize window while on quiz screen
- **Expected**: Layout adjusts gracefully (quiz is fixed 600x700)

### Test 3: Quit During Quiz
- Quit app mid-quiz (Question 2)
- Relaunch app
- **Expected**: Onboarding restarts from beginning (no partial save)

---

## Integration Points

### Test 1: Learning System Integration
1. Complete quiz as "Piler" (frequent suggestions)
2. Organize some files
3. Check RuleSuggestionView prominence
4. **Expected**: Pilers see rule suggestions more prominently

### Test 2: Confidence Threshold
1. Complete quiz as "Systematic Organizer" (occasional suggestions)
2. View files with varying confidence scores
3. **Expected**: Lower confidence threshold for highlighting

---

## Automated Test Coverage

The following scenarios are covered by `OrganizationPersonalityTests.swift`:

✅ Model initialization and properties  
✅ Template recommendations for all personality combinations  
✅ Folder depth calculations  
✅ View mode preferences  
✅ Suggestions frequency logic  
✅ Persistence (save/load/clear)  
✅ Quiz answer mapping to personality types  
✅ Codable roundtrip  

**To run automated tests**:
```bash
xcodebuild test -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -destination "platform=macOS"
```

---

## Success Criteria

- [ ] All 7 test scenarios pass
- [ ] UI/UX validation items checked
- [ ] Data persistence works correctly
- [ ] Edge cases handled gracefully
- [ ] Integration points verified
- [ ] All automated tests pass (24 tests in OrganizationPersonalityTests)
- [ ] No crashes or errors in console

---

## Troubleshooting

**Quiz doesn't appear**: Clear personality data with:
```bash
defaults delete com.forma.file-organizing userOrganizationPersonality
```

**Permissions step doesn't show**: Check if permissions already granted

**View modes not applied**: Restart app after completing quiz

**Step dots not showing**: Check that StepDot component is rendering

**Debug logging**: Look for console output:
```
📊 Applying personality preferences: [style], [thinking]
✅ Personality preferences applied - preferredViewMode: [mode]
```
