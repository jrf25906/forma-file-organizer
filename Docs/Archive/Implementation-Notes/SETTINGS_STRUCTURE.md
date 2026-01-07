# Settings Module Structure

**Status:** Archived (historical)  
**Archived:** 2026-01  
**Superseded By:** `Forma File Organizing/Views/Settings/SettingsView.swift`

## Structure Snapshot

```
Forma File Organizing/Views/Settings/
├── SettingsView.swift
│   └── Main coordinator with TabView
│       ├── RulesManagerSection
│       ├── CustomFoldersSection
│       ├── SmartFeaturesSection
│       ├── GeneralSettingsSection
│       └── AboutSection
│
├── SettingsComponents.swift
│   ├── SettingsSection<Content: View>
│   ├── SettingsRow<Accessory: View>
│   └── AppearanceMode enum (.system, .light, .dark)
│
├── GeneralSettingsSection.swift
│   ├── Appearance (theme picker)
│   ├── Startup (launch at login, auto-scan)
│   ├── Notifications (toggle)
│   ├── Scanning (interval picker)
│   └── Reset all settings
│
├── RulesManagerSection.swift
│   ├── Add Rule header
│   ├── Empty state
│   └── RuleManagementCard list
│
├── CustomFoldersSection.swift
│   ├── Add Folders header
│   ├── Empty state
│   ├── FolderRow list (edit/delete/enable)
│   └── Error handling
│
├── SmartFeaturesSection.swift
│   ├── Master AI toggle
│   ├── Feature toggles (learning, suggestions, context)
│   ├── Analytics & insights toggles
│   ├── Automation settings + behavior
│   └── Reset to defaults
│
└── AboutSection.swift
    ├── Forma logo
    ├── App name
    └── Version number
```

## Component Architecture

```
SettingsView
  ├── RulesManagerSection
  │     ├── Uses: Rule (SwiftData model)
  │     ├── Uses: RuleService
  │     └── Opens: RuleEditorView (sheet)
  │
  ├── CustomFoldersSection
  │     ├── Uses: CustomFolder (SwiftData model)
  │     ├── Uses: CustomFolderManager
  │     └── Component: FolderRow
  │
  ├── SmartFeaturesSection
  │     ├── Component: SmartFeatureRow
  │     ├── Component: AutomationModeRow
  │     ├── Component: AutomationModeOption
  │     └── Uses: FeatureFlagService.Feature enum
  │
  ├── GeneralSettingsSection
  │     ├── Uses: SMAppService (launch at login)
  │     └── Uses: AppearanceMode enum
  │
  └── AboutSection
        └── Uses: FormaLogo component
```

## Data Flow

```
User Interaction
      ↓
Settings View Tab Selection
      ↓
Section View Renders
      ↓
Uses SettingsSection/SettingsRow components
      ↓
User modifies setting
      ↓
@AppStorage or SwiftData updates
      ↓
UI updates reactively
```
