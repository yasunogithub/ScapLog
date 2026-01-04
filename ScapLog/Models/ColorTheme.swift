//
//  ColorTheme.swift
//  ScapLog
//
//  Vim-inspired color themes for the app
//

import SwiftUI

struct ColorTheme: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String

    // Main colors (stored as hex strings for Codable)
    let accentHex: String
    let backgroundTintHex: String
    let highlightHex: String
    let secondaryHex: String

    // Computed SwiftUI Colors
    var accent: Color { Color(hex: accentHex) }
    var backgroundTint: Color { Color(hex: backgroundTintHex) }
    var highlight: Color { Color(hex: highlightHex) }
    var secondary: Color { Color(hex: secondaryHex) }

    // Predefined themes inspired by popular Vim colorschemes
    static let themes: [ColorTheme] = [
        // Default - Cyan/Blue (current)
        ColorTheme(
            id: "default",
            name: "Default",
            description: "Clean cyan and blue",
            accentHex: "007AFF",
            backgroundTintHex: "00D4FF",
            highlightHex: "FFFFFF",
            secondaryHex: "8E8E93"
        ),

        // Nord - Cool blue/cyan
        ColorTheme(
            id: "nord",
            name: "Nord",
            description: "Arctic, north-bluish",
            accentHex: "88C0D0",
            backgroundTintHex: "5E81AC",
            highlightHex: "ECEFF4",
            secondaryHex: "D8DEE9"
        ),

        // Dracula - Purple/Pink
        ColorTheme(
            id: "dracula",
            name: "Dracula",
            description: "Dark purple vampire",
            accentHex: "BD93F9",
            backgroundTintHex: "FF79C6",
            highlightHex: "F8F8F2",
            secondaryHex: "6272A4"
        ),

        // Gruvbox - Warm orange/brown
        ColorTheme(
            id: "gruvbox",
            name: "Gruvbox",
            description: "Retro groovy",
            accentHex: "FE8019",
            backgroundTintHex: "D79921",
            highlightHex: "EBDBB2",
            secondaryHex: "928374"
        ),

        // Tokyo Night - Purple/Blue
        ColorTheme(
            id: "tokyonight",
            name: "Tokyo Night",
            description: "Neon city lights",
            accentHex: "7AA2F7",
            backgroundTintHex: "BB9AF7",
            highlightHex: "C0CAF5",
            secondaryHex: "565F89"
        ),

        // Monokai - Orange/Green
        ColorTheme(
            id: "monokai",
            name: "Monokai",
            description: "Classic sublime",
            accentHex: "A6E22E",
            backgroundTintHex: "FD971F",
            highlightHex: "F8F8F2",
            secondaryHex: "75715E"
        ),

        // One Dark - Blue/Purple
        ColorTheme(
            id: "onedark",
            name: "One Dark",
            description: "Atom editor style",
            accentHex: "61AFEF",
            backgroundTintHex: "C678DD",
            highlightHex: "ABB2BF",
            secondaryHex: "5C6370"
        ),

        // Catppuccin Mocha - Pastel
        ColorTheme(
            id: "catppuccin",
            name: "Catppuccin",
            description: "Soothing pastel",
            accentHex: "CBA6F7",
            backgroundTintHex: "F5C2E7",
            highlightHex: "CDD6F4",
            secondaryHex: "9399B2"
        ),

        // Solarized - Teal/Orange
        ColorTheme(
            id: "solarized",
            name: "Solarized",
            description: "Precision colors",
            accentHex: "268BD2",
            backgroundTintHex: "2AA198",
            highlightHex: "EEE8D5",
            secondaryHex: "93A1A1"
        ),

        // Rose Pine - Pink/Rose
        ColorTheme(
            id: "rosepine",
            name: "Rosé Pine",
            description: "All natural",
            accentHex: "EBBCBA",
            backgroundTintHex: "C4A7E7",
            highlightHex: "E0DEF4",
            secondaryHex: "908CAA"
        ),

        // Everforest - Green/Sage
        ColorTheme(
            id: "everforest",
            name: "Everforest",
            description: "Comfortable green",
            accentHex: "A7C080",
            backgroundTintHex: "83C092",
            highlightHex: "D3C6AA",
            secondaryHex: "859289"
        ),

        // Kanagawa - Japanese ink
        ColorTheme(
            id: "kanagawa",
            name: "Kanagawa",
            description: "Japanese wave",
            accentHex: "7E9CD8",
            backgroundTintHex: "957FB8",
            highlightHex: "DCD7BA",
            secondaryHex: "727169"
        )
    ]

    static var `default`: ColorTheme {
        themes.first!
    }

    static func theme(for id: String) -> ColorTheme {
        themes.first { $0.id == id } ?? .default
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
