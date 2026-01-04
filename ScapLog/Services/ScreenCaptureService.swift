//
//  ScreenCaptureService.swift
//  ScapLog
//

import Foundation
import ScreenCaptureKit
import AppKit
import CoreGraphics
import Observation

@Observable
@MainActor
class ScreenCaptureService {
    static let shared = ScreenCaptureService()

    var isAuthorized: Bool = false
    var lastError: String?

    private init() {
        Task {
            await checkPermission()
        }
    }

    func checkPermission() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            isAuthorized = !content.displays.isEmpty
        } catch {
            isAuthorized = false
            lastError = error.localizedDescription
        }
    }

    func requestPermission() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    func captureScreen() async throws -> URL {
        guard isAuthorized else {
            throw CaptureError.notAuthorized
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        let image: CGImage

        // Check if we should capture only the frontmost window
        if AppSettings.shared.captureFrontmostWindowOnly {
            // Find the frontmost app's window
            guard let frontApp = NSWorkspace.shared.frontmostApplication else {
                throw CaptureError.noWindow
            }

            let frontPID = frontApp.processIdentifier

            // Find windows belonging to the frontmost app
            let frontWindows = content.windows.filter { window in
                window.owningApplication?.processID == frontPID
            }

            guard let frontWindow = frontWindows.first else {
                // Fallback to full screen if no window found
                guard let display = content.displays.first else {
                    throw CaptureError.noDisplay
                }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = createConfig(width: Int(display.width), height: Int(display.height))
                image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                print("[ScreenCapture] Fallback to full screen (no frontmost window found)")
                return try saveImage(image)
            }

            // Capture only the frontmost window
            let filter = SCContentFilter(desktopIndependentWindow: frontWindow)
            let config = createConfig(width: Int(frontWindow.frame.width), height: Int(frontWindow.frame.height))
            image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            print("[ScreenCapture] Captured frontmost window: \(frontApp.localizedName ?? "Unknown")")
        } else {
            // Capture full screen
            guard let display = content.displays.first else {
                throw CaptureError.noDisplay
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = createConfig(width: Int(display.width), height: Int(display.height))
            image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            print("[ScreenCapture] Captured full screen")
        }

        return try saveImage(image)
    }

    private func createConfig(width: Int, height: Int) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.showsCursor = true
        return config
    }

    private func saveImage(_ image: CGImage) throws -> URL {
        let settings = AppSettings.shared

        // If analyze as PNG then convert is enabled, save as PNG first (for analysis)
        // CaptureManager will call convertToFinalFormat after AI analysis
        if settings.analyzeAsPngThenConvert && settings.screenshotFormat != .png {
            return try saveImageAsPng(image)
        }

        // Direct save in final format
        return try saveImageInFormat(image, format: settings.screenshotFormat)
    }

    /// Save image as PNG for high-quality analysis
    private func saveImageAsPng(_ image: CGImage) throws -> URL {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "screenshot_\(timestamp)_temp.png"
        let fileURL = AppSettings.screenshotsDirectory.appendingPathComponent(filename)

        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw CaptureError.saveFailed
        }

        try pngData.write(to: fileURL)

        let sizeKB = pngData.count / 1024
        print("[ScreenCapture] Saved temp PNG for analysis: \(filename) (\(sizeKB) KB)")

        return fileURL
    }

    /// Save image in specified format
    private func saveImageInFormat(_ image: CGImage, format: ScreenshotFormat) throws -> URL {
        let settings = AppSettings.shared
        let filename = "screenshot_\(Int(Date().timeIntervalSince1970)).\(format.fileExtension)"
        let fileURL = AppSettings.screenshotsDirectory.appendingPathComponent(filename)

        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw CaptureError.saveFailed
        }

        let imageData: Data?

        switch format {
        case .png:
            imageData = bitmap.representation(using: .png, properties: [:])
        case .jpeg:
            imageData = bitmap.representation(using: .jpeg, properties: [
                .compressionFactor: settings.jpegQuality
            ])
        }

        guard let data = imageData else {
            throw CaptureError.saveFailed
        }

        try data.write(to: fileURL)

        let sizeKB = data.count / 1024
        print("[ScreenCapture] Saved \(format.displayName): \(filename) (\(sizeKB) KB)")

        return fileURL
    }

    /// Convert temporary PNG to final format after analysis
    /// - Parameters:
    ///   - tempPngURL: URL to the temporary PNG file
    /// - Returns: URL to the converted file in final format
    func convertToFinalFormat(from tempPngURL: URL) throws -> URL {
        let settings = AppSettings.shared
        let format = settings.screenshotFormat

        // If already PNG or not using conversion mode, return as-is
        guard format != .png && settings.analyzeAsPngThenConvert else {
            return tempPngURL
        }

        // Load the temporary PNG
        guard let nsImage = NSImage(contentsOf: tempPngURL) else {
            throw CaptureError.saveFailed
        }

        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            throw CaptureError.saveFailed
        }

        // Create final filename (remove _temp and change extension)
        let timestamp = Int(Date().timeIntervalSince1970)
        let finalFilename = "screenshot_\(timestamp).\(format.fileExtension)"
        let finalURL = AppSettings.screenshotsDirectory.appendingPathComponent(finalFilename)

        // Convert to final format
        let imageData: Data?
        switch format {
        case .png:
            imageData = bitmap.representation(using: .png, properties: [:])
        case .jpeg:
            imageData = bitmap.representation(using: .jpeg, properties: [
                .compressionFactor: settings.jpegQuality
            ])
        }

        guard let data = imageData else {
            throw CaptureError.saveFailed
        }

        try data.write(to: finalURL)

        // Delete temporary PNG
        do {
            try FileManager.default.removeItem(at: tempPngURL)
        } catch {
            print("[ScreenCapture] Warning: Failed to delete temporary file \(tempPngURL.lastPathComponent): \(error.localizedDescription)")
        }

        let sizeKB = data.count / 1024
        print("[ScreenCapture] Converted to \(format.displayName): \(finalFilename) (\(sizeKB) KB)")

        return finalURL
    }

    func getActiveAppInfo() -> (appName: String?, windowTitle: String?, bundleId: String?, pid: Int32?) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else {
            return (nil, nil, nil, nil)
        }

        let appName = frontApp.localizedName
        let bundleId = frontApp.bundleIdentifier
        let pid = frontApp.processIdentifier
        var windowTitle: String? = nil

        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        if AXIsProcessTrustedWithOptions(options) {
            let app = AXUIElementCreateApplication(pid)

            var focusedWindow: CFTypeRef?
            if AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success {
                var title: CFTypeRef?
                if AXUIElementCopyAttributeValue(focusedWindow as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success {
                    windowTitle = title as? String
                }
            }
        }

        return (appName, windowTitle, bundleId, pid)
    }

    /// Detects if the current browser is in private/incognito mode
    func isPrivateBrowsing(bundleId: String?, windowTitle: String?) -> Bool {
        guard let bundleId = bundleId else { return false }

        // Check based on browser type
        switch bundleId {
        case "com.apple.Safari":
            // Safari: Check window title for "Private" indicator
            // Safari private windows have "プライベートブラウズ" or "Private" in title bar
            if let title = windowTitle {
                if title.contains("プライベート") || title.lowercased().contains("private") {
                    return true
                }
            }
            // Also try AppleScript (more reliable)
            return isSafariPrivate()

        case "com.google.Chrome", "com.brave.Browser", "com.microsoft.edgemac":
            // Chrome/Brave/Edge: Window title contains "Incognito" or "InPrivate"
            if let title = windowTitle {
                let lowerTitle = title.lowercased()
                return lowerTitle.contains("incognito") ||
                       lowerTitle.contains("inprivate") ||
                       lowerTitle.contains("シークレット")
            }

        case "org.mozilla.firefox":
            // Firefox: Window title contains "Private" or "プライベート"
            if let title = windowTitle {
                let lowerTitle = title.lowercased()
                return lowerTitle.contains("private browsing") ||
                       title.contains("プライベートブラウジング")
            }

        case "company.thebrowser.Browser":
            // Arc: Check for private space indicator
            if let title = windowTitle {
                // Arc private windows often have different indicators
                return title.contains("Private") || title.contains("プライベート")
            }

        default:
            break
        }

        return false
    }

    /// Check Safari private mode via AppleScript
    private func isSafariPrivate() -> Bool {
        // Only run if Safari is the frontmost app
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.bundleIdentifier == "com.apple.Safari" else {
            return false
        }

        let script = """
        tell application "Safari"
            if (count of windows) > 0 then
                set currentWindow to front window
                try
                    return private of currentWindow
                on error
                    return false
                end try
            end if
        end tell
        return false
        """

        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            return false
        }

        let result = appleScript.executeAndReturnError(&error)

        if error != nil {
            print("[ScreenCapture] AppleScript error checking Safari private mode")
            return false
        }

        return result.booleanValue
    }

    enum CaptureError: LocalizedError {
        case notAuthorized
        case noDisplay
        case noWindow
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return NSLocalizedString("error.screen_capture.not_authorized", comment: "")
            case .noDisplay:
                return NSLocalizedString("error.screen_capture.no_display", comment: "")
            case .noWindow:
                return NSLocalizedString("error.screen_capture.no_window", comment: "")
            case .saveFailed:
                return NSLocalizedString("error.screen_capture.save_failed", comment: "")
            }
        }
    }
}
