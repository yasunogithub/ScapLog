//
//  Localization.swift
//  ScapLog
//
//  Localization helper for multi-language support
//

import Foundation
import SwiftUI

// MARK: - Localized String Keys

enum L10n {
    // MARK: - Common
    enum Common {
        static let cancel = String(localized: "common.cancel")
        static let ok = String(localized: "common.ok")
        static let delete = String(localized: "common.delete")
        static let save = String(localized: "common.save")
        static let close = String(localized: "common.close")
        static let add = String(localized: "common.add")
        static let edit = String(localized: "common.edit")
        static let done = String(localized: "common.done")
        static let error = String(localized: "common.error")
        static let success = String(localized: "common.success")
        static let loading = String(localized: "common.loading")
        static let none = String(localized: "common.none")
        static let unknown = String(localized: "common.unknown")
    }

    // MARK: - Settings
    enum Settings {
        static let title = String(localized: "settings.title")

        enum Capture {
            static let title = String(localized: "settings.capture.title")
            static let interval = String(localized: "settings.capture.interval")
            static let frontmostOnly = String(localized: "settings.capture.frontmost_only")
            static let frontmostOnlyDescription = String(localized: "settings.capture.frontmost_only.description")
            static let skipPrivate = String(localized: "settings.capture.skip_private")
            static let skipPrivateDescription = String(localized: "settings.capture.skip_private.description")
            static let effect = String(localized: "settings.capture.effect")
            static let sound = String(localized: "settings.capture.sound")
            static let soundDescription = String(localized: "settings.capture.sound.description")
        }

        enum General {
            static let title = String(localized: "settings.general.title")
            static let launchAtLogin = String(localized: "settings.general.launch_at_login")
            static let launchAtLoginDescription = String(localized: "settings.general.launch_at_login.description")
            static let hotkey = String(localized: "settings.general.hotkey")
            static let hotkeyDescription = String(localized: "settings.general.hotkey.description")
            static let hotkeyShortcut = String(localized: "settings.general.hotkey.shortcut")
            static let windowOpacity = String(localized: "settings.general.window_opacity")
            static let windowOpacityDescription = String(localized: "settings.general.window_opacity.description")
        }

        enum Appearance {
            static let title = String(localized: "settings.appearance.title")
            static let colorTheme = String(localized: "settings.appearance.color_theme")
            static let blurIntensity = String(localized: "settings.appearance.blur_intensity")
            static let blurIntensityDescription = String(localized: "settings.appearance.blur_intensity.description")
            static let overlay = String(localized: "settings.appearance.overlay")
            static let overlayDescription = String(localized: "settings.appearance.overlay.description")
            static let border = String(localized: "settings.appearance.border")
            static let borderDescription = String(localized: "settings.appearance.border.description")
            static let shadow = String(localized: "settings.appearance.shadow")
            static let shadowDescription = String(localized: "settings.appearance.shadow.description")
            static let highlight = String(localized: "settings.appearance.highlight")
            static let highlightDescription = String(localized: "settings.appearance.highlight.description")
            static let reset = String(localized: "settings.appearance.reset")
        }

        enum ExcludedApps {
            static let title = String(localized: "settings.excluded_apps.title")
            static let description = String(localized: "settings.excluded_apps.description")
            static let add = String(localized: "settings.excluded_apps.add")
            static let select = String(localized: "settings.excluded_apps.select")
        }

        enum AICommand {
            static let title = String(localized: "settings.ai_command.title")
            static let add = String(localized: "settings.ai_command.add")
            static let new = String(localized: "settings.ai_command.new")
            static let name = String(localized: "settings.ai_command.name")
            static let template = String(localized: "settings.ai_command.template")
            static let templatePlaceholder = String(localized: "settings.ai_command.template.placeholder")
            static let defaultPrompt = String(localized: "settings.ai_command.default_prompt")
            static let builtinOCR = String(localized: "settings.ai_command.builtin_ocr")
        }

        enum CustomPrompt {
            static let title = String(localized: "settings.custom_prompt.title")
            static let description = String(localized: "settings.custom_prompt.description")
        }

        enum DataLocation {
            static let title = String(localized: "settings.data_location.title")
            static let screenshotPath = String(localized: "settings.data_location.screenshot_path")
            static let selectFolder = String(localized: "settings.data_location.select_folder")
            static let resetDefault = String(localized: "settings.data_location.reset_default")
            static let openFinder = String(localized: "settings.data_location.open_finder")
            static let autoDelete = String(localized: "settings.data_location.auto_delete")
            static let autoDeleteDisabled = String(localized: "settings.data_location.auto_delete.disabled")
            static func autoDeleteDescription(_ days: Int) -> String {
                String(format: String(localized: "settings.data_location.auto_delete.description"), days)
            }
            static let saveFormat = String(localized: "settings.data_location.save_format")
            static let jpegQuality = String(localized: "settings.data_location.jpeg_quality")
            static let jpegQualityLow = String(localized: "settings.data_location.jpeg_quality.low")
            static let jpegQualityHigh = String(localized: "settings.data_location.jpeg_quality.high")
        }

        enum DataManagement {
            static let title = String(localized: "settings.data_management.title")
            static let count = String(localized: "settings.data_management.count")
            static let inUse = String(localized: "settings.data_management.in_use")

            enum Cleanup {
                static let title = String(localized: "settings.data_management.cleanup.title")
                static func target(_ days: Int) -> String {
                    String(format: String(localized: "settings.data_management.cleanup.target"), days)
                }
                static func preview(_ count: Int, _ size: String) -> String {
                    String(format: String(localized: "settings.data_management.cleanup.preview"), count, size)
                }
                static let previewDescription = String(localized: "settings.data_management.cleanup.preview.description")
                static let noData = String(localized: "settings.data_management.cleanup.no_data")
                static let deleting = String(localized: "settings.data_management.cleanup.deleting")
                static func confirm(_ days: Int) -> String {
                    String(format: String(localized: "settings.data_management.cleanup.confirm"), days)
                }
                static let confirmTitle = String(localized: "settings.data_management.cleanup.confirm.title")
            }
        }

        enum Export {
            static let title = String(localized: "settings.export.title")
            static let selectPeriod = String(localized: "settings.export.select_period")
            static let startDate = String(localized: "settings.export.start_date")
            static let endDate = String(localized: "settings.export.end_date")
            static func presetDays(_ days: Int) -> String {
                String(format: String(localized: "settings.export.preset.days"), days)
            }
            static let preset3Months = String(localized: "settings.export.preset.3months")
            static let format = String(localized: "settings.export.format")
            static func count(_ count: Int) -> String {
                String(format: String(localized: "settings.export.count"), count)
            }
            static let target = String(localized: "settings.export.target")
            static let button = String(localized: "settings.export.button")
            static let exporting = String(localized: "settings.export.exporting")
            static let saveDialogMessage = String(localized: "settings.export.save_dialog.message")

            enum Error {
                static let title = String(localized: "settings.export.error.title")
                static let unknown = String(localized: "settings.export.error.unknown")
                static let invalidDate = String(localized: "settings.export.error.invalid_date")
                static let noData = String(localized: "settings.export.error.no_data")
                static func saveFailed(_ error: String) -> String {
                    String(format: String(localized: "settings.export.error.save_failed"), error)
                }
                static func exportFailed(_ error: String) -> String {
                    String(format: String(localized: "settings.export.error.export_failed"), error)
                }
            }
        }
    }

    // MARK: - Statistics
    enum Statistics {
        static let title = String(localized: "statistics.title")
        static let totalCaptures = String(localized: "statistics.total_captures")
        static let today = String(localized: "statistics.today")
        static let averagePerDay = String(localized: "statistics.average_per_day")
        static let period = String(localized: "statistics.period")
        static let startDate = String(localized: "statistics.start_date")
        static let daysElapsed = String(localized: "statistics.days_elapsed")
        static func days(_ days: Int) -> String {
            String(format: String(localized: "statistics.days"), days)
        }
        static let appUsage = String(localized: "statistics.app_usage")
        static let noData = String(localized: "statistics.no_data")
    }

    // MARK: - Main
    enum Main {
        static let searchPlaceholder = String(localized: "main.search.placeholder")
        static let captureButton = String(localized: "main.capture.button")
        static let captureRunning = String(localized: "main.capture.running")
        static let captureStopped = String(localized: "main.capture.stopped")
        static let todaySummaries = String(localized: "main.today_summaries")
        static let recentSummaries = String(localized: "main.recent_summaries")
        static let noSummaries = String(localized: "main.no_summaries")
        static let deleteConfirm = String(localized: "main.delete_confirm")
    }

    // MARK: - Errors
    enum Errors {
        enum ScreenCapture {
            static let notAuthorized = String(localized: "error.screen_capture.not_authorized")
            static let noDisplay = String(localized: "error.screen_capture.no_display")
            static let noWindow = String(localized: "error.screen_capture.no_window")
            static let saveFailed = String(localized: "error.screen_capture.save_failed")
        }

        enum Database {
            static func connection(_ message: String) -> String {
                String(format: String(localized: "error.database.connection"), message)
            }
            static func query(_ message: String) -> String {
                String(format: String(localized: "error.database.query"), message)
            }
        }
    }

    // MARK: - Menu Bar
    enum MenuBar {
        static let showWindow = String(localized: "menubar.show_window")
        static let captureNow = String(localized: "menubar.capture_now")
        static let settings = String(localized: "menubar.settings")
        static let statistics = String(localized: "menubar.statistics")
        static let quit = String(localized: "menubar.quit")
    }
}

// MARK: - String Extension for Localization

extension String {
    /// Returns a localized string using the current locale
    var localized: String {
        NSLocalizedString(self, comment: "")
    }

    /// Returns a localized string with format arguments
    func localized(with arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}
