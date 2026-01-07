# Forma: Comprehensive Feature Testing Guide

This document provides complete testing procedures for all 6 major features in Forma's intelligence system.

## Quick Reference

| Feature | Status | Components | Priority |
|---------|--------|------------|----------|
| **#1: Match Reasoning** | ✅ Complete | ConfidenceBadge, FileInspectorView | High |
| **#2: Folder Templates** | ✅ Complete | Pre-existing system | Medium |
| **#3: Learning System** | ✅ Complete | LearnedPattern, LearningService, RuleSuggestionView | High |
| **#4: Personality Quiz** | ✅ Complete | Onboarding/OnboardingFlowView, PersonalityQuizView | High |
| **#5: Enhanced Review** | ✅ Complete | ReviewView with confidence grouping, InlineRuleBuilder | High |
| **#6: Context Detection** | ✅ Complete | ProjectCluster, ContextDetectionService, ProjectClusterView | Medium |

---

## Feature #1: Match Reasoning Display

### Overview
Displays why Forma suggested a specific destination for each file, with confidence scoring.

### Components
- **ConfidenceBadge**: Visual indicator (High/Medium/Low) with colors
- **FileRow**: Shows confidence inline with file info
- **FileInspectorView**: Detailed match reasoning card

### Test Scenarios

#### Test 1.1: Confidence Badge Display
**Steps**:
1. Create a rule: "Move *.pdf to Documents/PDFs"
2. Add a file: `report.pdf` to Downloads
3. Scan files
4. View file in grid/list

**Expected**:
- Confidence badge shows on file card
- Badge color: Green (High) if 90%+, Blue (Medium) if 60-89%, Orange (Low) if <60%
- Icon: Shield (High), Circle (Medium), Triangle (Low)
- Hover shows tooltip with percentage

#### Test 1.2: Match Reason in Inspector
**Steps**:
1. Select a file with suggested destination
2. Open Inspector panel (⌘I or click file)
3. Scroll to "Why This Suggestion?" card

**Expected**:
- Card shows confidence icon + percentage
- Match details explain the rule that matched
- Color-coded based on confidence level
- Example: "File extension '.pdf' matches rule 'PDF Organizer' (95% confidence)"

#### Test 1.3: Different Confidence Levels
**Create 3 files to test each level**:
- **High (90%+)**: Exact extension match + name pattern
- **Medium (60-89%)**: Extension match only
- **Low (<60%)**: Partial name match

**Expected**: Each shows appropriate badge color and messaging

---

## Feature #2: Folder Templates

### Overview
Pre-configured organization systems (PARA, Johnny Decimal, Chronological, etc.)

### Templates
1. **Minimal** - 2 levels, for Pilers
2. **PARA** - Projects/Areas/Resources/Archives
3. **Johnny Decimal** - Numbered hierarchical system
4. **Chronological** - Time-based organization
5. **Creative Professional** - Assets/Projects/Clients
6. **Academic** - Courses/Research/Papers

### Test Scenarios

#### Test 2.1: Template Selection
**Steps**:
1. Navigate to template picker (Settings or onboarding)
2. Browse available templates
3. Select "PARA"
4. Click "Apply Template"

**Expected**:
- Templates display with previews
- Folder structure shown for each
- Apply button creates rules
- Success confirmation appears

#### Test 2.2: Template-Generated Rules
**Steps**:
1. Apply "Johnny Decimal" template
2. Navigate to Rules view
3. Inspect generated rules

**Expected**:
- Multiple rules created automatically
- Rules follow template's organization logic
- Can edit/delete individual rules
- Can add custom rules alongside template

---

## Feature #3: Learning System

### Overview
Detects patterns from user behavior and suggests new rules automatically.

### Components
- **LearnedPattern** model: Tracks recurring file→destination patterns
- **LearningService**: Pattern detection algorithm
- **RuleSuggestionView**: UI for one-click rule creation

### Test Scenarios

#### Test 3.1: Pattern Detection
**Steps**:
1. Manually move 3+ `*.sketch` files to `Design/Sketches`
2. Wait for pattern detection (or trigger refresh)
3. Check Dashboard → Insights section

**Expected**:
- Pattern card appears: "*.sketch files → Design/Sketches"
- Shows occurrence count (e.g., "3 times")
- Displays confidence badge
- "Create Rule" button present

#### Test 3.2: Confidence Calculation
**Test with varying occurrences**:
- 3 occurrences → Medium confidence (~60%)
- 5 occurrences → High confidence (~80%)
- 10 occurrences → Very high confidence (90%+)

**Expected**: Confidence increases with frequency

#### Test 3.3: Rejection Tracking
**Steps**:
1. Get a suggestion for `invoice.pdf` → `Documents/Invoices`
2. Reject suggestion (skip or move elsewhere)
3. Repeat rejection 2 more times
4. Check if pattern confidence decreases

**Expected**:
- Rejection count tracked on pattern
- Confidence score decreases
- Pattern may disappear if rejection rate > 50%

#### Test 3.4: One-Click Rule Creation
**Steps**:
1. Find learned pattern card
2. Click "Create Rule" button
3. Rule editor opens with pre-filled values

**Expected**:
- Rule name auto-generated (e.g., "Sketch Files Organizer")
- Condition: File extension = "sketch"
- Action: Move to "Design/Sketches"
- Can edit before saving

#### Test 3.5: Pattern Dismissal
**Steps**:
1. Find learned pattern
2. Click "Dismiss" or "X"
3. Refresh insights

**Expected**:
- Pattern removed from view
- Does not reappear unless pattern strengthens significantly

---

## Feature #4: Personality Quiz

### Overview
Onboarding quiz that personalizes Forma based on organization style.

*Full testing guide available in: `Personality-Quiz-Testing-Guide.md`*

### Quick Test
**Steps**:
1. Clear personality: `defaults delete com.forma.file-organizing userOrganizationPersonality`
2. Launch app
3. Complete onboarding:
   - Grant permissions
   - Answer 3 quiz questions
   - See personality result
4. Check dashboard view mode matches personality

**Expected**:
- Pilers → Grid view by default
- Filers → List view by default
- Template pre-selected based on personality

---

## Feature #5: Enhanced Review Workflow

### Overview
Improved review screen with confidence grouping and inline rule creation.

### Components
- **ConfidenceBadge**: Already tested in Feature #1
- **ReviewView**: Groups files by confidence + destination
- **DestinationGroupView**: Collapsible file groups
- **InlineRuleBuilder**: Quick rule creation from file

### Test Scenarios

#### Test 5.1: Confidence Grouping
**Setup**:
1. Create files with varying confidence:
   - 5 × `*.pdf` files (High confidence via strong rule)
   - 3 × `*_draft.docx` files (Medium confidence)
   - 2 × random files (Low confidence)
2. Navigate to Review screen

**Expected**:
- Files grouped by destination AND confidence
- Groups sorted: High → Medium → Low
- Each group shows confidence badge in header
- File count + total size displayed per group

#### Test 5.2: Group Expand/Collapse
**Steps**:
1. In Review view, click group header
2. Observe file list
3. Click header again

**Expected**:
- First click: Expands to show all files in group
- Second click: Collapses group
- Chevron icon rotates (down = expanded, right = collapsed)
- Smooth animation

#### Test 5.3: Batch Actions
**Steps**:
1. Hover over a collapsed group
2. Observe action buttons
3. Click "Accept All"

**Expected**:
- "Accept All" and "Skip All" buttons appear on hover
- "Accept All (N)" shows file count
- Clicking organizes all files in group
- Success toast appears
- Files removed from review list

#### Test 5.4: Similar Files Preview
**Steps**:
1. Expand a group with 5+ files
2. Examine file list within group

**Expected**:
- All files visible in expanded group
- Files show individual confidence badges
- Can act on files individually (Organize/Skip)
- Can create rule from any file

#### Test 5.5: Inline Rule Creation
**Steps**:
1. In Review view, find a file
2. Click "Create Rule" button/icon on file row
3. Inline rule builder appears

**Expected**:
- Rule builder opens without leaving Review
- File details pre-populate condition fields
- Suggested destination pre-filled
- Can save rule and immediately apply to file
- File updated with new rule's confidence

---

## Feature #6: Context Detection

### Overview
Automatically detects groups of related files (projects, work sessions) and suggests organizing them together.

### Components
- **ProjectCluster** model: Represents detected file groups
- **ContextDetectionService**: 4 detection algorithms
- **ProjectClusterView**: UI for cluster management

### Detection Algorithms
1. **Project Code** - Regex: `P-1024`, `JIRA-456`, `CLIENT_ABC`
2. **Temporal** - Files modified within 5 minutes
3. **Name Similarity** - Levenshtein distance ≥60%
4. **Date Stamp** - Files with matching date prefixes

### Test Scenarios

#### Test 6.1: Project Code Detection
**Setup**:
1. Create files:
   - `P-1024_proposal.pdf`
   - `P-1024_budget.xlsx`
   - `P-1024_timeline.png`
2. Scan files
3. Navigate to Dashboard → Smart Clusters

**Expected**:
- Cluster detected: "Project P-1024"
- Cluster type: Project Code
- Confidence: High (95%)
- Shows 3 files
- Suggested folder: "Project P-1024"

#### Test 6.2: Temporal Clustering
**Setup**:
1. Create/modify 4 files within 5 minutes:
   - `design_v1.sketch`
   - `design_v2.sketch`
   - `design_v3.sketch`
   - `feedback.txt`
2. Scan files

**Expected**:
- Cluster detected: "Work Session"
- Cluster type: Temporal
- Confidence: Medium-High (75%)
- All 4 files grouped
- Suggested folder: "Design Work Session"

#### Test 6.3: Name Similarity Detection
**Setup**:
1. Create files:
   - `report_draft.docx`
   - `report_final.docx`
   - `report_revised.docx`
2. Scan files

**Expected**:
- Cluster detected: "Related Files" or "Report"
- Cluster type: Name Similarity
- Confidence: High (85%)
- Common prefix detected: "report"
- Suggested folder: "Report Versions"

#### Test 6.4: Date Stamp Detection
**Setup**:
1. Create files:
   - `2024-11-15_meeting_notes.txt`
   - `2024-11-15_agenda.pdf`
   - `2024-11-15_slides.key`
2. Scan files

**Expected**:
- Cluster detected: "Date 2024-11-15"
- Cluster type: Date Stamp
- Confidence: High (90%)
- Date pattern: "2024-11-15"
- Suggested folder: "Date 2024-11-15"

#### Test 6.5: Cluster Organization
**Steps**:
1. Find cluster in Smart Clusters view
2. Click "Organize Together" button
3. Sheet appears with options
4. Confirm folder name
5. Click "Organize Files"

**Expected**:
- Modal shows all files in cluster
- Can edit destination folder name
- Can toggle "Create new folder"
- Clicking organizes all files at once
- Cluster marked as organized
- Files moved to destination
- Success confirmation

#### Test 6.6: Cluster Dismissal
**Steps**:
1. Find cluster card
2. Click "Dismiss" button
3. Refresh clusters view

**Expected**:
- Cluster removed from view
- Marked as dismissed in database
- Does not reappear unless files change

#### Test 6.7: Confidence Thresholds
**Test minimum cluster requirements**:
- Must have ≥3 files (2 files = not shown)
- Must have ≥50% confidence (49% = not shown)

**Expected**: Low-confidence or small clusters filtered out

---

## Integration Tests

### Test INT-1: Learning + Review Workflow
**Scenario**: Pattern → Rule → Review
1. Manually organize files (create pattern)
2. Learning system detects pattern
3. Create rule from pattern
4. New matching files appear
5. Review with confidence badges

**Expected**: Full workflow from learning to organized files

### Test INT-2: Personality + Templates
**Scenario**: Quiz → Template → View Mode
1. Complete personality quiz as "Systematic Organizer"
2. Recommended template: Johnny Decimal
3. Check default view mode: List
4. Verify folder depth preference: 5 levels

**Expected**: All preferences applied cohesively

### Test INT-3: Context Detection + Review
**Scenario**: Cluster → Organize → Review Remaining
1. Detect cluster of 5 files
2. Organize 3 files from cluster
3. Check if remaining 2 still cluster
4. Review remaining files individually

**Expected**: Partial cluster organization handled gracefully

---

## Performance Tests

### Test PERF-1: Large File Sets
**Scenario**: 1000+ files
1. Scan folder with 1000 files
2. Measure confidence calculation time
3. Measure grouping performance
4. Check UI responsiveness

**Expected**: 
- Scanning completes in <10s
- UI remains responsive
- Grouping completes in <2s
- No memory leaks

### Test PERF-2: Pattern Detection Scale
**Scenario**: 50+ unique patterns
1. Create 50 different file patterns
2. Each pattern has 3-5 occurrences
3. Trigger pattern detection

**Expected**:
- All patterns detected
- Confidence scores accurate
- UI displays top 10 patterns
- "Load more" option for rest

---

## Accessibility Tests

### Test A11Y-1: Keyboard Navigation
**Test all features with keyboard only**:
- Tab through file cards
- Arrow keys for grid navigation
- Enter to select files
- Space to toggle selections
- Cmd+A for select all

**Expected**: All features fully keyboard accessible

### Test A11Y-2: VoiceOver
**Test with VoiceOver enabled**:
- Confidence badges announce correctly
- File groupings announced
- Cluster descriptions clear
- Rule suggestions understandable

**Expected**: All content properly announced

### Test A11Y-3: Reduced Motion
**Test with Reduce Motion enabled**:
- Animations disable gracefully
- Functionality preserved
- No janky transitions

**Expected**: Smooth experience without animations

---

## Error Handling Tests

### Test ERR-1: Permission Denied
**Scenario**: No folder access
1. Revoke folder permissions
2. Try to scan files
3. Try to move files

**Expected**:
- Clear error message
- Option to re-grant permission
- Graceful fallback

### Test ERR-2: Invalid Patterns
**Scenario**: Corrupted learned pattern
1. Manually corrupt pattern in SwiftData
2. Load insights view

**Expected**:
- Error logged
- Pattern skipped
- App doesn't crash
- Other patterns load

### Test ERR-3: Missing Destination
**Scenario**: Rule points to deleted folder
1. Create rule → "Missing/Folder"
2. File matches rule
3. Try to organize

**Expected**:
- Error: "Destination not found"
- Option to update rule
- Option to create folder
- File not moved

---

## Regression Tests

### Test REG-1: Core Features Still Work
After implementing all features, verify:
- Basic file scanning still works
- Manual file organization works
- Rule creation/editing works
- Settings save correctly

### Test REG-2: Existing Rules Unaffected
Verify that:
- Pre-existing rules still evaluate correctly
- Old rule syntax still supported
- Rule priorities respected
- No rule corruption

---

## Success Criteria

**All features pass testing when**:
- ✅ All test scenarios execute successfully
- ✅ No critical bugs found
- ✅ Performance within acceptable limits
- ✅ Accessibility requirements met
- ✅ Error handling graceful
- ✅ No regressions in core features

**Testing Complete**: 19 of 23 implementation tasks done (83%)
**Remaining**: 4 manual testing tasks

---

## Testing Checklist

- [ ] Feature #1: Match Reasoning (5 tests)
- [ ] Feature #2: Folder Templates (2 tests)
- [ ] Feature #3: Learning System (5 tests)
- [ ] Feature #4: Personality Quiz (See dedicated guide)
- [ ] Feature #5: Enhanced Review (5 tests)
- [ ] Feature #6: Context Detection (7 tests)
- [ ] Integration Tests (3 tests)
- [ ] Performance Tests (2 tests)
- [ ] Accessibility Tests (3 tests)
- [ ] Error Handling Tests (3 tests)
- [ ] Regression Tests (2 tests)

**Total: 37+ test scenarios across 6 features**
