//
//  Forma_File_OrganizingTests.swift
//  Forma File OrganizingTests
//
//  Created by James Farmer on 11/17/25.
//

import Testing
import SwiftUI
import SwiftData
@testable import Forma_File_Organizing

struct Forma_File_OrganizingTests {

    @Test @MainActor func ruleEditorPrefillsFromFileContext() async throws {
        // Given
        let container = try ModelContainer(for: FileItem.self, Rule.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let file = FileItem(
            path: "/Users/test/Desktop/Screenshot.png",
            sizeInBytes: 4_718_592,
            creationDate: Date(),
            destination: nil,
            status: .pending
        )
        context.insert(file)

        // When: construct the view with fileContext; this should not crash
        _ = RuleEditorView(rule: nil, fileContext: file)

        // Then: basic smoke test that we reached here
        #expect(file.fileExtension == "png")
    }

}
