//
//  BrowserProfileService.swift
//  ScapLog
//
//  Browser profile detection for Chrome, Brave, Edge, Firefox, and Arc
//

import Foundation

// MARK: - Browser Types

enum BrowserType: String, CaseIterable, Codable, Identifiable {
    case chrome = "chrome"
    case brave = "brave"
    case edge = "edge"
    case firefox = "firefox"
    case arc = "arc"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chrome: return "Google Chrome"
        case .brave: return "Brave"
        case .edge: return "Microsoft Edge"
        case .firefox: return "Firefox"
        case .arc: return "Arc"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .chrome: return "com.google.Chrome"
        case .brave: return "com.brave.Browser"
        case .edge: return "com.microsoft.edgemac"
        case .firefox: return "org.mozilla.firefox"
        case .arc: return "company.thebrowser.Browser"
        }
    }

    var profileDirectory: URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first

        switch self {
        case .chrome:
            return appSupport?.appendingPathComponent("Google/Chrome")
        case .brave:
            return appSupport?.appendingPathComponent("BraveSoftware/Brave-Browser")
        case .edge:
            return appSupport?.appendingPathComponent("Microsoft Edge")
        case .firefox:
            return appSupport?.appendingPathComponent("Firefox")
        case .arc:
            return appSupport?.appendingPathComponent("Arc")
        }
    }
}

// MARK: - Browser Profile

struct BrowserProfile: Identifiable, Codable, Hashable {
    let id: String           // Unique ID: "browser:profileId"
    let name: String         // Display name
    let browser: BrowserType
    let profileId: String    // Original profile ID (e.g., "Profile 1", "default")

    init(browser: BrowserType, profileId: String, name: String) {
        self.id = "\(browser.rawValue):\(profileId)"
        self.name = name
        self.browser = browser
        self.profileId = profileId
    }

    /// The name that appears in window title (for matching)
    var windowTitleName: String {
        // Chrome/Brave/Edge show profile name in title
        // Arc shows Space name
        return name
    }
}

// MARK: - Browser Profile Service

class BrowserProfileService {
    static let shared = BrowserProfileService()

    private init() {}

    /// Detect all browser profiles from installed browsers
    func detectAllProfiles() -> [BrowserProfile] {
        var profiles: [BrowserProfile] = []

        // Chromium-based browsers
        profiles.append(contentsOf: getChromiumProfiles(browser: .chrome))
        profiles.append(contentsOf: getChromiumProfiles(browser: .brave))
        profiles.append(contentsOf: getChromiumProfiles(browser: .edge))

        // Firefox
        profiles.append(contentsOf: getFirefoxProfiles())

        // Arc
        profiles.append(contentsOf: getArcSpaces())

        return profiles
    }

    /// Get profiles for a specific browser type
    func getProfiles(for browser: BrowserType) -> [BrowserProfile] {
        switch browser {
        case .chrome, .brave, .edge:
            return getChromiumProfiles(browser: browser)
        case .firefox:
            return getFirefoxProfiles()
        case .arc:
            return getArcSpaces()
        }
    }

    // MARK: - Chromium Profiles (Chrome, Brave, Edge)

    func getChromiumProfiles(browser: BrowserType) -> [BrowserProfile] {
        guard let baseDir = browser.profileDirectory else { return [] }

        let localStatePath = baseDir.appendingPathComponent("Local State")

        guard FileManager.default.fileExists(atPath: localStatePath.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: localStatePath)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let profileCache = json["profile"] as? [String: Any],
                  let infoCache = profileCache["info_cache"] as? [String: Any] else {
                return []
            }

            var profiles: [BrowserProfile] = []

            for (profileId, info) in infoCache {
                guard let profileInfo = info as? [String: Any],
                      let name = profileInfo["name"] as? String else {
                    continue
                }

                let profile = BrowserProfile(
                    browser: browser,
                    profileId: profileId,
                    name: name
                )
                profiles.append(profile)
            }

            return profiles.sorted { $0.name < $1.name }
        } catch {
            print("[BrowserProfileService] Failed to read \(browser.displayName) profiles: \(error)")
            return []
        }
    }

    // MARK: - Firefox Profiles

    func getFirefoxProfiles() -> [BrowserProfile] {
        guard let baseDir = BrowserType.firefox.profileDirectory else { return [] }

        let profilesIniPath = baseDir.appendingPathComponent("profiles.ini")

        guard FileManager.default.fileExists(atPath: profilesIniPath.path) else {
            return []
        }

        do {
            let content = try String(contentsOf: profilesIniPath, encoding: .utf8)
            return parseFirefoxProfilesIni(content)
        } catch {
            print("[BrowserProfileService] Failed to read Firefox profiles: \(error)")
            return []
        }
    }

    private func parseFirefoxProfilesIni(_ content: String) -> [BrowserProfile] {
        var profiles: [BrowserProfile] = []
        var currentSection: String?
        var currentName: String?
        var currentPath: String?

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                // Save previous profile if exists
                if let section = currentSection, section.hasPrefix("Profile"),
                   let name = currentName, let path = currentPath {
                    let profile = BrowserProfile(
                        browser: .firefox,
                        profileId: path,
                        name: name
                    )
                    profiles.append(profile)
                }

                // Start new section
                currentSection = String(trimmed.dropFirst().dropLast())
                currentName = nil
                currentPath = nil
            } else if trimmed.hasPrefix("Name=") {
                currentName = String(trimmed.dropFirst(5))
            } else if trimmed.hasPrefix("Path=") {
                currentPath = String(trimmed.dropFirst(5))
            }
        }

        // Don't forget the last profile
        if let section = currentSection, section.hasPrefix("Profile"),
           let name = currentName, let path = currentPath {
            let profile = BrowserProfile(
                browser: .firefox,
                profileId: path,
                name: name
            )
            profiles.append(profile)
        }

        return profiles.sorted { $0.name < $1.name }
    }

    // MARK: - Arc Spaces

    func getArcSpaces() -> [BrowserProfile] {
        guard let baseDir = BrowserType.arc.profileDirectory else { return [] }

        // Arc stores sidebar data in StorableSidebar.json
        let sidebarPath = baseDir.appendingPathComponent("StorableSidebar.json")

        guard FileManager.default.fileExists(atPath: sidebarPath.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: sidebarPath)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return []
            }

            return parseArcSpaces(json)
        } catch {
            print("[BrowserProfileService] Failed to read Arc spaces: \(error)")
            return []
        }
    }

    private func parseArcSpaces(_ json: [String: Any]) -> [BrowserProfile] {
        var profiles: [BrowserProfile] = []

        // Arc's structure: containers -> spaces
        guard let containers = json["containers"] as? [[String: Any]] else {
            // Try alternative structure
            if let spaces = json["spaces"] as? [[String: Any]] {
                for space in spaces {
                    if let id = space["id"] as? String,
                       let title = space["title"] as? String {
                        let profile = BrowserProfile(
                            browser: .arc,
                            profileId: id,
                            name: title
                        )
                        profiles.append(profile)
                    }
                }
            }
            return profiles
        }

        for container in containers {
            if let spaces = container["spaces"] as? [[String: Any]] {
                for space in spaces {
                    if let id = space["id"] as? String,
                       let title = space["title"] as? String {
                        let profile = BrowserProfile(
                            browser: .arc,
                            profileId: id,
                            name: title
                        )
                        profiles.append(profile)
                    }
                }
            }
        }

        return profiles.sorted { $0.name < $1.name }
    }

    // MARK: - Profile Matching

    /// Check if a window title matches any of the excluded profiles
    func matchesProfile(_ windowTitle: String?, bundleId: String?, excludedProfiles: [String]) -> BrowserProfile? {
        guard let title = windowTitle, !title.isEmpty else { return nil }

        // Get the browser type from bundle ID
        let browser = BrowserType.allCases.first { $0.bundleIdentifier == bundleId }

        for profileId in excludedProfiles {
            let parts = profileId.split(separator: ":")
            guard parts.count >= 2 else { continue }

            let browserRaw = String(parts[0])
            let profileName = parts.dropFirst().joined(separator: ":")

            // If we know the browser, only check profiles for that browser
            if let browser = browser {
                guard browser.rawValue == browserRaw else { continue }
            }

            // Get the actual profile to find the display name
            if let profileBrowser = BrowserType(rawValue: browserRaw) {
                let profiles = getProfiles(for: profileBrowser)
                if let profile = profiles.first(where: { $0.id == profileId }) {
                    // Check if window title contains the profile name
                    if title.localizedCaseInsensitiveContains(profile.name) {
                        return profile
                    }
                }
            }
        }

        return nil
    }
}
