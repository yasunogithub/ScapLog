//
//  PrivacyFilterService.swift
//  ScapLog
//
//  Privacy filtering based on window title keywords and browser profiles
//

import Foundation

// MARK: - Filter Action

enum PrivacyFilterAction {
    case allow      // Normal capture
    case exclude    // Skip capture entirely
    case mask       // Capture but mask the summary
}

// MARK: - Privacy Filter Service

class PrivacyFilterService {
    static let shared = PrivacyFilterService()

    private let settings = AppSettings.shared
    private let browserService = BrowserProfileService.shared

    private init() {}

    /// Check if window should be filtered
    /// - Parameters:
    ///   - title: Window title
    ///   - bundleId: App bundle identifier
    /// - Returns: The filter action to take
    func checkWindow(title: String?, bundleId: String?) -> PrivacyFilterAction {
        guard let windowTitle = title, !windowTitle.isEmpty else {
            return .allow
        }

        // Check exclude keywords first (highest priority)
        if matchesExcludeKeyword(windowTitle) {
            print("[PrivacyFilter] Excluding capture - matched exclude keyword in: \(windowTitle)")
            return .exclude
        }

        // Check excluded browser profiles
        if let matchedProfile = matchesExcludedProfile(windowTitle, bundleId: bundleId) {
            print("[PrivacyFilter] Excluding capture - matched profile: \(matchedProfile.name)")
            return .exclude
        }

        // Check mask keywords (lower priority than exclude)
        if matchesMaskKeyword(windowTitle) {
            print("[PrivacyFilter] Masking capture - matched mask keyword in: \(windowTitle)")
            return .mask
        }

        return .allow
    }

    // MARK: - Keyword Matching

    /// Check if window title matches any exclude keyword
    func matchesExcludeKeyword(_ title: String) -> Bool {
        let keywords = settings.excludeKeywords
        guard !keywords.isEmpty else { return false }

        for keyword in keywords {
            if title.localizedCaseInsensitiveContains(keyword) {
                return true
            }
        }

        return false
    }

    /// Check if window title matches any mask keyword
    func matchesMaskKeyword(_ title: String) -> Bool {
        let keywords = settings.maskKeywords
        guard !keywords.isEmpty else { return false }

        for keyword in keywords {
            if title.localizedCaseInsensitiveContains(keyword) {
                return true
            }
        }

        return false
    }

    // MARK: - Profile Matching

    /// Check if window matches any excluded browser profile
    func matchesExcludedProfile(_ title: String, bundleId: String?) -> BrowserProfile? {
        let excludedProfiles = settings.excludedProfiles
        guard !excludedProfiles.isEmpty else { return nil }

        return browserService.matchesProfile(title, bundleId: bundleId, excludedProfiles: excludedProfiles)
    }

    // MARK: - Masking

    /// Get masked summary text
    func getMaskedSummary() -> String {
        return "[プライベート] - このキャプチャはプライバシー設定によりマスクされています"
    }

    /// Check if a specific keyword is in exclude list
    func isExcludeKeyword(_ keyword: String) -> Bool {
        return settings.excludeKeywords.contains { $0.lowercased() == keyword.lowercased() }
    }

    /// Check if a specific keyword is in mask list
    func isMaskKeyword(_ keyword: String) -> Bool {
        return settings.maskKeywords.contains { $0.lowercased() == keyword.lowercased() }
    }

    /// Check if a profile is excluded
    func isProfileExcluded(_ profileId: String) -> Bool {
        return settings.excludedProfiles.contains(profileId)
    }
}
