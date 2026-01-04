//
//  CaptureManager.swift
//  ScapLog
//

import Foundation
import Observation
import AppKit

@Observable
@MainActor
class CaptureManager {
    static let shared = CaptureManager()

    var isCapturing: Bool = false
    var lastSummary: String?
    var lastError: String?
    var captureCount: Int = 0
    var isPausedForSleep: Bool = false

    private var captureTimer: Timer?
    private let settings = AppSettings.shared
    private let screenCapture = ScreenCaptureService.shared
    private let aiService = AIService.shared
    private let ocrService = OCRService.shared
    private let database = DatabaseService.shared
    private let privacyFilter = PrivacyFilterService.shared

    private init() {
        setupNotifications()
        setupSleepNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .performCapture,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.performCapture()
            }
        }
    }

    private func setupSleepNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if AppSettings.shared.pauseCaptureDuringSleep {
                    self?.isPausedForSleep = true
                    print("[Capture] Paused - system going to sleep")
                }
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPausedForSleep = false
                print("[Capture] Resumed - system woke up")
            }
        }
    }

    func startCapturing() {
        guard !isCapturing else { return }
        guard screenCapture.isAuthorized else {
            lastError = "画面収録の権限がありません"
            return
        }
        guard settings.selectedCommand != nil else {
            lastError = "AIコマンドが選択されていません"
            return
        }

        isCapturing = true
        lastError = nil

        Task {
            await performCapture()
        }

        captureTimer = Timer.scheduledTimer(withTimeInterval: settings.captureInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performCapture()
            }
        }
    }

    func stopCapturing() {
        captureTimer?.invalidate()
        captureTimer = nil
        isCapturing = false
    }

    func performCapture() async {
        print("[Capture] performCapture() called")

        // Check if paused for sleep
        guard !isPausedForSleep else {
            print("[Capture] Skipped - paused for sleep")
            return
        }

        guard let command = settings.selectedCommand else {
            lastError = "AIコマンドが選択されていません"
            print("[Capture] Skipped - no command selected")
            return
        }

        print("[Capture] Using command: \(command.name), isOCR: \(command.isOCR)")

        // Check if current app is excluded
        let appInfo = screenCapture.getActiveAppInfo()
        if let bundleId = appInfo.bundleId, settings.isAppExcluded(bundleId: bundleId) {
            print("[Capture] Skipped - app excluded: \(bundleId)")
            return
        }

        // Background app check (when excludeOnlyWhenForeground is false AND capturing all windows)
        if !settings.excludeOnlyWhenForeground && !settings.captureFrontmostWindowOnly {
            if let excludedApp = isExcludedAppRunning() {
                print("[Capture] Skipped - excluded app running in background: \(excludedApp)")
                return
            }
            if let excludedBrowser = isExcludedBrowserRunning() {
                print("[Capture] Skipped - excluded browser profile running: \(excludedBrowser)")
                return
            }
        }

        // Check if private browsing is active (and setting is enabled)
        if settings.skipPrivateBrowsing {
            if screenCapture.isPrivateBrowsing(bundleId: appInfo.bundleId, windowTitle: appInfo.windowTitle) {
                print("[Capture] Skipped - private browsing detected")
                return
            }
        }

        // Privacy filter check (keywords and browser profiles)
        let filterAction = privacyFilter.checkWindow(
            title: appInfo.windowTitle,
            bundleId: appInfo.bundleId
        )

        switch filterAction {
        case .exclude:
            print("[Capture] Skipped - privacy filter (exclude)")
            return
        case .mask, .allow:
            break  // Continue with capture
        }

        // Show visual feedback only after all checks pass (right before capture)
        if settings.captureFlashEnabled {
            FeedbackService.shared.showCaptureFlash()
        }

        do {
            print("[Capture] Taking screenshot...")
            let screenshotURL = try await screenCapture.captureScreen()
            print("[Capture] Screenshot saved: \(screenshotURL.path)")

            var summaryText: String

            if filterAction == .mask {
                // Use masked summary instead of actual content
                print("[Capture] Using masked summary (privacy filter)")
                summaryText = privacyFilter.getMaskedSummary()
            } else if command.isOCR {
                // Use built-in macOS OCR
                print("[Capture] Running OCR...")
                summaryText = try await ocrService.generateSummary(from: screenshotURL.path)
                print("[Capture] OCR result: \(summaryText.prefix(100))...")
            } else {
                // Use external AI command
                print("[Capture] Running AI command...")
                let customPrompt = settings.customPrompt.isEmpty ? nil : settings.customPrompt
                summaryText = try await aiService.generateSummary(
                    command: command,
                    imagePath: screenshotURL.path,
                    customPrompt: customPrompt
                )
                print("[Capture] AI result: \(summaryText.prefix(100))...")
            }

            // Convert to final format after analysis (if enabled)
            let finalScreenshotURL: URL
            if settings.analyzeAsPngThenConvert && settings.screenshotFormat != .png {
                finalScreenshotURL = try screenCapture.convertToFinalFormat(from: screenshotURL)
            } else {
                finalScreenshotURL = screenshotURL
            }

            let summary = Summary(
                timestamp: Date(),
                summary: summaryText,
                screenshotPath: finalScreenshotURL.path,
                appName: appInfo.appName,
                windowTitle: appInfo.windowTitle
            )

            print("[Capture] Saving to database...")
            try await database.saveSummaryAsync(summary)
            print("[Capture] Saved successfully!")

            lastSummary = summaryText
            lastError = nil
            captureCount += 1

        } catch {
            print("[Capture] Error: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }

    // MARK: - Background App Checking

    /// Check if any excluded app is running (even in background)
    /// Note: This method is @MainActor-isolated for thread safety
    private func isExcludedAppRunning() -> String? {
        let runningApps = NSWorkspace.shared.runningApplications
        // Take a local copy to ensure consistency during iteration
        let excludedApps = Array(settings.excludedApps)
        for bundleId in excludedApps {
            if runningApps.contains(where: { $0.bundleIdentifier == bundleId }) {
                return bundleId
            }
        }
        return nil
    }

    /// Check if any browser with excluded profile is running
    /// Note: This method is @MainActor-isolated for thread safety
    private func isExcludedBrowserRunning() -> String? {
        let runningApps = NSWorkspace.shared.runningApplications
        // Take a local copy to ensure consistency during iteration
        let excludedProfiles = Array(settings.excludedProfiles)

        for profileId in excludedProfiles {
            let parts = profileId.split(separator: ":")
            guard parts.count >= 2 else { continue }

            let browserRaw = String(parts[0])
            guard let browserType = BrowserType(rawValue: browserRaw) else { continue }

            // Check if the browser is running
            if runningApps.contains(where: { $0.bundleIdentifier == browserType.bundleIdentifier }) {
                return profileId
            }
        }
        return nil
    }
}
