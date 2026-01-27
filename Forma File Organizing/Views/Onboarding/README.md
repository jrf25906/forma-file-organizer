# Onboarding Modular Architecture

This folder contains the onboarding flow, split from a single monolithic file into modular, focused components. The flow was redesigned from 5 steps to 4 steps by removing the standalone template selection step and merging customization into the preview.

## Onboarding Flow (4 Steps)

1. **Welcome** - Scattered macOS file icons converge into a folder animation; Libre Baskerville serif hero text
2. **Folders** - Vertical pre-checked list with all 5 folders selected by default (opt-out model)
3. **Quiz** - Personality assessment that determines template recommendations
4. **Preview + Customize** - Folder structure visualization with collapsible "Customize templates" disclosure section

Templates are auto-applied from quiz results -- there is no standalone template selection step. Visual energy follows a "bookend" pattern: high at Welcome and Preview, calm in the middle steps.

### Typography

- **Headlines**: Libre Baskerville (serif) for onboarding headlines
- **Body text**: SF Pro for all body and UI text

## File Structure

### Core Components

**OnboardingFlowView.swift** - Main coordinator
- Orchestrates the 4-step onboarding flow
- Manages step transitions and navigation
- Handles permissions and final setup
- Saves bookmarks to Keychain via BookmarkFolderService
- Applies per-folder template rules from quiz results

**OnboardingState.swift** - Shared state
- `@Observable` state management for entire flow
- `OnboardingFolderSelection` model
- `OnboardingFolder` enum with metadata
- `OnboardingStep` enum for navigation

### Step Views

**WelcomeStepView.swift** - Welcome screen
- Files-into-folder convergence animation
- Libre Baskerville hero text
- CTA button with hover effects

**FolderSelectionStepView.swift** - Folder picker
- Vertical pre-checked list layout
- All 5 folders default to selected (opt-out)
- Selection counter and privacy note

**PersonalityQuizStepView.swift** - Quiz wrapper
- Thin wrapper around PersonalityQuizView
- Passes completion and back callbacks

**OnboardingPreviewStepView.swift** - Preview + Customize
- Complete folder structure visualization
- Collapsible "Customize templates" disclosure section
- Templates auto-applied from quiz personality result
- Staggered entrance animations
- Lazy folder creation explanation

### Shared Components

**OnboardingComponents.swift** - Reusable UI
- `OnboardingProgressBar` - Step indicator
- `ProgressStep` - Individual step marker
- `OnboardingFooter` - Consistent footer buttons
- `OnboardingGeometricIcon` - Brand illustrations

## Architecture Benefits

1. **Separation of Concerns**: Each step is self-contained with clear responsibilities
2. **Easier Testing**: Individual steps can be tested in isolation
3. **Better Previews**: Each file has focused SwiftUI previews
4. **Improved Navigation**: State management centralized in ObservableObject
5. **Reusable Components**: Shared UI elements extracted to common file
6. **Maintainability**: Easier to locate and modify specific features

## Integration

The modular structure is a drop-in replacement. The public API is:

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

## Design Decisions

- **Pre-checked folders (opt-out)**: All 5 folders are selected by default. Users deselect what they don't want rather than opting in. This reduces friction and increases the number of folders managed.
- **No standalone template step**: Quiz results automatically determine templates. The old step 4 (Per-Folder Templates) was removed; customization is available via a collapsible disclosure in the Preview step for users who want to override.
- **Bookend energy pattern**: Welcome and Preview are visually energetic (animations, rich layout). Folders and Quiz are calmer to reduce cognitive load during decision-making.
