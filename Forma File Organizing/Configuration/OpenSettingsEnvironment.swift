//
//  OpenSettingsEnvironment.swift
//  Forma File Organizing
//
//  Created by Assistant on 11/20/25.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Environment key for opening the Settings window programmatically
struct OpenSettingsKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {
        SettingsOpener.open()
    }
}

/// Extension to EnvironmentValues to expose the openSettings action
extension EnvironmentValues {
    var openSettings: @MainActor @Sendable () -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
}

/// Cross-platform Settings opener utility
/// On macOS, this opens the Settings scene defined in the App
/// On other platforms, this is a no-op (can be extended for in-app settings)
enum SettingsOpener {
    /// Opens the SwiftUI Settings scene.
    ///
    /// macOS behavior:
    /// - Uses the standard settings menu command (Cmd+,)
    /// - Activates the app so the Settings window appears in front
    /// - Robust approach that works with SwiftUI Settings scene
    ///
    /// Usage:
    /// Inject at the app level:
    ///   `.environment(\.openSettings, SettingsOpener.open)`
    /// Then call from any view:
    ///   `@Environment(\.openSettings) var openSettings` and `openSettings()`
    @MainActor
    static func open() {
        #if os(macOS)
        #if DEBUG
        Log.debug("SettingsOpener.open() called on \(Thread.isMainThread ? "MAIN" : "BACKGROUND") thread", category: .ui)
        #endif

        // Bring Forma to foreground first so Settings is always visible to the user.
        NSApp.activate(ignoringOtherApps: true)

        let showSettingsSelector = Selector(("showSettingsWindow:"))
        let showPreferencesSelector = Selector(("showPreferencesWindow:"))
        let didShowSettings = NSApp.sendAction(showSettingsSelector, to: nil, from: nil)
        let didShowPreferences = didShowSettings
            ? false
            : NSApp.sendAction(showPreferencesSelector, to: nil, from: nil)

        #if DEBUG
        if didShowSettings {
            Log.debug("Settings opened via showSettingsWindow:", category: .ui)
        } else if didShowPreferences {
            Log.debug("Settings opened via showPreferencesWindow: fallback", category: .ui)
        } else {
            Log.warning("No responder handled settings open action", category: .ui)
        }
        #endif
        #else
        // iOS/iPadOS/tvOS: no-op or navigate to an in-app settings view
        Log.info("Settings not available on this platform", category: .ui)
        #endif
    }
}
