# Forma - File Organizing App

A premium macOS application for intelligent file organization.

## Links

| Resource | URL |
|----------|-----|
| **Marketing Site** | [formafiles.com](https://formafiles.com) |
| **GitHub Repo** | [github.com/jrf25906/forma-file-organizer](https://github.com/jrf25906/forma-file-organizer) (private) |

## Overview

Forma helps you organize files from Desktop, Downloads, and other folders using intelligent rule-based automation. Built with SwiftUI and SwiftData for macOS 14+.

**Design Philosophy:** Precise, Refined, Confident—crafted to Apple Design Award standards.

## Key Features

- **Dashboard**: Three-panel layout (sidebar, main content/analytics, right panel for actions)
- **Organization Templates**: Pre-built organization strategies (Minimalist, Creative Professional, Student, etc.)
- **Personality-Based Organization**: Adaptive system that learns your organizational style through an onboarding quiz
- **Smart Rules**: Automatic file organization based on extension, name patterns, context, and learned patterns
- **Project Clustering**: Intelligent detection and grouping of related files into projects
- **Multiple View Modes**: Card, list, and grid views with keyboard navigation
- **File Categories**: Documents, Images, Videos, Audio, Archives—each with distinct colors and icons
- **Activity Feed**: Real-time tracking of file operations with undo support
- **Context Detection**: AI-powered analysis of file content and relationships
- **Insights & Analytics**: Storage analytics, organization patterns, and productivity insights
- **Sandboxed Security**: Uses security-scoped bookmarks for safe, persistent folder access

## Quick Start

```bash
# Build
xcodebuild -project "Forma File Organizing.xcodeproj" -scheme "Forma File Organizing" -configuration Debug build

# Run
open "Forma File Organizing.xcodeproj"  # Then press Cmd+R
```

## Design System

| Token | Value |
|-------|-------|
| **Colors** | Obsidian, Bone White, Steel Blue, Sage, Clay, Terracotta, Amber |
| **Typography** | `.formaH1`, `.formaH2`, `.formaBody`, `.formaSmall` |
| **Spacing** | `.micro(4)`, `.tight(8)`, `.standard(12)`, `.generous(24)`, `.xl(32)` |

## Documentation

| Doc | Purpose |
|-----|--------|
| [Docs/INDEX.md](Docs/INDEX.md) | Master documentation map |
| [Docs/README.md](Docs/README.md) | Documentation hub |
| [Docs/Getting-Started/README.md](Docs/Getting-Started/README.md) | Setup, user guide, changelog, roadmap |
| [Docs/Architecture/README.md](Docs/Architecture/README.md) | System architecture |
| [Docs/Design/README.md](Docs/Design/README.md) | Design system and UX |
| [Docs/Development/README.md](Docs/Development/README.md) | Development workflow |
| [Docs/Testing/README.md](Docs/Testing/README.md) | Testing guides and reports |
| [Docs/Security/README.md](Docs/Security/README.md) | Security docs |
| [API_REFERENCE.md](API_REFERENCE.md) | API reference pointer |
| [CHANGELOG.md](CHANGELOG.md) | Release notes |
| [TODO.md](TODO.md) | Roadmap and project status |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |
| [AGENTS.md](AGENTS.md) | Agent and automation guidance |
| [WARP.md](WARP.md) | AI assistant guidance |

**Note:** `API_REFERENCE.md` links to the canonical API docs.

## Project Structure

```
Forma File Organizing/
├── Models/                      # SwiftData models + protocols
│   ├── FileItem.swift           # File representation with metadata
│   ├── Rule.swift               # Organization rules
│   ├── OrganizationTemplate.swift    # Template system
│   ├── OrganizationPersonality.swift # Personality-based organization
│   ├── ProjectCluster.swift     # Project detection
│   ├── LearnedPattern.swift     # ML-based patterns
│   ├── ActivityItem.swift       # Activity tracking
│   ├── CustomFolder.swift       # Multi-folder support
│   └── ...                      # Error handling, protocols, types
├── ViewModels/                  # State management (@MainActor classes)
│   ├── DashboardViewModel.swift # Coordinator composing child VMs
│   ├── FileScanViewModel.swift  # File discovery and scanning
│   ├── FilterViewModel.swift    # Filtering, search, view modes
│   ├── SelectionViewModel.swift # Multi-select, keyboard navigation
│   ├── AnalyticsDashboardViewModel.swift # Storage analytics
│   ├── BulkOperationViewModel.swift      # Batch operations
│   ├── ReviewViewModel.swift    # File review state
│   └── NavigationViewModel.swift # App navigation
├── Views/                       # UI screens
│   ├── DashboardView.swift      # Main three-panel interface
│   ├── SidebarView.swift        # Left navigation panel
│   ├── MainContentView.swift    # Center content area
│   ├── RightPanelView.swift     # Context-aware right panel
│   ├── Onboarding/              # Modular onboarding flow
│   │   ├── OnboardingFlowView.swift    # Coordinator
│   │   ├── OnboardingState.swift       # Shared state
│   │   ├── WelcomeStepView.swift       # Step 1
│   │   ├── FolderSelectionStepView.swift # Step 2
│   │   ├── PersonalityQuizStepView.swift # Step 3
│   │   ├── TemplateSelectionStepView.swift # Step 4
│   │   └── OnboardingPreviewStepView.swift # Step 5
│   ├── Settings/                # Modular settings
│   │   ├── SettingsView.swift   # TabView coordinator
│   │   ├── GeneralSettingsSection.swift
│   │   ├── RulesManagerSection.swift
│   │   ├── CustomFoldersSection.swift
│   │   ├── SmartFeaturesSection.swift
│   │   └── AboutSection.swift
│   ├── Components/              # View-specific shared components
│   │   ├── RuleFormState.swift  # Unified rule form state
│   │   └── CategoryComponents.swift # Category UI components
│   ├── RulesManagementView.swift # Rule configuration
│   └── ...                      # Project clusters, file inspector, etc.
├── Components/                  # Reusable UI components
│   ├── Shared/                  # Consolidated shared components
│   │   ├── FormaCheckbox.swift  # Unified checkbox variants
│   │   ├── FormaThumbnail.swift # Unified thumbnail modes
│   │   └── FormaActionButton.swift # Unified action button styles
│   ├── FloatingActionBar.swift  # Bulk operation bar
│   ├── FilterTabBar.swift       # File filtering tabs
│   ├── FileGridItem.swift       # Grid view cards
│   ├── FileListRow.swift        # List view rows
│   ├── ActivityFeed.swift       # Activity timeline
│   ├── StorageChart.swift       # Storage visualization
│   └── ...                      # Toasts, buttons, animations, etc.
├── Services/                    # Business logic layer
│   ├── FileSystemService.swift  # File scanning & access
│   ├── RuleEngine.swift         # Rule evaluation
│   ├── FileOperationsService.swift # File moves & operations
│   ├── ContextDetectionService.swift # AI context analysis
│   ├── LearningService.swift    # Pattern learning
│   ├── InsightsService.swift    # Analytics generation
│   ├── CustomFolderManager.swift # Multi-folder management
│   ├── SecureBookmarkStore.swift # Permission management
│   ├── UndoCommand.swift        # Undo/redo system
│   └── ...                      # Notifications, thumbnails, etc.
├── DesignSystem/                # Visual design system
│   ├── FormaColors.swift        # Color palette & tokens
│   ├── FormaTypography.swift    # Type scale & styles
│   ├── FormaSpacing.swift       # Spacing system
│   ├── FormaComponents.swift    # Reusable UI patterns
│   ├── FormaMicroanimations.swift # Delightful interactions
│   ├── LiquidGlassComponents.swift # Glass morphism effects
│   └── FormaAnimation.swift     # Animation utilities
├── Coordinators/                # Navigation coordination
├── Configuration/               # App configuration
├── Utilities/                   # Helper functions
├── Resources/                   # Static resources
├── KeyboardCommands.swift       # Keyboard shortcuts
├── OpenSettingsEnvironment.swift # Settings integration
├── Forma_File_Organizing.entitlements # Permissions
└── Assets.xcassets              # Images, icons, brand assets
```

## Tech Stack

- **Framework**: SwiftUI
- **Persistence**: SwiftData
- **Architecture**: MVVM with Service Layer
- **Minimum**: macOS 14.0+, Swift 5.9+

## Marketing Site

The marketing site at [formafiles.com](https://formafiles.com) is a Next.js app located in `forma-marketing-site/`.

| Stack | Details |
|-------|---------|
| **Framework** | Next.js 16 |
| **Hosting** | Vercel (auto-deploys from `main` branch) |
| **Domain** | formafiles.com (DNS via Cloudflare) |

To run locally:
```bash
cd forma-marketing-site
npm install
npm run dev
```

Changes pushed to `main` automatically deploy to production via Vercel's GitHub integration.

## License

Copyright © 2025. All rights reserved.
