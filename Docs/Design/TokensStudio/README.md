# Forma Tokens Studio Seed

This folder contains a first-pass Tokens Studio package for importing Forma's current design system into Tokens Studio and then syncing it into Supernova.

Files:

- `forma-primitives.json`: brand colors, spacing, radius, sizing, font primitives, motion durations
- `forma-typography.json`: named text styles built from the primitive font tokens
- `forma-theme-light.json`: semantic light theme tokens
- `forma-theme-dark.json`: semantic dark theme tokens

Recommended import flow:

1. Create a new Tokens Studio project.
2. Import each JSON file as a separate token set.
3. Mark `forma-primitives` and `forma-typography` as source/base sets.
4. Create two themes:
   - `Forma / Light`: enable `forma-primitives`, `forma-typography`, `forma-theme-light`
   - `Forma / Dark`: enable `forma-primitives`, `forma-typography`, `forma-theme-dark`
5. Connect Tokens Studio to Supernova and sync the sets/themes into the design system.

Important notes:

- The SwiftUI/AppKit design system uses platform semantic colors like `NSColor.labelColor` and `NSColor.windowBackgroundColor`. Those do not translate cleanly into portable design-tool tokens, so this seed normalizes them into explicit brand-aligned light/dark theme values.
- The Swift source defines typography with size and weight but not explicit line heights. The typography set adds normalized line heights on a 4/8pt rhythm so text styles are importable into design tooling.
- Gradients, materials, spring curves, and some platform-only visual effects are intentionally omitted from this first pass. They should be documented in Supernova and authored visually in Figma rather than treated as raw token data.

Source files used:

- `Forma File Organizing/DesignSystem/FormaColors.swift`
- `Forma File Organizing/DesignSystem/FormaSpacing.swift`
- `Forma File Organizing/DesignSystem/FormaTypography.swift`
- `Forma File Organizing/DesignSystem/FormaLayout.swift`
- `Forma File Organizing/DesignSystem/FormaAnimation.swift`
- `Docs/Design/DesignSystem.md`
- `Docs/Design/Forma-Brand-Guidelines.md`
