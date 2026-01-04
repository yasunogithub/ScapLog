//
//  FeedbackService.swift
//  ScapLog
//
//  キャプチャ時の視覚フィードバック
//

import AppKit
import SwiftUI

@MainActor
class FeedbackService {
    static let shared = FeedbackService()

    private var feedbackWindows: [NSWindow] = []

    private init() {}

    /// Show capture effect based on settings
    func showCaptureFlash() {
        let effectType = AppSettings.shared.captureEffectType

        guard effectType != .none else {
            // Sound only if enabled
            if AppSettings.shared.captureSoundEnabled {
                playShutterSound()
            }
            return
        }

        // Show on all screens
        for screen in NSScreen.screens {
            showEffect(effectType, on: screen)
        }

        // Play sound if enabled
        if AppSettings.shared.captureSoundEnabled {
            playShutterSound()
        }
    }

    /// Preview a specific effect type (for settings)
    func previewEffect(_ effectType: CaptureEffectType) {
        guard effectType != .none else { return }

        // Show only on main screen for preview
        if let mainScreen = NSScreen.main {
            showEffect(effectType, on: mainScreen)
        }
    }

    /// Preview a sound type for settings (uses current volume setting)
    func previewSound(_ soundType: CaptureSoundType) {
        let volume = Float(AppSettings.shared.captureSoundVolume) / 100.0

        // システムサウンドの場合
        if let systemName = soundType.systemSoundName,
           let sound = NSSound(named: NSSound.Name(systemName)) {
            sound.volume = volume
            sound.play()
            return
        }

        // カスタムサウンドの場合
        if let fileName = soundType.customSoundFileName,
           let url = Bundle.main.url(forResource: fileName, withExtension: soundType.customSoundExtension),
           let sound = NSSound(contentsOf: url, byReference: true) {
            sound.volume = volume
            sound.play()
        }
    }

    private func showEffect(_ effectType: CaptureEffectType, on screen: NSScreen) {
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let contentView: NSHostingView<AnyView>

        switch effectType {
        case .none:
            return
        case .borderGlow:
            contentView = NSHostingView(rootView: AnyView(BorderGlowView()))
        case .flash:
            contentView = NSHostingView(rootView: AnyView(FlashView()))
        case .vignette:
            contentView = NSHostingView(rootView: AnyView(VignetteView()))
        case .shrink:
            contentView = NSHostingView(rootView: AnyView(ShrinkView()))
        }

        window.contentView = contentView

        feedbackWindows.append(window)
        window.orderFrontRegardless()

        // Duration based on effect type
        let duration: Double = effectType == .shrink ? 0.3 : 0.4

        // Fade out and remove
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                window.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                window.orderOut(nil)
                Task { @MainActor in
                    self?.feedbackWindows.removeAll { $0 == window }
                }
            })
        }
    }

    private func playShutterSound() {
        let soundType = AppSettings.shared.captureSoundType
        let volume = Float(AppSettings.shared.captureSoundVolume) / 100.0

        // システムサウンドの場合
        if let systemName = soundType.systemSoundName,
           let sound = NSSound(named: NSSound.Name(systemName)) {
            sound.volume = volume
            sound.play()
            return
        }

        // カスタムサウンドの場合
        if let fileName = soundType.customSoundFileName,
           let url = Bundle.main.url(forResource: fileName, withExtension: soundType.customSoundExtension),
           let sound = NSSound(contentsOf: url, byReference: true) {
            sound.volume = volume
            sound.play()
        }
    }
}

// MARK: - Border Glow View (Original)

struct BorderGlowView: View {
    @State private var animationPhase: CGFloat = 0

    private var theme: ColorTheme { AppSettings.shared.colorTheme }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Outer glow border
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                theme.accent.opacity(0.8),
                                theme.backgroundTint.opacity(0.6),
                                theme.secondary.opacity(0.4),
                                theme.backgroundTint.opacity(0.6),
                                theme.accent.opacity(0.8)
                            ]),
                            center: .center,
                            startAngle: .degrees(animationPhase),
                            endAngle: .degrees(animationPhase + 360)
                        ),
                        lineWidth: 4
                    )
                    .blur(radius: 8)

                // Sharp inner border
                RoundedRectangle(cornerRadius: 0)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                theme.accent.opacity(0.9),
                                theme.backgroundTint.opacity(0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )

                // Corner accents
                ForEach(Corner.allCases, id: \.self) { corner in
                    CornerAccent(corner: corner, color: theme.accent)
                        .frame(width: 60, height: 60)
                        .position(corner.position(in: geometry.size))
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 0.4)) {
                animationPhase = 90
            }
        }
    }
}

// MARK: - Flash View

struct FlashView: View {
    @State private var opacity: Double = 0

    var body: some View {
        Color.white
            .opacity(opacity)
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeOut(duration: 0.1)) {
                    opacity = 0.7
                }
                withAnimation(.easeIn(duration: 0.3).delay(0.1)) {
                    opacity = 0
                }
            }
    }
}

// MARK: - Vignette View

struct VignetteView: View {
    @State private var intensity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.clear,
                    Color.black.opacity(0.3 * intensity),
                    Color.black.opacity(0.7 * intensity)
                ]),
                center: .center,
                startRadius: min(geometry.size.width, geometry.size.height) * 0.3,
                endRadius: max(geometry.size.width, geometry.size.height) * 0.8
            )
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.15)) {
                intensity = 1.0
            }
            withAnimation(.easeIn(duration: 0.25).delay(0.15)) {
                intensity = 0
            }
        }
    }
}

// MARK: - Shrink View

struct ShrinkView: View {
    @State private var scale: CGFloat = 1.0
    @State private var borderOpacity: Double = 0

    private var theme: ColorTheme { AppSettings.shared.colorTheme }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark overlay
                Color.black
                    .opacity(0.15 * (1.0 - scale) * 20)

                // Shrinking border
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                theme.accent.opacity(0.8),
                                theme.backgroundTint.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .opacity(borderOpacity)
                    .scaleEffect(scale)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.15)) {
                scale = 0.97
                borderOpacity = 1.0
            }
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6).delay(0.15)) {
                scale = 1.0
                borderOpacity = 0
            }
        }
    }
}

// MARK: - Corner Accent

enum Corner: CaseIterable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    func position(in size: CGSize) -> CGPoint {
        switch self {
        case .topLeading: return CGPoint(x: 30, y: 30)
        case .topTrailing: return CGPoint(x: size.width - 30, y: 30)
        case .bottomLeading: return CGPoint(x: 30, y: size.height - 30)
        case .bottomTrailing: return CGPoint(x: size.width - 30, y: size.height - 30)
        }
    }
}

struct CornerAccent: View {
    let corner: Corner
    var color: Color = .cyan
    @State private var scale: CGFloat = 0.5
    @State private var opacity: CGFloat = 0

    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.6),
                            color.opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
                .scaleEffect(scale)

            // Core
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 8, height: 8)
                .scaleEffect(scale)
        }
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.2)) {
                scale = 1.2
                opacity = 1
            }
            withAnimation(.easeIn(duration: 0.2).delay(0.2)) {
                scale = 0.8
                opacity = 0.5
            }
        }
    }
}
