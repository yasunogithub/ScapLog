//
//  AICommandTests.swift
//  ScapLogTests
//
//  Created by Claude on 2026/01/05.
//

import Testing
import Foundation
@testable import ScapLog

struct AICommandTests {

    // MARK: - Test Data

    private func createTestCommand(
        name: String = "Test Command",
        template: String = "echo {prompt} {image_path}",
        defaultPrompt: String = "Default prompt",
        isEnabled: Bool = true
    ) -> AICommand {
        AICommand(
            name: name,
            template: template,
            defaultPrompt: defaultPrompt,
            isEnabled: isEnabled
        )
    }

    // MARK: - isOCR Tests

    @Test func isOCR_withOCRTemplate_shouldReturnTrue() {
        let command = AICommand(
            name: "OCR Test",
            template: "__OCR__",
            defaultPrompt: "",
            isEnabled: true
        )
        #expect(command.isOCR == true)
    }

    @Test func isOCR_withRegularTemplate_shouldReturnFalse() {
        let command = createTestCommand(template: "gemini {prompt}")
        #expect(command.isOCR == false)
    }

    // MARK: - buildCommand Placeholder Tests

    @Test func buildCommand_shouldReplaceImagePath() {
        let command = createTestCommand(template: "process {image_path}")
        let result = command.buildCommand(imagePath: "/path/to/image.png")
        #expect(result == "process /path/to/image.png")
    }

    @Test func buildCommand_shouldReplaceImageDir() {
        let command = createTestCommand(template: "cd {image_dir}")
        let result = command.buildCommand(imagePath: "/path/to/image.png")
        #expect(result == "cd /path/to")
    }

    @Test func buildCommand_shouldReplaceImageName() {
        let command = createTestCommand(template: "open {image_name}")
        let result = command.buildCommand(imagePath: "/path/to/screenshot.png")
        #expect(result == "open screenshot.png")
    }

    @Test func buildCommand_shouldReplacePrompt() {
        let command = createTestCommand(template: "ai \"{prompt}\"")
        let result = command.buildCommand(imagePath: "/test.png", prompt: "Analyze this")
        #expect(result == "ai \"Analyze this\"")
    }

    @Test func buildCommand_shouldUseDefaultPromptWhenNil() {
        let command = createTestCommand(
            template: "ai \"{prompt}\"",
            defaultPrompt: "Default analysis"
        )
        let result = command.buildCommand(imagePath: "/test.png")
        #expect(result == "ai \"Default analysis\"")
    }

    @Test func buildCommand_shouldReplaceAllPlaceholders() {
        let command = createTestCommand(
            template: "cd \"{image_dir}\" && process \"{image_name}\" \"{prompt}\" \"{image_path}\""
        )
        let result = command.buildCommand(
            imagePath: "/Users/test/screenshots/capture.png",
            prompt: "Summarize"
        )

        #expect(result.contains("/Users/test/screenshots"))
        #expect(result.contains("capture.png"))
        #expect(result.contains("Summarize"))
        #expect(result.contains("/Users/test/screenshots/capture.png"))
    }

    // MARK: - Preset Tests

    @Test func presets_shouldContainOCRCommand() {
        let ocrPreset = AICommand.presets.first { $0.name == AICommand.ocrCommandName }
        #expect(ocrPreset != nil)
        #expect(ocrPreset?.isOCR == true)
    }

    @Test func presets_shouldContainGeminiCommand() {
        let geminiPreset = AICommand.presets.first { $0.name == "Gemini" }
        #expect(geminiPreset != nil)
        #expect(geminiPreset?.template.contains("gemini") == true)
    }

    @Test func presets_shouldHaveAtLeastOneEnabledCommand() {
        let enabledCount = AICommand.presets.filter { $0.isEnabled }.count
        #expect(enabledCount >= 1)
    }

    @Test func presets_shouldHaveUniqueNames() {
        let names = AICommand.presets.map { $0.name }
        let uniqueNames = Set(names)
        #expect(names.count == uniqueNames.count)
    }

    // MARK: - Edge Case Tests

    @Test func buildCommand_withEmptyPrompt_shouldReplaceWithEmpty() {
        let command = createTestCommand(
            template: "ai \"{prompt}\"",
            defaultPrompt: ""
        )
        let result = command.buildCommand(imagePath: "/test.png")
        #expect(result == "ai \"\"")
    }

    @Test func buildCommand_withSpecialCharactersInPath_shouldPreserve() {
        let command = createTestCommand(template: "{image_path}")
        let pathWithSpaces = "/path/with spaces/image file.png"
        let result = command.buildCommand(imagePath: pathWithSpaces)
        #expect(result == pathWithSpaces)
    }

    @Test func buildCommand_withJapanesePrompt_shouldPreserve() {
        let command = createTestCommand(template: "ai \"{prompt}\"")
        let japanesePrompt = "この画像を要約してください"
        let result = command.buildCommand(imagePath: "/test.png", prompt: japanesePrompt)
        #expect(result.contains(japanesePrompt))
    }

    // MARK: - Codable Tests

    @Test func aiCommand_shouldBeEncodableAndDecodable() throws {
        let original = createTestCommand(
            name: "Test",
            template: "echo {prompt}",
            defaultPrompt: "Hello",
            isEnabled: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AICommand.self, from: data)

        #expect(decoded.name == original.name)
        #expect(decoded.template == original.template)
        #expect(decoded.defaultPrompt == original.defaultPrompt)
        #expect(decoded.isEnabled == original.isEnabled)
    }

    // MARK: - Identifiable Tests

    @Test func aiCommand_shouldHaveUniqueIds() {
        let command1 = createTestCommand()
        let command2 = createTestCommand()
        #expect(command1.id != command2.id)
    }
}
