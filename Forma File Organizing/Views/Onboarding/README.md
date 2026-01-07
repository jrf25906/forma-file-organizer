# Onboarding Modular Architecture

This folder contains the refactored onboarding flow, split from a single 1,385-line file into modular, focused components.

## File Structure

### Core Components (236 lines total)

**OnboardingFlowView.swift** - Main coordinator (236 lines)
- Orchestrates the 5-step onboarding flow
- Manages step transitions and navigation
- Handles permissions and final setup
- Creates CustomFolder entries from selections
- Applies per-folder template rules

**OnboardingState.swift** - Shared state (182 lines)
- `@Observable` state management for entire flow
- `OnboardingFolderSelection` model
- `OnboardingFolder` enum with metadata
- `OnboardingStep` enum for navigation

### Step Views

**WelcomeStepView.swift** - Welcome screen (309 lines)
- Hero section with animated geometric illustration
- Three value proposition cards
- Floating background shapes
- CTA button with hover effects

**FolderSelectionStepView.swift** - Folder picker (264 lines)
- Visual folder grid (3x3 layout)
- Animated folder cards with rising icons
- Selection counter and privacy note
- Folder base shape components

**PersonalityQuizStepView.swift** - Quiz wrapper (30 lines)
- Thin wrapper around PersonalityQuizView
- Passes completion and back callbacks

**TemplateSelectionStepView.swift** - Template picker (143 lines)
- Per-folder template assignment cards
- Global template application button
- Folder template card with dropdown
- Preview expandable sections

**OnboardingPreviewStepView.swift** - Final preview (143 lines)
- Complete folder structure visualization
- Staggered entrance animations
- Folder structure preview cards
- Lazy folder creation explanation

### Shared Components

**OnboardingComponents.swift** - Reusable UI (312 lines)
- `OnboardingProgressBar` - Step indicator
- `ProgressStep` - Individual step marker
- `OnboardingFooter` - Consistent footer buttons
- `OnboardingGeometricIcon` - Brand illustrations (welcome, folders, style, system)

## Total Line Count

- **Old file**: 1,385 lines (monolithic)
- **New files**: 1,619 lines total (8 files)
- **Average per file**: ~202 lines
- **Largest file**: OnboardingComponents.swift (312 lines)
- **Smallest file**: PersonalityQuizStepView.swift (30 lines)

## Architecture Benefits

1. **Separation of Concerns**: Each step is self-contained with clear responsibilities
2. **Easier Testing**: Individual steps can be tested in isolation
3. **Better Previews**: Each file has focused SwiftUI previews
4. **Improved Navigation**: State management centralized in ObservableObject
5. **Reusable Components**: Shared UI elements extracted to common file
6. **Maintainability**: Easier to locate and modify specific features

## Integration

The new modular structure is a drop-in replacement for the old OnboardingFlowView. The public API remains identical:

```swift
OnboardingFlowView()
    .environmentObject(DashboardViewModel())
```

## Dependencies

External files referenced:
- `PersonalityQuizView.swift` - Personality assessment UI
- `PerFolderTemplateComponents.swift` - FolderTemplateSelection model and UI components
- Design system (FormaSpacing, FormaRadius, FormaColors, etc.)
- Dashboard and logging services

## Migration Notes

The original file has been backed up to:
- `Forma File Organizing/Views/OnboardingFlowView.swift.backup`

To complete migration:
1. Add new files to Xcode project
2. Remove old OnboardingFlowView.swift from project
3. Build and verify all previews work
4. Run tests to ensure functionality preserved
