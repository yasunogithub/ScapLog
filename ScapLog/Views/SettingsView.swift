//
//  SettingsView.swift
//  ScapLog
//
//  Liquid Glass Design

import SwiftUI
import Observation
import Carbon.HIToolbox

struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    @State private var editingCommand: AICommand?
    @State private var showingAddCommand = false

    // Data management
    @State private var screenshotCount: Int = 0
    @State private var screenshotSize: String = "計算中..."
    @State private var screenshotBytes: Int64 = 0
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var deleteOlderThan: Int = 7 // days
    @State private var oldDataCount: Int = 0
    @State private var oldDataSize: String = "0 MB"

    // Export
    @State private var exportStartDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var exportEndDate: Date = Date()
    @State private var exportFormat: ExportFormat = .markdown
    @State private var exportEntryCount: Int = 0
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var showExportError = false
    @State private var activePreset: Int? = 7

    // Excluded apps
    @State private var showingAppPicker = false
    @State private var runningApps: [RunningAppInfo] = []

    // Privacy filter
    @State private var newExcludeKeyword = ""
    @State private var newMaskKeyword = ""
    @State private var detectedProfiles: [BrowserProfile] = []
    @State private var isLoadingProfiles = false

    // Screenshot folder
    @State private var showingFolderPicker = false

    // Hotkey recording
    @State private var isRecordingHotkey = false

    // MARK: - Section Builders (to reduce type-check complexity)

    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Text("設定")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            Button("閉じる") {
                dismiss()
            }
            .buttonStyle(LiquidGlassButtonStyle())
        }
        .padding()
        .liquidGlassHeader()
    }

    @ViewBuilder
    private var captureSettingsSection: some View {
        LiquidGlassGroupBox(title: "キャプチャ設定", icon: "camera") {
            VStack(alignment: .leading, spacing: 14) {
                captureIntervalView
                Divider().opacity(0.2)
                captureModeView
                Divider().opacity(0.2)
                skipPrivateBrowsingView
                Divider().opacity(0.2)
                pauseCaptureDuringSleepView
                Divider().opacity(0.2)
                captureEffectView
                Divider().opacity(0.2)
                captureSoundView
            }
        }
    }

    @ViewBuilder
    private var captureIntervalView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("間隔")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(settings.colorTheme.secondary)
            Picker("間隔", selection: $settings.captureInterval) {
                Text("30秒").tag(30.0)
                Text("1分").tag(60.0)
                Text("2分").tag(120.0)
                Text("5分").tag(300.0)
                Text("10分").tag(600.0)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var captureModeView: some View {
        Toggle(isOn: $settings.captureFrontmostWindowOnly) {
            VStack(alignment: .leading, spacing: 3) {
                Text("最前面のウィンドウのみ")
                    .fontWeight(.medium)
                Text("オフにすると画面全体をキャプチャ")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)
            }
        }
        .toggleStyle(.switch)
        .tint(settings.colorTheme.accent)
    }

    @ViewBuilder
    private var skipPrivateBrowsingView: some View {
        Toggle(isOn: $settings.skipPrivateBrowsing) {
            VStack(alignment: .leading, spacing: 3) {
                Text("プライベートブラウズ時はスキップ")
                    .fontWeight(.medium)
                Text("シークレットモード/プライベートウィンドウを検出してキャプチャをスキップ")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)
            }
        }
        .toggleStyle(.switch)
        .tint(settings.colorTheme.accent)
    }

    @ViewBuilder
    private var pauseCaptureDuringSleepView: some View {
        Toggle(isOn: $settings.pauseCaptureDuringSleep) {
            VStack(alignment: .leading, spacing: 3) {
                Text("スリープ中は一時停止")
                    .fontWeight(.medium)
                Text("Macがスリープ状態の間はキャプチャを停止")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)
            }
        }
        .toggleStyle(.switch)
        .tint(settings.colorTheme.accent)
    }

    @ViewBuilder
    private var captureEffectView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("キャプチャエフェクト")
                    .fontWeight(.medium)
                Spacer()
                Text(settings.captureEffectType.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(settings.colorTheme.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(CaptureEffectType.allCases) { effectType in
                    EffectTypeButton(
                        effectType: effectType,
                        isSelected: settings.captureEffectType == effectType
                    ) {
                        settings.captureEffectType = effectType
                        FeedbackService.shared.previewEffect(effectType)
                    }
                }
            }

            Text(settings.captureEffectType.description)
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)
        }
    }

    @ViewBuilder
    private var captureSoundView: some View {
        Toggle(isOn: $settings.captureSoundEnabled) {
            VStack(alignment: .leading, spacing: 3) {
                Text("キャプチャサウンド")
                    .fontWeight(.medium)
                Text("キャプチャ時に効果音を再生")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)
            }
        }
        .toggleStyle(.switch)
        .tint(settings.colorTheme.accent)

        if settings.captureSoundEnabled {
            VStack(alignment: .leading, spacing: 8) {
                Text("サウンドタイプ")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(CaptureSoundType.allCases) { soundType in
                        SoundTypeButton(
                            soundType: soundType,
                            isSelected: settings.captureSoundType == soundType
                        ) {
                            settings.captureSoundType = soundType
                            FeedbackService.shared.previewSound(soundType)
                        }
                    }
                }
            }
            .padding(.leading, 4)

            // Volume slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("音量")
                        .font(.caption)
                        .foregroundColor(settings.colorTheme.secondary)
                    Spacer()
                    Text("\(settings.captureSoundVolume)%")
                        .font(.caption)
                        .foregroundColor(settings.colorTheme.secondary)
                }

                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill")
                        .font(.caption)
                        .foregroundColor(settings.colorTheme.secondary)

                    Slider(
                        value: Binding(
                            get: { Double(settings.captureSoundVolume) },
                            set: { settings.captureSoundVolume = Int($0) }
                        ),
                        in: 0...100,
                        step: 1
                    )
                    .tint(settings.colorTheme.accent)

                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption)
                        .foregroundColor(settings.colorTheme.secondary)
                }

                Text("システムの音量とは独立して設定されます")
                    .font(.caption2)
                    .foregroundColor(settings.colorTheme.secondary.opacity(0.7))
            }
            .padding(.leading, 4)
        }
    }

    @ViewBuilder
    private var generalSettingsSection: some View {
        LiquidGlassGroupBox(title: "一般", icon: "gearshape") {
            VStack(alignment: .leading, spacing: 14) {
                launchAtLoginView
                Divider().opacity(0.2)
                globalHotkeyView
                Divider().opacity(0.2)
                windowOpacityView
            }
        }
    }

    @ViewBuilder
    private var launchAtLoginView: some View {
        Toggle(isOn: $settings.launchAtLogin) {
            VStack(alignment: .leading, spacing: 3) {
                Text("ログイン時に起動")
                    .fontWeight(.medium)
                Text("Macにログインしたとき自動的に起動")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)
            }
        }
        .toggleStyle(.switch)
        .tint(settings.colorTheme.accent)
    }

    @ViewBuilder
    private var globalHotkeyView: some View {
        Toggle(isOn: $settings.globalHotkeyEnabled) {
            VStack(alignment: .leading, spacing: 3) {
                Text("グローバルホットキー")
                    .fontWeight(.medium)
                Text("どこからでもキャプチャを実行")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)
            }
        }
        .toggleStyle(.switch)
        .tint(settings.colorTheme.accent)

        if settings.globalHotkeyEnabled {
            HStack {
                Text("ショートカット:")
                    .font(.subheadline)
                    .foregroundColor(settings.colorTheme.secondary)

                Button(action: {
                    isRecordingHotkey = true
                }) {
                    Text(isRecordingHotkey ? "キーを押してください..." : HotkeyManager.currentHotkeyString())
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(isRecordingHotkey ? settings.colorTheme.accent : settings.colorTheme.highlight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .liquidGlassCard(cornerRadius: LiquidGlass.radiusTiny)
                        .overlay(
                            RoundedRectangle(cornerRadius: LiquidGlass.radiusTiny)
                                .stroke(isRecordingHotkey ? settings.colorTheme.accent : Color.clear, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)

                if !isRecordingHotkey {
                    Button(action: {
                        isRecordingHotkey = true
                    }) {
                        Image(systemName: "keyboard")
                            .foregroundColor(settings.colorTheme.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("クリックしてホットキーを変更")
                }

                Spacer()
            }
            .padding(.leading, 4)
            .background(
                HotkeyRecorderView(isRecording: $isRecordingHotkey) { keyCode, modifiers in
                    settings.hotkeyKeyCode = keyCode
                    settings.hotkeyModifiers = modifiers
                    NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                }
            )
        }
    }

    @ViewBuilder
    private var windowOpacityView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ウィンドウ透明度")
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(settings.windowOpacity * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(settings.colorTheme.secondary)
                    .monospacedDigit()
            }
            Slider(value: $settings.windowOpacity, in: 0.1...1.0, step: 0.05)
                .tint(settings.colorTheme.accent)
            Text("ウィンドウの背景透明度を調整")
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)
        }
    }

    @ViewBuilder
    private var appearanceSettingsSection: some View {
        LiquidGlassGroupBox(title: "外観設定", icon: "paintbrush") {
            VStack(alignment: .leading, spacing: 14) {
                colorThemeView
                Divider().opacity(0.2)
                materialTypeView
                Divider().opacity(0.2)
                overlayOpacityView
                Divider().opacity(0.2)
                borderOpacityView
                Divider().opacity(0.2)
                shadowOpacityView
                Divider().opacity(0.2)
                highlightOpacityView
                Divider().opacity(0.2)
                resetAppearanceButton
            }
        }
    }

    @ViewBuilder
    private var colorThemeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("カラーテーマ")
                    .fontWeight(.medium)
                Spacer()
                Text(settings.colorTheme.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(settings.colorTheme.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(ColorTheme.themes) { theme in
                    ThemePreviewButton(
                        theme: theme,
                        isSelected: settings.colorThemeId == theme.id
                    ) {
                        settings.colorThemeId = theme.id
                    }
                }
            }

            Text(settings.colorTheme.description)
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)
        }
    }

    @ViewBuilder
    private var materialTypeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ブラー強度")
                    .fontWeight(.medium)
                Spacer()
                Text(settings.glassMaterialName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(settings.colorTheme.secondary)
            }
            Picker("マテリアル", selection: $settings.glassMaterialIndex) {
                Text("Ultra Thin").tag(0)
                Text("Thin").tag(1)
                Text("Regular").tag(2)
                Text("Thick").tag(3)
            }
            .pickerStyle(.segmented)
            Text("背景のぼかし強度を調整")
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)
        }
    }

    @ViewBuilder
    private var overlayOpacityView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("オーバーレイ")
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(settings.glassOverlayOpacity * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(settings.colorTheme.secondary)
                    .monospacedDigit()
            }
            Slider(value: $settings.glassOverlayOpacity, in: 0.0...0.3, step: 0.01)
                .tint(settings.colorTheme.accent)
            Text("グラデーション光沢の強さ")
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)
        }
    }

    @ViewBuilder
    private var borderOpacityView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ボーダー")
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(settings.glassBorderOpacity * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(settings.colorTheme.secondary)
                    .monospacedDigit()
            }
            Slider(value: $settings.glassBorderOpacity, in: 0.0...0.5, step: 0.01)
                .tint(settings.colorTheme.accent)
            Text("ガラス風ボーダーの濃さ")
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)
        }
    }

    @ViewBuilder
    private var shadowOpacityView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("シャドウ")
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(settings.glassShadowOpacity * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(settings.colorTheme.secondary)
                    .monospacedDigit()
            }
            Slider(value: $settings.glassShadowOpacity, in: 0.0...0.5, step: 0.01)
                .tint(settings.colorTheme.accent)
            Text("ドロップシャドウの濃さ")
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)
        }
    }

    @ViewBuilder
    private var highlightOpacityView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ハイライト")
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(settings.glassHighlightOpacity * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(settings.colorTheme.secondary)
                    .monospacedDigit()
            }
            Slider(value: $settings.glassHighlightOpacity, in: 0.0...1.0, step: 0.01)
                .tint(settings.colorTheme.accent)
            Text("上部ハイライトラインの強さ")
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)
        }
    }

    @ViewBuilder
    private var resetAppearanceButton: some View {
        HStack {
            Spacer()
            Button("デフォルトに戻す") {
                withAnimation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping)) {
                    settings.resetAppearanceToDefaults()
                }
            }
            .buttonStyle(LiquidGlassButtonStyle())
        }
    }

    @ViewBuilder
    private var excludedAppsSection: some View {
        LiquidGlassGroupBox(title: "除外アプリ", icon: "xmark.app") {
            VStack(alignment: .leading, spacing: 10) {
                Text("以下のアプリがアクティブの時はキャプチャしません")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)

                if settings.excludedApps.isEmpty {
                    Text("なし")
                        .font(.subheadline)
                        .foregroundColor(settings.colorTheme.secondary.opacity(0.7))
                        .padding(.vertical, 4)
                } else {
                    ForEach(settings.excludedApps, id: \.self) { bundleId in
                        excludedAppRow(bundleId: bundleId)
                    }
                }

                Button {
                    loadRunningApps()
                    showingAppPicker = true
                } label: {
                    Label("アプリを追加", systemImage: "plus")
                }
                .buttonStyle(LiquidGlassButtonStyle())
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func excludedAppRow(bundleId: String) -> some View {
        HStack {
            Text(appNameFromBundleId(bundleId))
                .font(.subheadline)
                .fontWeight(.medium)
            Spacer()
            Text(bundleId)
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)
            Button {
                withAnimation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping)) {
                    settings.excludedApps.removeAll { $0 == bundleId }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(settings.colorTheme.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Privacy Filter Section

    @ViewBuilder
    private var privacyFilterSection: some View {
        LiquidGlassGroupBox(title: "プライバシーフィルタ", icon: "eye.slash") {
            VStack(alignment: .leading, spacing: 16) {
                // Foreground-only toggle
                excludeOnlyWhenForegroundView

                Divider()

                // Exclude keywords
                excludeKeywordsView

                Divider()

                // Mask keywords
                maskKeywordsView

                Divider()

                // Browser profiles
                browserProfilesView
            }
        }
    }

    @ViewBuilder
    private var excludeOnlyWhenForegroundView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $settings.excludeOnlyWhenForeground) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("最前面のときのみ除外")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(settings.excludeOnlyWhenForeground
                         ? "除外対象が最前面のときだけスキップ"
                         : "除外対象がバックグラウンドで実行中でもスキップ")
                        .font(.caption)
                        .foregroundColor(settings.colorTheme.secondary)
                }
            }
            .toggleStyle(.switch)
            .disabled(settings.captureFrontmostWindowOnly)

            if settings.captureFrontmostWindowOnly {
                Text("「最前面のウィンドウのみ」有効時は使用できません")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }

    @ViewBuilder
    private var excludeKeywordsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("除外キーワード")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("ウィンドウタイトルに含まれていたらキャプチャしません")
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)

            if settings.excludeKeywords.isEmpty {
                Text("なし")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary.opacity(0.7))
                    .padding(.vertical, 2)
            } else {
                ForEach(settings.excludeKeywords, id: \.self) { keyword in
                    keywordRow(keyword: keyword, type: .exclude)
                }
            }

            HStack {
                TextField("キーワードを入力", text: $newExcludeKeyword)
                    .textFieldStyle(.plain)
                    .padding(6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(LiquidGlass.radiusTiny)

                Button {
                    addExcludeKeyword()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(newExcludeKeyword.isEmpty)
            }
        }
    }

    @ViewBuilder
    private var maskKeywordsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("マスクキーワード")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("ウィンドウタイトルに含まれていたらサマリーをマスクします")
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)

            if settings.maskKeywords.isEmpty {
                Text("なし")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary.opacity(0.7))
                    .padding(.vertical, 2)
            } else {
                ForEach(settings.maskKeywords, id: \.self) { keyword in
                    keywordRow(keyword: keyword, type: .mask)
                }
            }

            HStack {
                TextField("キーワードを入力", text: $newMaskKeyword)
                    .textFieldStyle(.plain)
                    .padding(6)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(LiquidGlass.radiusTiny)

                Button {
                    addMaskKeyword()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .disabled(newMaskKeyword.isEmpty)
            }
        }
    }

    private enum KeywordType {
        case exclude, mask
    }

    @ViewBuilder
    private func keywordRow(keyword: String, type: KeywordType) -> some View {
        HStack {
            Image(systemName: type == .exclude ? "xmark.circle" : "eye.slash")
                .foregroundColor(type == .exclude ? .orange : .purple)
                .frame(width: 16)
            Text(keyword)
                .font(.subheadline)
            Spacer()
            Button {
                removeKeyword(keyword, type: type)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(settings.colorTheme.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var browserProfilesView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("除外ブラウザプロファイル")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    loadBrowserProfiles()
                } label: {
                    if isLoadingProfiles {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .disabled(isLoadingProfiles)
            }

            Text("選択したプロファイルがアクティブの時はキャプチャしません")
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)

            if detectedProfiles.isEmpty {
                Text("プロファイルを検出するには更新ボタンを押してください")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary.opacity(0.7))
                    .padding(.vertical, 4)
            } else {
                ForEach(BrowserType.allCases) { browserType in
                    let browserProfiles = detectedProfiles.filter { $0.browser == browserType }
                    if !browserProfiles.isEmpty {
                        browserProfileGroup(browser: browserType, profiles: browserProfiles)
                    }
                }
            }
        }
        .onAppear {
            if detectedProfiles.isEmpty {
                // Delay profile loading to improve app startup time
                Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
                    await MainActor.run {
                        loadBrowserProfiles()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func browserProfileGroup(browser: BrowserType, profiles: [BrowserProfile]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(browser.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(settings.colorTheme.secondary)
                .padding(.top, 4)

            ForEach(profiles) { profile in
                Toggle(isOn: Binding(
                    get: { settings.excludedProfiles.contains(profile.id) },
                    set: { isExcluded in
                        if isExcluded {
                            if !settings.excludedProfiles.contains(profile.id) {
                                settings.excludedProfiles.append(profile.id)
                            }
                        } else {
                            settings.excludedProfiles.removeAll { $0 == profile.id }
                        }
                    }
                )) {
                    Text(profile.name)
                        .font(.subheadline)
                }
                .toggleStyle(.checkbox)
            }
        }
    }

    // MARK: - Privacy Filter Actions

    private func addExcludeKeyword() {
        let keyword = newExcludeKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        guard !settings.excludeKeywords.contains(keyword) else {
            newExcludeKeyword = ""
            return
        }
        settings.excludeKeywords.append(keyword)
        newExcludeKeyword = ""
    }

    private func addMaskKeyword() {
        let keyword = newMaskKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }
        guard !settings.maskKeywords.contains(keyword) else {
            newMaskKeyword = ""
            return
        }
        settings.maskKeywords.append(keyword)
        newMaskKeyword = ""
    }

    private func removeKeyword(_ keyword: String, type: KeywordType) {
        switch type {
        case .exclude:
            settings.excludeKeywords.removeAll { $0 == keyword }
        case .mask:
            settings.maskKeywords.removeAll { $0 == keyword }
        }
    }

    private func loadBrowserProfiles() {
        isLoadingProfiles = true
        DispatchQueue.global(qos: .userInitiated).async {
            let profiles = BrowserProfileService.shared.detectAllProfiles()
            DispatchQueue.main.async {
                self.detectedProfiles = profiles
                self.isLoadingProfiles = false
            }
        }
    }

    @ViewBuilder
    private var aiCommandsSection: some View {
        LiquidGlassGroupBox(title: "AIコマンド", icon: "cpu") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(settings.aiCommands) { command in
                    LiquidSettingsCommandRow(
                        command: command,
                        isSelected: settings.selectedCommandId == command.id,
                        onSelect: {
                            settings.selectedCommandId = command.id
                        },
                        onEdit: {
                            editingCommand = command
                        },
                        onDelete: !AICommand.presets.contains(where: { $0.name == command.name }) ? {
                            withAnimation(.spring(response: LiquidGlass.springResponse, dampingFraction: LiquidGlass.springDamping)) {
                                settings.aiCommands.removeAll { $0.id == command.id }
                            }
                        } : nil
                    )

                    if command.id != settings.aiCommands.last?.id {
                        Divider().opacity(0.2)
                    }
                }

                Button {
                    showingAddCommand = true
                } label: {
                    Label("コマンドを追加", systemImage: "plus")
                }
                .buttonStyle(LiquidGlassButtonStyle())
                .padding(.top, 8)
            }
        }
    }

    @ViewBuilder
    private var customPromptSection: some View {
        LiquidGlassGroupBox(title: "カスタムプロンプト", icon: "text.bubble") {
            VStack(alignment: .leading, spacing: 10) {
                Text("空欄の場合はコマンドのデフォルトプロンプトを使用")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)

                TextEditor(text: $settings.customPrompt)
                    .frame(height: 80)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                            .fill(Color.black.opacity(0.15))
                            .overlay {
                                RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                            }
                    }
            }
        }
    }

    @ViewBuilder
    private var dataLocationSection: some View {
        LiquidGlassGroupBox(title: "データ保存先", icon: "folder") {
            VStack(alignment: .leading, spacing: 14) {
                screenshotFolderView
                Divider().opacity(0.2)
                autoDeleteView
                Divider().opacity(0.2)
                screenshotFormatView
                if settings.screenshotFormat == .jpeg {
                    jpegQualityView
                }
            }
        }
    }

    @ViewBuilder
    private var screenshotFolderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("スクリーンショット保存先")
                .font(.subheadline)
                .fontWeight(.medium)

            Text(settings.customScreenshotsPath ?? AppSettings.screenshotsDirectory.path)
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .liquidGlassCard(cornerRadius: LiquidGlass.radiusTiny)

            HStack {
                Button("フォルダを選択") {
                    selectScreenshotFolder()
                }
                .buttonStyle(LiquidGlassButtonStyle())

                if settings.customScreenshotsPath != nil {
                    Button("デフォルトに戻す") {
                        settings.customScreenshotsPath = nil
                    }
                    .buttonStyle(LiquidGlassButtonStyle())
                }

                Spacer()

                Button("Finderで開く") {
                    NSWorkspace.shared.open(AppSettings.screenshotsDirectory)
                }
                .buttonStyle(LiquidGlassButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var autoDeleteView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("自動削除")
                .font(.subheadline)
                .fontWeight(.medium)

            Picker("保持期間", selection: $settings.autoDeleteDays) {
                Text("無効").tag(0)
                Text("7日").tag(7)
                Text("14日").tag(14)
                Text("30日").tag(30)
                Text("90日").tag(90)
            }
            .pickerStyle(.segmented)

            if settings.autoDeleteDays > 0 {
                Text("\(settings.autoDeleteDays)日より古いデータを自動削除します")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)
            }
        }
    }

    @ViewBuilder
    private var screenshotFormatView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("保存形式")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(settings.screenshotFormat.displayName)
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)
            }

            HStack(spacing: 8) {
                ForEach(ScreenshotFormat.allCases) { format in
                    Button {
                        settings.screenshotFormat = format
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: format == .png ? "photo" : "photo.fill")
                                .font(.title3)
                            Text(format.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(settings.screenshotFormat == format ? settings.colorTheme.accent.opacity(0.2) : Color.black.opacity(0.2))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(settings.screenshotFormat == format ? settings.colorTheme.accent : Color.white.opacity(0.1), lineWidth: settings.screenshotFormat == format ? 2 : 0.5)
                                }
                        }
                        .foregroundColor(settings.screenshotFormat == format ? settings.colorTheme.accent : settings.colorTheme.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(settings.screenshotFormat.description)
                .font(.caption)
                .foregroundColor(settings.colorTheme.secondary)
        }
    }

    @ViewBuilder
    private var jpegQualityView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("JPEG品質")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(settings.jpegQuality * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(settings.colorTheme.secondary)
                    .monospacedDigit()
            }
            Slider(value: $settings.jpegQuality, in: 0.5...1.0, step: 0.05)
                .tint(settings.colorTheme.accent)
            HStack {
                Text("小サイズ")
                    .font(.caption2)
                    .foregroundColor(settings.colorTheme.secondary)
                Spacer()
                Text("高品質")
                    .font(.caption2)
                    .foregroundColor(settings.colorTheme.secondary)
            }

            Divider()
                .padding(.vertical, 4)

            Toggle(isOn: $settings.analyzeAsPngThenConvert) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PNGで解析してから変換")
                        .font(.subheadline)
                    Text("高画質なPNGでAI解析し、保存時に選択形式へ変換します")
                        .font(.caption)
                        .foregroundColor(settings.colorTheme.secondary)
                }
            }
            .toggleStyle(.switch)
            .tint(settings.colorTheme.accent)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private var dataManagementSection: some View {
        LiquidGlassGroupBox(title: "データ管理", icon: "externaldrive") {
            VStack(alignment: .leading, spacing: 16) {
                StorageGaugeView(
                    screenshotCount: screenshotCount,
                    screenshotSize: screenshotSize,
                    screenshotBytes: screenshotBytes
                )

                Divider().opacity(0.2)

                DataCleanupView(
                    deleteOlderThan: $deleteOlderThan,
                    oldDataCount: oldDataCount,
                    oldDataSize: oldDataSize,
                    isDeleting: isDeleting,
                    onDelete: {
                        showDeleteConfirmation = true
                    },
                    onPreviewChange: { days in
                        calculateOldDataStats(days: days)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var exportSection: some View {
        LiquidGlassGroupBox(title: "データエクスポート", icon: "square.and.arrow.up") {
            VStack(alignment: .leading, spacing: 16) {
                exportDateRangeView
                Divider().opacity(0.2)
                exportFormatView
                Divider().opacity(0.2)
                exportPreviewAndButtonView
            }
        }
    }

    @ViewBuilder
    private var exportDateRangeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(settings.colorTheme.secondary)
                Text("期間を選択")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("開始日")
                        .font(.caption)
                        .foregroundColor(settings.colorTheme.secondary)
                    DatePicker("", selection: $exportStartDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .onChange(of: exportStartDate) { _, _ in
                            updateExportPreview()
                        }
                }

                Image(systemName: "arrow.right")
                    .foregroundColor(settings.colorTheme.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("終了日")
                        .font(.caption)
                        .foregroundColor(settings.colorTheme.secondary)
                    DatePicker("", selection: $exportEndDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .onChange(of: exportEndDate) { _, _ in
                            updateExportPreview()
                        }
                }
            }

            exportDatePresetsView
        }
    }

    @ViewBuilder
    private var exportDatePresetsView: some View {
        HStack(spacing: 6) {
            ForEach([7, 14, 30, 90], id: \.self) { days in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        exportStartDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                        exportEndDate = Date()
                        activePreset = days
                    }
                    updateExportPreviewWithoutClearingPreset()
                } label: {
                    Text(days == 90 ? "3ヶ月" : "\(days)日")
                        .font(.caption)
                        .fontWeight(activePreset == days ? .semibold : .regular)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(activePreset == days ? settings.colorTheme.accent.opacity(0.2) : Color.black.opacity(0.2))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(activePreset == days ? settings.colorTheme.accent : Color.white.opacity(0.1), lineWidth: activePreset == days ? 1.5 : 0.5)
                                }
                        }
                        .foregroundColor(activePreset == days ? settings.colorTheme.accent : settings.colorTheme.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var exportFormatView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("形式")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(exportFormat.rawValue.uppercased())
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)
            }

            HStack(spacing: 8) {
                ForEach(ExportFormat.allCases, id: \.self) { format in
                    ExportFormatButton(
                        format: format,
                        isSelected: exportFormat == format
                    ) {
                        exportFormat = format
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var exportPreviewAndButtonView: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .foregroundColor(settings.colorTheme.accent)
                    Text("\(exportEntryCount)件")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                Text("エクスポート対象")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)
            }

            Spacer()

            Button {
                performExport()
            } label: {
                HStack(spacing: 6) {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(isExporting ? "処理中..." : "エクスポート")
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }
            .buttonStyle(LiquidGlassButtonStyle(isProminent: true))
            .disabled(isExporting || exportEntryCount == 0)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(settings.colorTheme.accent.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(settings.colorTheme.accent.opacity(0.3), lineWidth: 1)
                }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    captureSettingsSection
                    generalSettingsSection
                    appearanceSettingsSection
                    excludedAppsSection
                    privacyFilterSection
                    aiCommandsSection
                    customPromptSection
                    dataLocationSection
                    dataManagementSection
                    exportSection
                }
                .padding()
            }
        }
        .frame(width: 500, height: 900)
        .background {
            ZStack {
                LiquidGlassBackground()
                LiquidGlassVisualEffect(material: .sidebar)
            }
        }
        .onAppear {
            // Delay heavy calculations to improve app startup time
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
                await MainActor.run {
                    calculateScreenshotStats()
                    updateExportPreview()
                }
            }
        }
        .alert("確認", isPresented: $showDeleteConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                deleteOldData()
            }
        } message: {
            Text("\(deleteOlderThan)日より古いスクリーンショットとサマリーを削除しますか？この操作は取り消せません。")
        }
        .alert("エクスポートエラー", isPresented: $showExportError) {
            Button("OK") { }
        } message: {
            Text(exportError ?? "不明なエラーが発生しました")
        }
        .sheet(item: $editingCommand) { command in
            LiquidCommandEditView(command: command) { updatedCommand in
                if let index = settings.aiCommands.firstIndex(where: { $0.id == command.id }) {
                    settings.aiCommands[index] = updatedCommand
                }
            }
        }
        .sheet(isPresented: $showingAddCommand) {
            LiquidCommandEditView(command: AICommand(name: "", template: "", defaultPrompt: "", isEnabled: true)) { newCommand in
                settings.aiCommands.append(newCommand)
            }
        }
        .sheet(isPresented: $showingAppPicker) {
            LiquidAppPickerSheet(apps: runningApps, excludedApps: settings.excludedApps) { bundleId in
                if !settings.excludedApps.contains(bundleId) {
                    settings.excludedApps.append(bundleId)
                }
            }
        }
    }

    // MARK: - Data Management

    private func calculateScreenshotStats() {
        Task {
            let screenshotsDir = AppSettings.applicationSupportDirectory.appendingPathComponent("screenshots")
            let fm = FileManager.default

            guard fm.fileExists(atPath: screenshotsDir.path) else {
                await MainActor.run {
                    screenshotCount = 0
                    screenshotSize = "0 MB"
                    screenshotBytes = 0
                }
                return
            }

            var count = 0
            var totalSize: Int64 = 0

            // Collect files synchronously to avoid async iterator issues
            let files = collectScreenshotFiles(in: screenshotsDir)
            for fileURL in files {
                count += 1
                if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                   let size = attrs[.size] as? Int64 {
                    totalSize += size
                }
            }

            let sizeString = formatBytes(totalSize)

            await MainActor.run {
                screenshotCount = count
                screenshotSize = sizeString
                screenshotBytes = totalSize
                // Initial old data calculation
                calculateOldDataStats(days: deleteOlderThan)
            }
        }
    }

    private func collectScreenshotFiles(in directory: URL) -> [URL] {
        let fm = FileManager.default
        var result: [URL] = []
        let validExtensions = ["png", "jpeg", "jpg"]
        if let enumerator = fm.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles]) {
            while let fileURL = enumerator.nextObject() as? URL {
                if validExtensions.contains(fileURL.pathExtension.lowercased()) {
                    result.append(fileURL)
                }
            }
        }
        return result
    }

    private func calculateOldDataStats(days: Int) {
        Task {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
            let screenshotsDir = AppSettings.applicationSupportDirectory.appendingPathComponent("screenshots")
            let fm = FileManager.default

            guard fm.fileExists(atPath: screenshotsDir.path) else {
                await MainActor.run {
                    oldDataCount = 0
                    oldDataSize = "0 MB"
                }
                return
            }

            var count = 0
            var totalSize: Int64 = 0

            let files = collectScreenshotFiles(in: screenshotsDir)
            for fileURL in files {
                if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attrs[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    count += 1
                    if let size = attrs[.size] as? Int64 {
                        totalSize += size
                    }
                }
            }

            let sizeString = formatBytes(totalSize)

            await MainActor.run {
                oldDataCount = count
                oldDataSize = sizeString
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Export Functions

    /// Normalized date range with proper start-of-day and end-of-day handling
    private var normalizedDateRange: (start: Date, end: Date) {
        let startOfDay = Calendar.current.startOfDay(for: exportStartDate)
        guard let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: exportEndDate) else {
            // Fallback: use start of next day
            let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: exportEndDate) ?? exportEndDate
            return (startOfDay, Calendar.current.startOfDay(for: nextDay))
        }
        return (startOfDay, endOfDay)
    }

    private func updateExportPreview() {
        // Clear preset if dates were manually changed
        activePreset = nil
        updateExportPreviewWithoutClearingPreset()
    }

    private func updateExportPreviewWithoutClearingPreset() {
        Task {
            let range = normalizedDateRange

            // Validate date range
            guard range.start <= range.end else {
                await MainActor.run {
                    exportEntryCount = 0
                }
                return
            }

            do {
                let summaries = try await DatabaseService.shared.fetchSummariesInRangeAsync(from: range.start, to: range.end)
                await MainActor.run {
                    exportEntryCount = summaries.count
                }
            } catch {
                print("[Export] Preview error: \(error)")
                await MainActor.run {
                    exportEntryCount = 0
                }
            }
        }
    }

    private func performExport() {
        isExporting = true
        exportError = nil

        Task {
            let range = normalizedDateRange

            // Validate date range
            guard range.start <= range.end else {
                await MainActor.run {
                    exportError = "開始日は終了日より前に設定してください"
                    showExportError = true
                    isExporting = false
                }
                return
            }

            do {
                let summaries = try await DatabaseService.shared.fetchSummariesInRangeAsync(from: range.start, to: range.end)

                // Check for empty results
                guard !summaries.isEmpty else {
                    await MainActor.run {
                        exportError = "選択した期間にデータがありません"
                        showExportError = true
                        isExporting = false
                    }
                    return
                }

                let content: String
                switch exportFormat {
                case .markdown:
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy/MM/dd"
                    let title = "Screen Summary (\(dateFormatter.string(from: exportStartDate)) - \(dateFormatter.string(from: exportEndDate)))"
                    content = ExportService.shared.exportToMarkdown(summaries: summaries, title: title)
                case .json:
                    content = ExportService.shared.exportToJSON(summaries: summaries)
                case .csv:
                    content = ExportService.shared.exportToCSV(summaries: summaries)
                case .text:
                    content = ExportService.shared.exportToText(summaries: summaries)
                }

                let finalContent = content
                let finalFormat = exportFormat

                await MainActor.run {
                    isExporting = false
                }

                // Show save panel after updating UI state
                await MainActor.run {
                    do {
                        try ExportService.shared.saveToFile(content: finalContent, format: finalFormat)
                    } catch {
                        exportError = "ファイル保存に失敗しました: \(error.localizedDescription)"
                        showExportError = true
                    }
                }
            } catch {
                print("[Export] Error: \(error)")
                await MainActor.run {
                    exportError = "エクスポートに失敗しました: \(error.localizedDescription)"
                    showExportError = true
                    isExporting = false
                }
            }
        }
    }

    private func deleteOldData() {
        isDeleting = true

        Task {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -deleteOlderThan, to: Date()) ?? Date()
            let fm = FileManager.default
            let screenshotsDir = AppSettings.applicationSupportDirectory.appendingPathComponent("screenshots")

            var deletedCount = 0

            // Delete old screenshots
            let files = collectScreenshotFiles(in: screenshotsDir)
            for fileURL in files {
                if let attrs = try? fm.attributesOfItem(atPath: fileURL.path),
                   let creationDate = attrs[.creationDate] as? Date,
                   creationDate < cutoffDate {
                    try? fm.removeItem(at: fileURL)
                    deletedCount += 1
                }
            }

            // Delete old summaries from database
            try? DatabaseService.shared.deleteOldSummaries(olderThan: cutoffDate)

            print("[Settings] Deleted \(deletedCount) old screenshots")

            await MainActor.run {
                isDeleting = false
                calculateScreenshotStats()
            }
        }
    }

    // MARK: - Excluded Apps

    private func loadRunningApps() {
        let workspace = NSWorkspace.shared
        runningApps = workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningAppInfo? in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return RunningAppInfo(name: name, bundleId: bundleId, icon: app.icon)
            }
            .sorted { $0.name < $1.name }
    }

    private func appNameFromBundleId(_ bundleId: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: url),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return bundleId.components(separatedBy: ".").last ?? bundleId
    }

    // MARK: - Folder Selection

    private func selectScreenshotFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "スクリーンショットの保存先を選択してください"
        panel.prompt = "選択"

        if panel.runModal() == .OK, let url = panel.url {
            settings.customScreenshotsPath = url.path
        }
    }
}

// MARK: - Running App Info

struct RunningAppInfo: Identifiable {
    let id = UUID()
    let name: String
    let bundleId: String
    let icon: NSImage?
}

// MARK: - Liquid App Picker Sheet

struct LiquidAppPickerSheet: View {
    let apps: [RunningAppInfo]
    let excludedApps: [String]
    let onSelect: (String) -> Void
    @Environment(\.dismiss) var dismiss
    private var settings: AppSettings { AppSettings.shared }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("アプリを選択")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("閉じる") { dismiss() }
                    .buttonStyle(LiquidGlassButtonStyle())
            }
            .padding()
            .liquidGlassHeader()

            List(apps) { app in
                Button {
                    onSelect(app.bundleId)
                    dismiss()
                } label: {
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name)
                                .fontWeight(.medium)
                            Text(app.bundleId)
                                .font(.caption)
                                .foregroundColor(settings.colorTheme.secondary)
                        }
                        Spacer()
                        if excludedApps.contains(app.bundleId) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [settings.colorTheme.accent, settings.colorTheme.accent.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
            .scrollContentBackground(.hidden)
        }
        .frame(width: 400, height: 400)
        .background {
            ZStack {
                LiquidGlassBackground()
                LiquidGlassVisualEffect(material: .sidebar)
            }
        }
    }
}

// MARK: - Liquid Settings Command Row

struct LiquidSettingsCommandRow: View {
    let command: AICommand
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    var onDelete: (() -> Void)?

    @State private var isHovered = false
    private var settings: AppSettings { AppSettings.shared }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(
                            isSelected ?
                            AnyShapeStyle(
                                LinearGradient(
                                    colors: [settings.colorTheme.accent, settings.colorTheme.accent.opacity(0.7)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            ) : AnyShapeStyle(Color.gray)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(command.name)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)

                        Text(command.isOCR ? "macOS内蔵OCR" : command.template)
                            .font(.caption)
                            .foregroundColor(settings.colorTheme.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.body)
                    .foregroundColor(settings.colorTheme.secondary)
            }
            .buttonStyle(LiquidGlassIconButtonStyle(size: 28))
            .opacity(isHovered ? 1 : 0.7)

            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundColor(.red)
                }
                .buttonStyle(LiquidGlassIconButtonStyle(size: 28))
                .opacity(isHovered ? 1 : 0.7)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background {
            RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
                .overlay {
                    if isHovered {
                        RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    }
                }
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Liquid Command Edit View

struct LiquidCommandEditView: View {
    @State var command: AICommand
    var onSave: (AICommand) -> Void

    @Environment(\.dismiss) var dismiss
    private var settings: AppSettings { AppSettings.shared }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(command.name.isEmpty ? "新しいコマンド" : command.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button("キャンセル") {
                    dismiss()
                }
                .buttonStyle(LiquidGlassButtonStyle())

                Button("保存") {
                    onSave(command)
                    dismiss()
                }
                .buttonStyle(LiquidGlassButtonStyle(isProminent: true))
                .disabled(command.name.isEmpty || command.template.isEmpty)
            }
            .padding()
            .liquidGlassHeader()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 10) {
                        Text("名前")
                            .font(.headline)
                            .fontWeight(.semibold)
                        TextField("コマンド名", text: $command.name)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .liquidGlassSearchField()
                    }

                    // Template
                    VStack(alignment: .leading, spacing: 10) {
                        Text("コマンドテンプレート")
                            .font(.headline)
                            .fontWeight(.semibold)
                        TextEditor(text: $command.template)
                            .frame(height: 80)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background {
                                RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                                    .fill(Color.black.opacity(0.15))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                                    }
                            }

                        Text("プレースホルダー: {image_path}, {prompt}")
                            .font(.caption)
                            .foregroundColor(settings.colorTheme.secondary)
                    }

                    // Default Prompt
                    VStack(alignment: .leading, spacing: 10) {
                        Text("デフォルトプロンプト")
                            .font(.headline)
                            .fontWeight(.semibold)
                        TextEditor(text: $command.defaultPrompt)
                            .frame(height: 100)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background {
                                RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                                    .fill(Color.black.opacity(0.15))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: LiquidGlass.radiusSmall)
                                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                                    }
                            }
                    }
                }
                .padding()
            }
        }
        .frame(width: 480, height: 450)
        .background {
            ZStack {
                LiquidGlassBackground()
                LiquidGlassVisualEffect(material: .sidebar)
            }
        }
    }
}

// MARK: - Storage Gauge View

struct StorageGaugeView: View {
    let screenshotCount: Int
    let screenshotSize: String
    let screenshotBytes: Int64

    private var settings: AppSettings { AppSettings.shared }

    // Assume 1GB as reference max for visual gauge
    private let referenceMax: Int64 = 1_073_741_824

    private var usagePercent: Double {
        min(Double(screenshotBytes) / Double(referenceMax), 1.0)
    }

    private var usageColor: Color {
        if usagePercent < 0.5 {
            return .green
        } else if usagePercent < 0.8 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Main stats
            HStack(spacing: 20) {
                // Screenshot count with icon
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(settings.colorTheme.accent.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: "photo.stack")
                            .font(.title2)
                            .foregroundColor(settings.colorTheme.accent)
                    }
                    Text("\(screenshotCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("枚")
                        .font(.caption)
                        .foregroundColor(settings.colorTheme.secondary)
                }
                .frame(maxWidth: .infinity)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 1, height: 60)

                // Storage size with icon
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(usageColor.opacity(0.15))
                            .frame(width: 50, height: 50)
                        Image(systemName: "externaldrive")
                            .font(.title2)
                            .foregroundColor(usageColor)
                    }
                    Text(screenshotSize)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("使用中")
                        .font(.caption)
                        .foregroundColor(settings.colorTheme.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)

            // Storage bar
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.3))

                        // Usage bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [usageColor.opacity(0.8), usageColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * usagePercent)
                            .animation(.spring(response: 0.5), value: usagePercent)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("0 MB")
                        .font(.caption2)
                        .foregroundColor(settings.colorTheme.secondary)
                    Spacer()
                    Text("1 GB")
                        .font(.caption2)
                        .foregroundColor(settings.colorTheme.secondary)
                }
            }
        }
        .padding(14)
        .liquidGlassCard(cornerRadius: LiquidGlass.radiusSmall)
    }
}

// MARK: - Data Cleanup View

struct DataCleanupView: View {
    @Binding var deleteOlderThan: Int
    let oldDataCount: Int
    let oldDataSize: String
    let isDeleting: Bool
    let onDelete: () -> Void
    let onPreviewChange: (Int) -> Void

    private let dayOptions = [7, 14, 30, 60, 90]
    private var settings: AppSettings { AppSettings.shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "trash.circle")
                    .font(.title3)
                    .foregroundColor(.orange)
                Text("データクリーンアップ")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }

            // Day selector with slider feel
            VStack(alignment: .leading, spacing: 8) {
                Text("削除対象: \(deleteOlderThan)日より古いデータ")
                    .font(.caption)
                    .foregroundColor(settings.colorTheme.secondary)

                HStack(spacing: 6) {
                    ForEach(dayOptions, id: \.self) { days in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                deleteOlderThan = days
                            }
                            onPreviewChange(days)
                        } label: {
                            Text("\(days)日")
                                .font(.caption)
                                .fontWeight(deleteOlderThan == days ? .bold : .regular)
                                .foregroundColor(deleteOlderThan == days ? .white : settings.colorTheme.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background {
                                    if deleteOlderThan == days {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.orange)
                                    } else {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.black.opacity(0.2))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
                                            }
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Preview of what will be deleted
            if oldDataCount > 0 {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(oldDataCount)枚 (\(oldDataSize))")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("削除対象のスクリーンショット")
                            .font(.caption)
                            .foregroundColor(settings.colorTheme.secondary)
                    }

                    Spacer()

                    Button {
                        onDelete()
                    } label: {
                        HStack(spacing: 6) {
                            if isDeleting {
                                ProgressView()
                                    .scaleEffect(0.6)
                            } else {
                                Image(systemName: "trash")
                            }
                            Text(isDeleting ? "削除中..." : "削除")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                    }
                    .buttonStyle(LiquidGlassButtonStyle(isProminent: true, color: .red))
                    .disabled(isDeleting)
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.orange.opacity(0.1))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                        }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Text("削除対象のデータはありません")
                        .font(.subheadline)
                        .foregroundColor(settings.colorTheme.secondary)

                    Spacer()
                }
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.green.opacity(0.1))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                        }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
}

// MARK: - Effect Type Button

struct EffectTypeButton: View {
    let effectType: CaptureEffectType
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    private var settings: AppSettings { AppSettings.shared }
    private var theme: ColorTheme { settings.colorTheme }

    private var iconName: String {
        switch effectType {
        case .none: return "circle.slash"
        case .borderGlow: return "square.dashed"
        case .flash: return "bolt.fill"
        case .vignette: return "circle.circle"
        case .shrink: return "arrow.down.right.and.arrow.up.left"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .frame(width: 36, height: 36)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        isSelected ? theme.accent : Color.white.opacity(isHovered ? 0.2 : 0.1),
                                        lineWidth: isSelected ? 2 : 0.5
                                    )
                            }
                    }
                    .foregroundColor(isSelected ? theme.accent : theme.secondary)

                Text(effectType.displayName)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? theme.accent : theme.secondary)
                    .lineLimit(1)
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}


// MARK: - Sound Type Button

struct SoundTypeButton: View {
    let soundType: CaptureSoundType
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    private var settings: AppSettings { AppSettings.shared }
    private var theme: ColorTheme { settings.colorTheme }

    private var iconName: String {
        switch soundType {
        case .tink: return "bell"
        case .glass: return "wineglass"
        case .pop: return "bubble.left.fill"
        case .purr: return "waveform"
        case .ping: return "bell.badge"
        case .shutter: return "camera.shutter.button"
        case .softClick: return "hand.tap"
        case .macChime: return "desktopcomputer"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 14))
                    .frame(width: 32, height: 32)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        isSelected ? theme.accent : Color.white.opacity(isHovered ? 0.2 : 0.1),
                                        lineWidth: isSelected ? 2 : 0.5
                                    )
                            }
                    }
                    .foregroundColor(isSelected ? theme.accent : theme.secondary)

                Text(soundType.displayName)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? theme.accent : theme.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Theme Preview Button

struct ThemePreviewButton: View {
    let theme: ColorTheme
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    private var settings: AppSettings { AppSettings.shared }
    private var currentTheme: ColorTheme { settings.colorTheme }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                // Color preview circles
                HStack(spacing: 3) {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(theme.backgroundTint)
                        .frame(width: 12, height: 12)
                }
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.3))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    isSelected ? theme.accent : Color.white.opacity(isHovered ? 0.2 : 0.1),
                                    lineWidth: isSelected ? 2 : 0.5
                                )
                        }
                }

                // Theme name
                Text(theme.name)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? theme.accent : currentTheme.secondary)
                    .lineLimit(1)
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Export Format Button

struct ExportFormatButton: View {
    let format: ExportFormat
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false
    private var settings: AppSettings { AppSettings.shared }

    private var iconName: String {
        switch format {
        case .markdown: return "doc.richtext"
        case .json: return "curlybraces"
        case .csv: return "tablecells"
        case .text: return "doc.plaintext"
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .frame(width: 44, height: 36)
                    .background {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.3))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(
                                        isSelected ? settings.colorTheme.accent : Color.white.opacity(isHovered ? 0.2 : 0.1),
                                        lineWidth: isSelected ? 2 : 0.5
                                    )
                            }
                    }
                    .foregroundColor(isSelected ? settings.colorTheme.accent : settings.colorTheme.secondary)

                Text(format.rawValue)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? settings.colorTheme.accent : settings.colorTheme.secondary)
                    .lineLimit(1)
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Hotkey Recorder View

/// A view that captures keyboard events for hotkey recording
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onKeyRecorded: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.onKeyRecorded = { [self] keyCode, modifiers in
            onKeyRecorded(keyCode, modifiers)
            DispatchQueue.main.async {
                isRecording = false
            }
        }
        view.onCancel = {
            DispatchQueue.main.async {
                isRecording = false
            }
        }
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        if isRecording {
            nsView.startRecording()
        } else {
            nsView.stopRecording()
        }
    }
}

/// Custom NSView for capturing keyboard events
class HotkeyRecorderNSView: NSView {
    var onKeyRecorded: ((UInt32, UInt32) -> Void)?
    var onCancel: (() -> Void)?
    private var localMonitor: Any?

    override var acceptsFirstResponder: Bool { true }

    func startRecording() {
        // Remove existing monitor
        stopRecording()

        // Add local event monitor for key events
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else { return event }

            // ESC to cancel
            if event.keyCode == 53 {
                self.onCancel?()
                return nil
            }

            // Get modifiers
            let modifiers = event.modifierFlags
            var carbonModifiers: UInt32 = 0

            if modifiers.contains(.command) { carbonModifiers |= UInt32(cmdKey) }
            if modifiers.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
            if modifiers.contains(.option) { carbonModifiers |= UInt32(optionKey) }
            if modifiers.contains(.control) { carbonModifiers |= UInt32(controlKey) }

            // Only accept if at least one modifier is pressed (for safety)
            if event.type == .keyDown && carbonModifiers != 0 {
                let keyCode = UInt32(event.keyCode)
                self.onKeyRecorded?(keyCode, carbonModifiers)
                return nil
            }

            return event
        }

        // Make this view first responder
        window?.makeFirstResponder(self)
    }

    func stopRecording() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    deinit {
        stopRecording()
    }
}

// MARK: - Legacy Compatibility

typealias AppPickerSheet = LiquidAppPickerSheet
typealias SettingsCommandRow = LiquidSettingsCommandRow
typealias CommandEditView = LiquidCommandEditView

#Preview {
    SettingsView()
}
