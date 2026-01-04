//
//  AppSettings.swift
//  ScapLog
//

import Foundation
import Observation
import ServiceManagement
import Carbon.HIToolbox

@Observable
class AppSettings {
    static let shared = AppSettings()

    /// Last error message for settings operations
    var lastSettingsError: String?

    var captureInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(captureInterval, forKey: "captureInterval")
        }
    }

    var selectedCommandId: UUID? {
        didSet {
            if let id = selectedCommandId {
                UserDefaults.standard.set(id.uuidString, forKey: "selectedCommandId")
            }
        }
    }

    var aiCommands: [AICommand] {
        didSet {
            if let data = try? JSONEncoder().encode(aiCommands) {
                UserDefaults.standard.set(data, forKey: "aiCommands")
            }
        }
    }

    var customPrompt: String {
        didSet {
            UserDefaults.standard.set(customPrompt, forKey: "customPrompt")
        }
    }

    /// 最前面のウィンドウのみをキャプチャするか（デフォルト: true）
    var captureFrontmostWindowOnly: Bool {
        didSet {
            UserDefaults.standard.set(captureFrontmostWindowOnly, forKey: "captureFrontmostWindowOnly")
        }
    }

    // MARK: - New Settings

    /// 除外するアプリのBundle ID一覧
    var excludedApps: [String] {
        didSet {
            UserDefaults.standard.set(excludedApps, forKey: "excludedApps")
        }
    }

    // MARK: - Privacy Filter Settings

    /// 除外キーワード（ウィンドウタイトルに含まれていたらキャプチャしない）
    var excludeKeywords: [String] {
        didSet {
            UserDefaults.standard.set(excludeKeywords, forKey: "excludeKeywords")
        }
    }

    /// マスクキーワード（ウィンドウタイトルに含まれていたらサマリーをマスク）
    var maskKeywords: [String] {
        didSet {
            UserDefaults.standard.set(maskKeywords, forKey: "maskKeywords")
        }
    }

    /// 除外するブラウザプロファイルID一覧（"browser:profileId" 形式）
    var excludedProfiles: [String] {
        didSet {
            UserDefaults.standard.set(excludedProfiles, forKey: "excludedProfiles")
        }
    }

    /// 最前面のときだけ除外する（false = バックグラウンドで実行中でも除外）
    var excludeOnlyWhenForeground: Bool {
        didSet {
            UserDefaults.standard.set(excludeOnlyWhenForeground, forKey: "excludeOnlyWhenForeground")
        }
    }

    /// ログイン時に自動起動
    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            updateLaunchAtLogin()
        }
    }

    /// 自動削除日数（0 = 無効）
    var autoDeleteDays: Int {
        didSet {
            UserDefaults.standard.set(autoDeleteDays, forKey: "autoDeleteDays")
        }
    }

    /// カスタムスクリーンショット保存先（nil = デフォルト）
    var customScreenshotsPath: String? {
        didSet {
            UserDefaults.standard.set(customScreenshotsPath, forKey: "customScreenshotsPath")
        }
    }

    /// スクリーンショット保存形式
    var screenshotFormat: ScreenshotFormat {
        didSet {
            UserDefaults.standard.set(screenshotFormat.rawValue, forKey: "screenshotFormat")
        }
    }

    /// JPEG品質 (0.5 - 1.0)
    var jpegQuality: Double {
        didSet {
            UserDefaults.standard.set(jpegQuality, forKey: "jpegQuality")
        }
    }

    /// PNGで解析してから保存形式に変換（高品質解析 + 省スペース保存）
    var analyzeAsPngThenConvert: Bool {
        didSet {
            UserDefaults.standard.set(analyzeAsPngThenConvert, forKey: "analyzeAsPngThenConvert")
        }
    }

    /// グローバルホットキー有効
    var globalHotkeyEnabled: Bool {
        didSet {
            UserDefaults.standard.set(globalHotkeyEnabled, forKey: "globalHotkeyEnabled")
            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
        }
    }

    /// ホットキー: キーコード (デフォルト: S = 1)
    var hotkeyKeyCode: UInt32 {
        didSet {
            UserDefaults.standard.set(hotkeyKeyCode, forKey: "hotkeyKeyCode")
            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
        }
    }

    /// ホットキー: モディファイア (デフォルト: Cmd+Shift)
    var hotkeyModifiers: UInt32 {
        didSet {
            UserDefaults.standard.set(hotkeyModifiers, forKey: "hotkeyModifiers")
            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
        }
    }

    /// ウィンドウ透明度 (0.1 - 1.0)
    var windowOpacity: Double {
        didSet {
            UserDefaults.standard.set(windowOpacity, forKey: "windowOpacity")
            NotificationCenter.default.post(name: .windowOpacityChanged, object: nil)
        }
    }

    /// プライベートブラウザ使用時にキャプチャをスキップ
    var skipPrivateBrowsing: Bool {
        didSet {
            UserDefaults.standard.set(skipPrivateBrowsing, forKey: "skipPrivateBrowsing")
        }
    }

    /// スリープ中はキャプチャを一時停止
    var pauseCaptureDuringSleep: Bool {
        didSet {
            UserDefaults.standard.set(pauseCaptureDuringSleep, forKey: "pauseCaptureDuringSleep")
        }
    }

    // MARK: - Appearance Settings (Liquid Glass)

    /// ガラスマテリアルの種類 (0=ultraThin, 1=thin, 2=regular, 3=thick)
    var glassMaterialIndex: Int {
        didSet {
            UserDefaults.standard.set(glassMaterialIndex, forKey: "glassMaterialIndex")
            NotificationCenter.default.post(name: .appearanceSettingsChanged, object: nil)
        }
    }

    /// オーバーレイの透明度 (0.0 - 0.5)
    var glassOverlayOpacity: Double {
        didSet {
            UserDefaults.standard.set(glassOverlayOpacity, forKey: "glassOverlayOpacity")
            NotificationCenter.default.post(name: .appearanceSettingsChanged, object: nil)
        }
    }

    /// ボーダーの透明度 (0.0 - 0.5)
    var glassBorderOpacity: Double {
        didSet {
            UserDefaults.standard.set(glassBorderOpacity, forKey: "glassBorderOpacity")
            NotificationCenter.default.post(name: .appearanceSettingsChanged, object: nil)
        }
    }

    /// シャドウの透明度 (0.0 - 0.5)
    var glassShadowOpacity: Double {
        didSet {
            UserDefaults.standard.set(glassShadowOpacity, forKey: "glassShadowOpacity")
            NotificationCenter.default.post(name: .appearanceSettingsChanged, object: nil)
        }
    }

    /// ハイライトの透明度 (0.0 - 1.0)
    var glassHighlightOpacity: Double {
        didSet {
            UserDefaults.standard.set(glassHighlightOpacity, forKey: "glassHighlightOpacity")
            NotificationCenter.default.post(name: .appearanceSettingsChanged, object: nil)
        }
    }

    // MARK: - Capture Feedback Settings

    /// キャプチャ時のエフェクトタイプ
    var captureEffectType: CaptureEffectType {
        didSet {
            UserDefaults.standard.set(captureEffectType.rawValue, forKey: "captureEffectType")
        }
    }

    /// キャプチャ時にサウンドを再生
    var captureSoundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(captureSoundEnabled, forKey: "captureSoundEnabled")
        }
    }

    var captureSoundType: CaptureSoundType {
        didSet {
            UserDefaults.standard.set(captureSoundType.rawValue, forKey: "captureSoundType")
        }
    }

    /// キャプチャサウンドの音量 (0-100、システム音量とは独立)
    var captureSoundVolume: Int {
        didSet {
            // Clamp value to 0-100
            let clampedValue = max(0, min(100, captureSoundVolume))
            if clampedValue != captureSoundVolume {
                captureSoundVolume = clampedValue
            }
            UserDefaults.standard.set(captureSoundVolume, forKey: "captureSoundVolume")
        }
    }

    /// 後方互換性のため (captureFlashEnabled -> captureEffectType)
    var captureFlashEnabled: Bool {
        get { captureEffectType != .none }
        set { captureEffectType = newValue ? .borderGlow : .none }
    }

    // MARK: - Color Theme Settings

    /// 選択されたカラーテーマID
    var colorThemeId: String {
        didSet {
            UserDefaults.standard.set(colorThemeId, forKey: "colorThemeId")
            NotificationCenter.default.post(name: .colorThemeChanged, object: nil)
        }
    }

    /// 現在のカラーテーマ
    var colorTheme: ColorTheme {
        ColorTheme.theme(for: colorThemeId)
    }

    var isCapturing: Bool = false

    /// Returns the selected command, or the first available command (OCR) as fallback
    var selectedCommand: AICommand? {
        if let id = selectedCommandId, let cmd = aiCommands.first(where: { $0.id == id }) {
            return cmd
        }
        // Fallback to first command (OCR)
        return aiCommands.first
    }

    private init() {
        // Initialize all stored properties first
        let interval = UserDefaults.standard.double(forKey: "captureInterval")
        self.captureInterval = interval > 0 ? interval : 60

        // Always use fresh presets to ensure OCR is available
        // User custom commands could be merged here if needed
        self.aiCommands = AICommand.presets

        self.customPrompt = UserDefaults.standard.string(forKey: "customPrompt") ?? ""

        // Default to frontmost window only (true)
        if UserDefaults.standard.object(forKey: "captureFrontmostWindowOnly") == nil {
            self.captureFrontmostWindowOnly = true
        } else {
            self.captureFrontmostWindowOnly = UserDefaults.standard.bool(forKey: "captureFrontmostWindowOnly")
        }

        // New settings initialization
        self.excludedApps = UserDefaults.standard.stringArray(forKey: "excludedApps") ?? []

        // Privacy filter settings
        self.excludeKeywords = UserDefaults.standard.stringArray(forKey: "excludeKeywords") ?? []

        // Default mask keywords for sensitive data
        let defaultMaskKeywords = [
            "password", "パスワード", "Password", "PASSWORD",
            "クレジット", "credit card", "Credit Card", "カード番号",
            "暗証番号", "PIN", "セキュリティコード", "CVV", "CVC",
            "口座番号", "銀行", "Bank",
            "社会保険", "マイナンバー", "個人番号",
            "ID", "ログイン", "Login", "signin", "サインイン"
        ]
        let storedMaskKeywords = UserDefaults.standard.stringArray(forKey: "maskKeywords")
        if storedMaskKeywords == nil {
            self.maskKeywords = defaultMaskKeywords
            UserDefaults.standard.set(defaultMaskKeywords, forKey: "maskKeywords")
        } else {
            self.maskKeywords = storedMaskKeywords!
        }

        self.excludedProfiles = UserDefaults.standard.stringArray(forKey: "excludedProfiles") ?? []

        // Exclude only when foreground (default: true = 最前面のときのみ除外)
        if UserDefaults.standard.object(forKey: "excludeOnlyWhenForeground") == nil {
            self.excludeOnlyWhenForeground = true
        } else {
            self.excludeOnlyWhenForeground = UserDefaults.standard.bool(forKey: "excludeOnlyWhenForeground")
        }

        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        self.autoDeleteDays = UserDefaults.standard.integer(forKey: "autoDeleteDays")
        self.customScreenshotsPath = UserDefaults.standard.string(forKey: "customScreenshotsPath")

        // Screenshot format settings
        if let formatRaw = UserDefaults.standard.string(forKey: "screenshotFormat"),
           let format = ScreenshotFormat(rawValue: formatRaw) {
            self.screenshotFormat = format
        } else {
            self.screenshotFormat = .jpeg  // Default to JPEG for smaller size
        }
        let storedQuality = UserDefaults.standard.double(forKey: "jpegQuality")
        self.jpegQuality = storedQuality > 0 ? storedQuality : 0.7  // Default 70% quality

        // Analyze as PNG then convert (default: true for best quality analysis)
        if UserDefaults.standard.object(forKey: "analyzeAsPngThenConvert") == nil {
            self.analyzeAsPngThenConvert = true
        } else {
            self.analyzeAsPngThenConvert = UserDefaults.standard.bool(forKey: "analyzeAsPngThenConvert")
        }

        self.globalHotkeyEnabled = UserDefaults.standard.object(forKey: "globalHotkeyEnabled") == nil ? true : UserDefaults.standard.bool(forKey: "globalHotkeyEnabled")

        // Hotkey key code initialization
        let storedKeyCode = UserDefaults.standard.integer(forKey: "hotkeyKeyCode")
        self.hotkeyKeyCode = storedKeyCode == 0 ? UInt32(kVK_ANSI_S) : UInt32(storedKeyCode)

        // Hotkey modifiers initialization
        let storedModifiers = UserDefaults.standard.integer(forKey: "hotkeyModifiers")
        self.hotkeyModifiers = storedModifiers == 0 ? UInt32(cmdKey | shiftKey) : UInt32(storedModifiers)

        // Window opacity initialization (default: 1.0 = fully opaque)
        let storedOpacity = UserDefaults.standard.double(forKey: "windowOpacity")
        self.windowOpacity = storedOpacity > 0 ? storedOpacity : 1.0

        // Skip private browsing (default: true)
        if UserDefaults.standard.object(forKey: "skipPrivateBrowsing") == nil {
            self.skipPrivateBrowsing = true
        } else {
            self.skipPrivateBrowsing = UserDefaults.standard.bool(forKey: "skipPrivateBrowsing")
        }

        // Pause capture during sleep (default: true)
        if UserDefaults.standard.object(forKey: "pauseCaptureDuringSleep") == nil {
            self.pauseCaptureDuringSleep = true
        } else {
            self.pauseCaptureDuringSleep = UserDefaults.standard.bool(forKey: "pauseCaptureDuringSleep")
        }

        // Appearance settings initialization
        self.glassMaterialIndex = UserDefaults.standard.object(forKey: "glassMaterialIndex") == nil
            ? 1 : UserDefaults.standard.integer(forKey: "glassMaterialIndex")  // Default: thin

        let storedOverlay = UserDefaults.standard.double(forKey: "glassOverlayOpacity")
        self.glassOverlayOpacity = storedOverlay > 0 ? storedOverlay : 0.08  // Default

        let storedBorder = UserDefaults.standard.double(forKey: "glassBorderOpacity")
        self.glassBorderOpacity = storedBorder > 0 ? storedBorder : 0.25  // Default

        let storedShadow = UserDefaults.standard.double(forKey: "glassShadowOpacity")
        self.glassShadowOpacity = storedShadow > 0 ? storedShadow : 0.15  // Default

        let storedHighlight = UserDefaults.standard.double(forKey: "glassHighlightOpacity")
        self.glassHighlightOpacity = storedHighlight > 0 ? storedHighlight : 0.4  // Default

        // Capture feedback settings
        // Migrate from old captureFlashEnabled to captureEffectType
        if let effectRaw = UserDefaults.standard.string(forKey: "captureEffectType"),
           let effectType = CaptureEffectType(rawValue: effectRaw) {
            self.captureEffectType = effectType
        } else if UserDefaults.standard.object(forKey: "captureFlashEnabled") != nil {
            // Migrate old setting
            self.captureEffectType = UserDefaults.standard.bool(forKey: "captureFlashEnabled") ? .borderGlow : .none
        } else {
            self.captureEffectType = .borderGlow  // Default
        }

        if UserDefaults.standard.object(forKey: "captureSoundEnabled") == nil {
            self.captureSoundEnabled = true
        } else {
            self.captureSoundEnabled = UserDefaults.standard.bool(forKey: "captureSoundEnabled")
        }

        // Capture sound type (default: tink)
        if let soundRaw = UserDefaults.standard.string(forKey: "captureSoundType"),
           let soundType = CaptureSoundType(rawValue: soundRaw) {
            self.captureSoundType = soundType
        } else {
            self.captureSoundType = .tink
        }

        // Capture sound volume (default: 50, range: 0-100)
        if UserDefaults.standard.object(forKey: "captureSoundVolume") != nil {
            self.captureSoundVolume = UserDefaults.standard.integer(forKey: "captureSoundVolume")
        } else {
            self.captureSoundVolume = 50
        }

        // Color theme (default: "default")
        self.colorThemeId = UserDefaults.standard.string(forKey: "colorThemeId") ?? "default"

        // Try to restore selected command, fallback to first (OCR)
        if let idString = UserDefaults.standard.string(forKey: "selectedCommandId"),
           let id = UUID(uuidString: idString),
           aiCommands.contains(where: { $0.id == id }) {
            self.selectedCommandId = id
        } else {
            // Default to OCR (first command)
            self.selectedCommandId = self.aiCommands.first?.id
        }
    }

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            // Clear any previous error on success
            lastSettingsError = nil
        } catch {
            print("[Settings] Failed to update launch at login: \(error)")
            lastSettingsError = "ログイン時起動の設定に失敗しました: \(error.localizedDescription)"
            // Restore the previous value to reflect actual state
            let previousValue = !launchAtLogin
            UserDefaults.standard.set(previousValue, forKey: "launchAtLogin")
            // Use DispatchQueue to avoid recursive didSet
            DispatchQueue.main.async { [weak self] in
                self?.launchAtLogin = previousValue
            }
        }
    }

    static var applicationSupportDirectory: URL {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("ScreenSummary")

        if !fm.fileExists(atPath: appDir.path) {
            try? fm.createDirectory(at: appDir, withIntermediateDirectories: true)
        }

        return appDir
    }

    static var databasePath: URL {
        applicationSupportDirectory.appendingPathComponent("summaries.duckdb")
    }

    static var screenshotsDirectory: URL {
        let fm = FileManager.default

        // Use custom path if set
        if let customPath = shared.customScreenshotsPath,
           !customPath.isEmpty {
            let customURL = URL(fileURLWithPath: customPath)
            if !fm.fileExists(atPath: customURL.path) {
                try? fm.createDirectory(at: customURL, withIntermediateDirectories: true)
            }
            return customURL
        }

        // Default path
        let dir = applicationSupportDirectory.appendingPathComponent("screenshots")
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// Check if an app should be excluded from capture
    func isAppExcluded(bundleId: String?) -> Bool {
        guard let bundleId = bundleId else { return false }
        return excludedApps.contains(bundleId)
    }

    /// マテリアル名を取得
    var glassMaterialName: String {
        switch glassMaterialIndex {
        case 0: return "Ultra Thin"
        case 1: return "Thin"
        case 2: return "Regular"
        case 3: return "Thick"
        default: return "Thin"
        }
    }

    /// 外観設定をデフォルトに戻す
    func resetAppearanceToDefaults() {
        glassMaterialIndex = 1
        glassOverlayOpacity = 0.08
        glassBorderOpacity = 0.25
        glassShadowOpacity = 0.15
        glassHighlightOpacity = 0.4
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let hotkeySettingsChanged = Notification.Name("hotkeySettingsChanged")
    static let performCapture = Notification.Name("performCapture")
    static let windowOpacityChanged = Notification.Name("windowOpacityChanged")
    static let appearanceSettingsChanged = Notification.Name("appearanceSettingsChanged")
    static let colorThemeChanged = Notification.Name("colorThemeChanged")
}

// MARK: - Screenshot Format

enum ScreenshotFormat: String, CaseIterable, Identifiable {
    case png = "png"
    case jpeg = "jpeg"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .png: return "PNG"
        case .jpeg: return "JPEG"
        }
    }

    var fileExtension: String { rawValue }

    var description: String {
        switch self {
        case .png: return "高品質・ロスレス（サイズ大）"
        case .jpeg: return "圧縮・軽量（サイズ小）"
        }
    }
}

// MARK: - Capture Effect Type

enum CaptureEffectType: String, CaseIterable, Identifiable {
    case none = "none"
    case borderGlow = "borderGlow"
    case flash = "flash"
    case vignette = "vignette"
    case shrink = "shrink"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "なし"
        case .borderGlow: return "ボーダーグロー"
        case .flash: return "フラッシュ"
        case .vignette: return "ビネット"
        case .shrink: return "シュリンク"
        }
    }

    var description: String {
        switch self {
        case .none: return "エフェクトなし"
        case .borderGlow: return "画面の縁がシアン色に光る"
        case .flash: return "画面全体が白くフラッシュ"
        case .vignette: return "画面の周囲が暗くなる"
        case .shrink: return "画面が一瞬縮む"
        }
    }
}


// MARK: - Capture Sound Type

enum CaptureSoundType: String, CaseIterable, Identifiable {
    case tink = "tink"
    case glass = "glass"
    case pop = "pop"
    case purr = "purr"
    case ping = "ping"
    case shutter = "shutter"       // カスタム: カメラシャッター風
    case softClick = "softClick"   // カスタム: 柔らかいクリック音
    case macChime = "macChime"     // カスタム: Mac起動音風

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tink: return "Tink"
        case .glass: return "Glass"
        case .pop: return "Pop"
        case .purr: return "Purr"
        case .ping: return "Ping"
        case .shutter: return "シャッター"
        case .softClick: return "ソフトクリック"
        case .macChime: return "Macチャイム"
        }
    }

    var description: String {
        switch self {
        case .tink: return "軽やかな金属音（デフォルト）"
        case .glass: return "グラスを鳴らすような音"
        case .pop: return "ポップな弾ける音"
        case .purr: return "穏やかな振動音"
        case .ping: return "高めのベル音"
        case .shutter: return "カメラのシャッター風"
        case .softClick: return "柔らかいクリック音"
        case .macChime: return "懐かしのMac起動音"
        }
    }

    /// システムサウンド名（nilの場合はカスタムサウンド）
    var systemSoundName: String? {
        switch self {
        case .tink: return "Tink"
        case .glass: return "Glass"
        case .pop: return "Pop"
        case .purr: return "Purr"
        case .ping: return "Ping"
        case .shutter, .softClick, .macChime: return nil
        }
    }

    /// カスタムサウンドのファイル名（拡張子なし）
    var customSoundFileName: String? {
        switch self {
        case .shutter: return "shutter"
        case .softClick: return "soft_click"
        case .macChime: return "mac_chime"
        default: return nil
        }
    }

    /// カスタムサウンドの拡張子
    var customSoundExtension: String {
        return "wav"
    }
}
