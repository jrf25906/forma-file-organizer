import XCTest
@testable import Forma_File_Organizing

/// Tests for FolderTemplateSelection model used in per-folder template onboarding
final class FolderTemplateSelectionTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitializationHasNilTemplates() {
        let selection = FolderTemplateSelection()

        XCTAssertNil(selection.desktop, "Desktop should be nil by default")
        XCTAssertNil(selection.downloads, "Downloads should be nil by default")
        XCTAssertNil(selection.documents, "Documents should be nil by default")
        XCTAssertNil(selection.pictures, "Pictures should be nil by default")
        XCTAssertNil(selection.music, "Music should be nil by default")
    }

    // MARK: - Template Retrieval Tests

    func testTemplateReturnsExplicitSelectionWhenSet() {
        var selection = FolderTemplateSelection()
        selection.desktop = .para
        selection.downloads = .minimal
        selection.documents = .johnnyDecimal
        selection.pictures = .chronological
        selection.music = .creativeProf

        // Should return explicit selections, ignoring personality
        // Using creative personality (piler/visual) which suggests minimal template
        let creativePersonality = OrganizationPersonality.creative

        XCTAssertEqual(
            selection.template(for: .desktop, personality: creativePersonality),
            .para,
            "Should return explicit desktop selection"
        )
        XCTAssertEqual(
            selection.template(for: .downloads, personality: creativePersonality),
            .minimal,
            "Should return explicit downloads selection"
        )
        XCTAssertEqual(
            selection.template(for: .documents, personality: creativePersonality),
            .johnnyDecimal,
            "Should return explicit documents selection"
        )
        XCTAssertEqual(
            selection.template(for: .pictures, personality: creativePersonality),
            .chronological,
            "Should return explicit pictures selection"
        )
        XCTAssertEqual(
            selection.template(for: .music, personality: creativePersonality),
            .creativeProf,
            "Should return explicit music selection"
        )
    }

    func testTemplateReturnsPersonalitySuggestedWhenNotExplicitlySet() {
        let selection = FolderTemplateSelection()

        // Each personality suggests a different template based on its dimensions
        // creative: piler + visual + projectBased → minimal
        XCTAssertEqual(
            selection.template(for: .desktop, personality: .creative),
            OrganizationPersonality.creative.suggestedTemplate,
            "Should return creative's suggested template"
        )
        // academic: filer + hierarchical + topicBased → johnnyDecimal
        XCTAssertEqual(
            selection.template(for: .desktop, personality: .academic),
            OrganizationPersonality.academic.suggestedTemplate,
            "Should return academic's suggested template"
        )
        // business: filer + hierarchical + projectBased → creativeProf
        XCTAssertEqual(
            selection.template(for: .desktop, personality: .business),
            OrganizationPersonality.business.suggestedTemplate,
            "Should return business's suggested template"
        )
        // default: filer + visual + projectBased → creativeProf
        XCTAssertEqual(
            selection.template(for: .desktop, personality: .default),
            OrganizationPersonality.default.suggestedTemplate,
            "Should return default's suggested template"
        )
    }

    func testTemplateReturnsMinimalWhenNoPersonalityOrExplicitSelection() {
        let selection = FolderTemplateSelection()

        XCTAssertEqual(
            selection.template(for: .desktop, personality: nil),
            .minimal,
            "Should default to minimal when no personality or explicit selection"
        )
        XCTAssertEqual(
            selection.template(for: .downloads, personality: nil),
            .minimal,
            "Should default to minimal for all folders"
        )
    }

    // MARK: - SetTemplate Tests

    func testSetTemplateUpdatesCorrectFolder() {
        var selection = FolderTemplateSelection()

        selection.setTemplate(.para, for: .desktop)
        XCTAssertEqual(selection.desktop, .para)
        XCTAssertNil(selection.downloads, "Other folders should remain nil")

        selection.setTemplate(.chronological, for: .pictures)
        XCTAssertEqual(selection.pictures, .chronological)
        XCTAssertEqual(selection.desktop, .para, "Desktop should be unchanged")
    }

    func testSetTemplateCanOverwriteExistingValue() {
        var selection = FolderTemplateSelection()

        selection.setTemplate(.para, for: .desktop)
        XCTAssertEqual(selection.desktop, .para)

        selection.setTemplate(.minimal, for: .desktop)
        XCTAssertEqual(selection.desktop, .minimal, "Should overwrite existing selection")
    }

    func testSetTemplateForAllFolders() {
        var selection = FolderTemplateSelection()

        for folder in OnboardingFolder.allCases {
            selection.setTemplate(.academic, for: folder)
        }

        XCTAssertEqual(selection.desktop, .academic)
        XCTAssertEqual(selection.downloads, .academic)
        XCTAssertEqual(selection.documents, .academic)
        XCTAssertEqual(selection.pictures, .academic)
        XCTAssertEqual(selection.music, .academic)
    }

    // MARK: - ApplyDefaults Tests

    func testApplyDefaultsSetsTemplateForSelectedFolders() {
        var selection = FolderTemplateSelection()
        let folderSelection = OnboardingFolderSelection(
            desktop: true,
            downloads: true,
            documents: false,
            pictures: false,
            music: false
        )

        // Using creative personality (piler + visual + projectBased → minimal template)
        selection.applyDefaults(personality: .creative, selectedFolders: folderSelection)

        // Selected folders should get the default template
        XCTAssertEqual(selection.desktop, OrganizationPersonality.creative.suggestedTemplate)
        XCTAssertEqual(selection.downloads, OrganizationPersonality.creative.suggestedTemplate)

        // Unselected folders should remain nil
        XCTAssertNil(selection.documents)
        XCTAssertNil(selection.pictures)
        XCTAssertNil(selection.music)
    }

    func testApplyDefaultsDoesNotOverwriteExistingSelections() {
        var selection = FolderTemplateSelection()
        selection.desktop = .johnnyDecimal

        let folderSelection = OnboardingFolderSelection(
            desktop: true,
            downloads: true,
            documents: true,
            pictures: true,
            music: true
        )

        // Using creative personality (piler + visual + projectBased → minimal template)
        selection.applyDefaults(personality: .creative, selectedFolders: folderSelection)

        // Explicit selection should be preserved
        XCTAssertEqual(selection.desktop, .johnnyDecimal, "Should not overwrite explicit selection")

        // Others should get the default
        XCTAssertEqual(selection.downloads, OrganizationPersonality.creative.suggestedTemplate)
    }

    func testApplyDefaultsWithNilPersonalityUsesMinimal() {
        var selection = FolderTemplateSelection()
        let folderSelection = OnboardingFolderSelection(
            desktop: true,
            downloads: false,
            documents: false,
            pictures: false,
            music: false
        )

        selection.applyDefaults(personality: nil, selectedFolders: folderSelection)

        XCTAssertEqual(selection.desktop, .minimal, "Should use minimal when personality is nil")
    }

    // MARK: - Persistence Tests

    func testSaveAndLoad() {
        // Clear any existing data
        UserDefaults.standard.removeObject(forKey: FolderTemplateSelection.storageKey)

        var selection = FolderTemplateSelection()
        selection.desktop = .para
        selection.downloads = .minimal
        selection.documents = .johnnyDecimal
        selection.pictures = .chronological
        selection.music = .creativeProf

        selection.save()

        let loaded = FolderTemplateSelection.load()

        XCTAssertEqual(loaded.desktop, .para)
        XCTAssertEqual(loaded.downloads, .minimal)
        XCTAssertEqual(loaded.documents, .johnnyDecimal)
        XCTAssertEqual(loaded.pictures, .chronological)
        XCTAssertEqual(loaded.music, .creativeProf)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: FolderTemplateSelection.storageKey)
    }

    func testLoadReturnsEmptySelectionWhenNoSavedData() {
        // Clear any existing data
        UserDefaults.standard.removeObject(forKey: FolderTemplateSelection.storageKey)

        let loaded = FolderTemplateSelection.load()

        XCTAssertNil(loaded.desktop)
        XCTAssertNil(loaded.downloads)
        XCTAssertNil(loaded.documents)
        XCTAssertNil(loaded.pictures)
        XCTAssertNil(loaded.music)
    }

    func testLoadHandlesCorruptedData() {
        // Save corrupted data
        UserDefaults.standard.set(Data([0x00, 0x01, 0x02]), forKey: FolderTemplateSelection.storageKey)

        let loaded = FolderTemplateSelection.load()

        // Should return empty selection when data is corrupted
        XCTAssertNil(loaded.desktop)
        XCTAssertNil(loaded.downloads)

        // Cleanup
        UserDefaults.standard.removeObject(forKey: FolderTemplateSelection.storageKey)
    }

    // MARK: - Codable Tests

    func testCodableRoundTrip() {
        var selection = FolderTemplateSelection()
        selection.desktop = .para
        selection.downloads = .minimal
        selection.pictures = .chronological

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let data = try encoder.encode(selection)
            let decoded = try decoder.decode(FolderTemplateSelection.self, from: data)

            XCTAssertEqual(decoded.desktop, .para)
            XCTAssertEqual(decoded.downloads, .minimal)
            XCTAssertNil(decoded.documents, "Nil values should remain nil after round trip")
            XCTAssertEqual(decoded.pictures, .chronological)
            XCTAssertNil(decoded.music)
        } catch {
            XCTFail("Codable round trip failed: \(error)")
        }
    }

    func testCodableWithAllNilValues() {
        let selection = FolderTemplateSelection()

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        do {
            let data = try encoder.encode(selection)
            let decoded = try decoder.decode(FolderTemplateSelection.self, from: data)

            XCTAssertNil(decoded.desktop)
            XCTAssertNil(decoded.downloads)
            XCTAssertNil(decoded.documents)
            XCTAssertNil(decoded.pictures)
            XCTAssertNil(decoded.music)
        } catch {
            XCTFail("Codable with nil values failed: \(error)")
        }
    }

    // MARK: - Equatable Tests

    func testEquatableWithIdenticalSelections() {
        var selection1 = FolderTemplateSelection()
        selection1.desktop = .para
        selection1.downloads = .minimal

        var selection2 = FolderTemplateSelection()
        selection2.desktop = .para
        selection2.downloads = .minimal

        XCTAssertEqual(selection1, selection2)
    }

    func testEquatableWithDifferentSelections() {
        var selection1 = FolderTemplateSelection()
        selection1.desktop = .para

        var selection2 = FolderTemplateSelection()
        selection2.desktop = .minimal

        XCTAssertNotEqual(selection1, selection2)
    }

    func testEquatableWithNilVsSetValue() {
        var selection1 = FolderTemplateSelection()
        selection1.desktop = nil

        var selection2 = FolderTemplateSelection()
        selection2.desktop = .minimal

        XCTAssertNotEqual(selection1, selection2)
    }

    func testEquatableEmptySelections() {
        let selection1 = FolderTemplateSelection()
        let selection2 = FolderTemplateSelection()

        XCTAssertEqual(selection1, selection2)
    }

    // MARK: - Integration Tests

    func testFullOnboardingScenario() {
        // Simulate a complete onboarding flow
        var selection = FolderTemplateSelection()

        // User selects folders
        let folderSelection = OnboardingFolderSelection(
            desktop: true,
            downloads: true,
            documents: false,
            pictures: true,
            music: false
        )

        // User completes personality quiz
        let personality: OrganizationPersonality = .creative

        // Apply defaults for all selected folders
        selection.applyDefaults(personality: personality, selectedFolders: folderSelection)

        // User customizes a specific folder
        selection.setTemplate(.chronological, for: .pictures)

        // Verify final state
        XCTAssertEqual(
            selection.template(for: .desktop, personality: personality),
            OrganizationPersonality.creative.suggestedTemplate,
            "Desktop should use personality default"
        )
        XCTAssertEqual(
            selection.template(for: .downloads, personality: personality),
            OrganizationPersonality.creative.suggestedTemplate,
            "Downloads should use personality default"
        )
        XCTAssertEqual(
            selection.template(for: .pictures, personality: personality),
            .chronological,
            "Pictures should use explicit selection"
        )

        // Unselected folder should still fall back to personality default
        XCTAssertEqual(
            selection.template(for: .documents, personality: personality),
            OrganizationPersonality.creative.suggestedTemplate,
            "Unselected folder should fall back to personality"
        )
    }

    func testMixedExplicitAndDefaultTemplates() {
        var selection = FolderTemplateSelection()

        // Set explicit templates for some folders
        selection.desktop = .minimal
        selection.pictures = .chronological
        // Leave others as nil

        // Using academic personality (filer + hierarchical + topicBased → johnnyDecimal)
        let personality: OrganizationPersonality = .academic

        // Explicit selections should be returned
        XCTAssertEqual(selection.template(for: .desktop, personality: personality), .minimal)
        XCTAssertEqual(selection.template(for: .pictures, personality: personality), .chronological)

        // Non-explicit should fall back to personality
        XCTAssertEqual(
            selection.template(for: .downloads, personality: personality),
            personality.suggestedTemplate
        )
        XCTAssertEqual(
            selection.template(for: .documents, personality: personality),
            personality.suggestedTemplate
        )
        XCTAssertEqual(
            selection.template(for: .music, personality: personality),
            personality.suggestedTemplate
        )
    }
}
