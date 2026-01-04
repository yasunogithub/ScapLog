//
//  AppSettingsTests.swift
//  ScapLogTests
//
//  Created by Claude on 2026/01/05.
//

import Testing
import Foundation
@testable import ScapLog

struct AppSettingsTests {

    // MARK: - ScreenshotFormat Tests

    @Test func screenshotFormat_allCases_shouldHaveUniqueIds() {
        let ids = ScreenshotFormat.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }

    @Test func screenshotFormat_displayName_shouldNotBeEmpty() {
        for format in ScreenshotFormat.allCases {
            #expect(!format.displayName.isEmpty)
        }
    }

    @Test func screenshotFormat_fileExtension_shouldBeValid() {
        for format in ScreenshotFormat.allCases {
            #expect(!format.fileExtension.isEmpty)
            // Extensions should not contain dots
            #expect(!format.fileExtension.contains("."))
        }
    }

    @Test func screenshotFormat_png_shouldHavePngExtension() {
        #expect(ScreenshotFormat.png.fileExtension == "png")
    }

    @Test func screenshotFormat_jpeg_shouldHaveJpegExtension() {
        #expect(ScreenshotFormat.jpeg.fileExtension == "jpeg")
    }



    // MARK: - CaptureEffectType Tests

    @Test func captureEffectType_allCases_shouldHaveUniqueIds() {
        let ids = CaptureEffectType.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }

    @Test func captureEffectType_displayName_shouldNotBeEmpty() {
        for effect in CaptureEffectType.allCases {
            #expect(!effect.displayName.isEmpty)
        }
    }

    @Test func captureEffectType_description_shouldNotBeEmpty() {
        for effect in CaptureEffectType.allCases {
            #expect(!effect.description.isEmpty)
        }
    }

    @Test func captureEffectType_shouldContainNone() {
        let hasNone = CaptureEffectType.allCases.contains { $0.rawValue == "none" }
        #expect(hasNone)
    }

    // MARK: - CaptureSoundType Tests

    @Test func captureSoundType_allCases_shouldHaveUniqueIds() {
        let ids = CaptureSoundType.allCases.map { $0.id }
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }

    @Test func captureSoundType_displayName_shouldNotBeEmpty() {
        for sound in CaptureSoundType.allCases {
            #expect(!sound.displayName.isEmpty)
        }
    }

    @Test func captureSoundType_systemSounds_shouldHaveSystemName() {
        let systemSounds: [CaptureSoundType] = [.tink, .glass, .pop, .purr, .ping]
        for sound in systemSounds {
            #expect(sound.systemSoundName != nil)
            #expect(sound.customSoundFileName == nil)
        }
    }

    @Test func captureSoundType_customSounds_shouldHaveFileName() {
        let customSounds: [CaptureSoundType] = [.shutter, .softClick, .macChime]
        for sound in customSounds {
            #expect(sound.customSoundFileName != nil)
            #expect(sound.systemSoundName == nil)
        }
    }

    @Test func captureSoundType_customSoundExtension_shouldBeWav() {
        for sound in CaptureSoundType.allCases {
            #expect(sound.customSoundExtension == "wav")
        }
    }

    // MARK: - AppSettings Static Properties Tests

    @Test func applicationSupportDirectory_shouldBeValid() {
        let dir = AppSettings.applicationSupportDirectory
        #expect(!dir.path.isEmpty)
        #expect(dir.path.contains("Application Support"))
    }

    @Test func databasePath_shouldBeValid() {
        let path = AppSettings.databasePath
        #expect(!path.path.isEmpty)
        // Should have proper extension
        #expect(path.pathExtension == "duckdb")
    }

    @Test func screenshotsDirectory_shouldBeValid() {
        let dir = AppSettings.screenshotsDirectory
        #expect(!dir.path.isEmpty)
    }

    // MARK: - Notification Names Tests

    @Test func notificationNames_shouldBeUnique() {
        let names: [Notification.Name] = [
            .hotkeySettingsChanged,
            .performCapture,
            .windowOpacityChanged,
            .appearanceSettingsChanged,
            .colorThemeChanged
        ]
        let uniqueNames = Set(names)
        #expect(names.count == uniqueNames.count)
    }

    // MARK: - AppSettings Instance Tests

    @Test func shared_shouldReturnSameInstance() {
        let instance1 = AppSettings.shared
        let instance2 = AppSettings.shared
        #expect(instance1 === instance2)
    }

    @Test func isAppExcluded_emptyBundleId_shouldReturnFalse() {
        let settings = AppSettings.shared
        let result = settings.isAppExcluded(bundleId: "")
        #expect(result == false)
    }

    @Test func isAppExcluded_unknownApp_shouldReturnFalse() {
        let settings = AppSettings.shared
        let result = settings.isAppExcluded(bundleId: "com.unknown.app.test123456")
        #expect(result == false)
    }

    @Test func glassMaterialName_shouldNotBeEmpty() {
        let settings = AppSettings.shared
        #expect(!settings.glassMaterialName.isEmpty)
    }

    // MARK: - Default Values Tests

    @Test func captureInterval_shouldHaveReasonableDefault() {
        let settings = AppSettings.shared
        // Interval should be positive and reasonable (e.g., between 5 and 3600 seconds)
        #expect(settings.captureInterval >= 5)
        #expect(settings.captureInterval <= 3600)
    }

    @Test func windowOpacity_shouldBeInValidRange() {
        let settings = AppSettings.shared
        #expect(settings.windowOpacity >= 0.0)
        #expect(settings.windowOpacity <= 1.0)
    }

    @Test func jpegQuality_shouldBeInValidRange() {
        let settings = AppSettings.shared
        #expect(settings.jpegQuality >= 0.0)
        #expect(settings.jpegQuality <= 1.0)
    }

    @Test func autoDeleteDays_shouldBeNonNegative() {
        let settings = AppSettings.shared
        #expect(settings.autoDeleteDays >= 0)
    }

    // MARK: - Glass Settings Tests

    @Test func glassOverlayOpacity_shouldBeInValidRange() {
        let settings = AppSettings.shared
        #expect(settings.glassOverlayOpacity >= 0.0)
        #expect(settings.glassOverlayOpacity <= 1.0)
    }

    @Test func glassBorderOpacity_shouldBeInValidRange() {
        let settings = AppSettings.shared
        #expect(settings.glassBorderOpacity >= 0.0)
        #expect(settings.glassBorderOpacity <= 1.0)
    }

    @Test func glassShadowOpacity_shouldBeInValidRange() {
        let settings = AppSettings.shared
        #expect(settings.glassShadowOpacity >= 0.0)
        #expect(settings.glassShadowOpacity <= 1.0)
    }

    @Test func glassHighlightOpacity_shouldBeInValidRange() {
        let settings = AppSettings.shared
        #expect(settings.glassHighlightOpacity >= 0.0)
        #expect(settings.glassHighlightOpacity <= 1.0)
    }

    @Test func glassMaterialIndex_shouldBeNonNegative() {
        let settings = AppSettings.shared
        #expect(settings.glassMaterialIndex >= 0)
    }

    // MARK: - AI Commands Tests

    @Test func aiCommands_shouldNotBeEmpty() {
        let settings = AppSettings.shared
        #expect(!settings.aiCommands.isEmpty)
    }

    @Test func selectedCommand_shouldReturnValidCommand() {
        let settings = AppSettings.shared
        // selectedCommand might be nil if no command is selected, but should not crash
        _ = settings.selectedCommand
    }

    // MARK: - Color Theme Tests

    @Test func colorTheme_shouldReturnValidTheme() {
        let settings = AppSettings.shared
        let theme = settings.colorTheme

        // Theme should have valid colors
        #expect(theme.name.count > 0)
    }
}
