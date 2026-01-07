# Onboarding Architecture Overview

## Component Hierarchy

```
OnboardingFlowView (Coordinator)
│
├── OnboardingState (@Observable)
│   ├── currentStep: OnboardingStep
│   ├── folderSelection: OnboardingFolderSelection
│   ├── personality: OrganizationPersonality?
│   ├── templateSelection: FolderTemplateSelection
│   └── isRequestingPermissions: Bool
│
└── Step Views (Switched by currentStep)
    │
    ├── Step 1: WelcomeStepView
    │   ├── Hero Animation
    │   ├── ValuePropCard × 3
    │   └── WelcomeCTAButton
    │
    ├── Step 2: FolderSelectionStepView
    │   ├── OnboardingGeometricIcon (folders)
    │   ├── AnimatedFolderCard × 5
    │   │   └── FolderBaseShape
    │   └── OnboardingFooter
    │
    ├── Step 3: PersonalityQuizStepView
    │   └── PersonalityQuizView (external)
    │
    ├── Step 4: TemplateSelectionStepView
    │   ├── OnboardingGeometricIcon (system)
    │   ├── FolderTemplateCard × N
    │   │   ├── TemplateDropdown
    │   │   └── FolderStructurePreview
    │   └── OnboardingFooter
    │
    └── Step 5: OnboardingPreviewStepView
        ├── FolderStructurePreview × N
        └── OnboardingFooter

Shared Components (OnboardingComponents.swift)
├── OnboardingProgressBar
│   └── ProgressStep × 4
├── OnboardingFooter
└── OnboardingGeometricIcon
    ├── welcomeGeometry
    ├── foldersGeometry
    ├── styleGeometry
    └── systemGeometry
```

## Data Flow

```
User Action → Step View → OnboardingState → Coordinator → Next Step

Example: Folder Selection Flow
1. User taps folder card
2. AnimatedFolderCard updates binding
3. OnboardingState.folderSelection updates
4. User taps Continue
5. OnboardingFlowView.advanceToQuiz()
6. Requests permissions (async)
7. OnboardingState.currentStep = .quiz
8. View switches to PersonalityQuizStepView
```

## State Management Pattern

### Centralized State (`@Observable`)
```swift
@State private var state = OnboardingState()

// State flows down through bindings
FolderSelectionStepView(
    selection: $state.folderSelection,
    isRequestingPermissions: state.isRequestingPermissions,
    onContinue: advanceToQuiz,
    onBack: { state.advance(to: .welcome) }
)
```

### Benefits
- Single source of truth
- Clear data ownership
- Predictable state updates
- Easy to debug with breakpoints

## Navigation Pattern

### Step Enum
```swift
enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case folders = 1
    case quiz = 2
    case folderTemplates = 3
    case preview = 4
}
```

### Forward Navigation
```swift
private func advanceToQuiz() {
    state.folderSelection.save()
    state.isRequestingPermissions = true
    Task {
        await requestPermissionsForSelectedFolders()
        await MainActor.run {
            state.isRequestingPermissions = false
            state.advance(to: .quiz)
        }
    }
}
```

### Backward Navigation
```swift
onBack: { state.advance(to: .folders) }
```

## Component Reuse Strategy

### Shared UI Components
All steps (except Welcome) use:
- `OnboardingProgressBar` - Shows step progress
- `OnboardingFooter` - Provides Continue/Back buttons

### Geometric Icons
`OnboardingGeometricIcon` provides 4 style variants:
- `.welcome` - Logo-inspired geometric shapes
- `.folders` - Stacked folder illustration
- `.style` - Colorful personality grid
- `.system` - Grid/system representation

### Why Shared Components?
1. Consistency across steps
2. Single location for design updates
3. Reduced code duplication
4. Easier to maintain animations

## File Size Targets

| File Type | Target Lines | Actual Range |
|-----------|--------------|--------------|
| Step View | 150-300 | 30-309 |
| Shared Components | 200-400 | 312 |
| State Management | 150-250 | 182 |
| Main Coordinator | 200-300 | 236 |

## Testing Strategy

### Unit Tests
- OnboardingState navigation logic
- OnboardingFolderSelection encoding/decoding
- Step advance/back behavior

### Component Tests
- Individual step view rendering
- Button interactions
- Animation triggers

### Integration Tests
- Complete flow from welcome → preview
- Permission request handling
- Template selection persistence

### Preview Tests
Each file includes SwiftUI previews:
```swift
#Preview("Folder Selection") {
    FolderSelectionStepView(
        selection: .constant(OnboardingFolderSelection()),
        isRequestingPermissions: false,
        onContinue: {},
        onBack: {}
    )
    .frame(width: 650, height: 720)
    .background(Color.formaBackground)
}
```

## Design Patterns Used

1. **Coordinator Pattern**: OnboardingFlowView orchestrates steps
2. **Observer Pattern**: @Observable for state management
3. **Strategy Pattern**: Different geometric icon styles
4. **Template Method**: OnboardingFooter with customizable actions
5. **Dependency Injection**: Environment objects and bindings

## Performance Considerations

### Animations
- Use `.spring()` for natural movement
- Stagger entrance with `.delay()`
- Reduce motion when `accessibilityReduceMotion` is enabled

### State Updates
- Batch related state changes
- Use `withAnimation` for UI transitions
- Async operations on background thread

### Memory
- Each step view is created/destroyed on navigation
- State persisted in UserDefaults
- No retain cycles (all closures capture weakly)

## Migration Benefits Summary

| Aspect | Before | After |
|--------|--------|-------|
| File Size | 1,385 lines | 8 files, avg 202 lines |
| Testability | Monolithic, hard to test | Isolated, easy to test |
| Readability | Scrolling nightmare | Focused, scannable |
| Collaboration | Merge conflicts | Parallel development |
| Debugging | Hard to isolate | Clear boundaries |
| Previews | One mega preview | 8 focused previews |

