//
//  MenuBarView.swift
//  ScapLog
//
//  Simplified Menu Bar

import SwiftUI
import Observation

struct MenuBarView: View {
    @State private var captureManager = CaptureManager.shared
    @State private var screenCapture = ScreenCaptureService.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status header
            HStack {
                Circle()
                    .fill(captureManager.isCapturing ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)

                Text(captureManager.isCapturing ? "キャプチャ中" : "停止中")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if captureManager.captureCount > 0 {
                    Text("\(captureManager.captureCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Permission warning
            if !screenCapture.isAuthorized {
                Button {
                    screenCapture.requestPermission()
                } label: {
                    Label("権限を許可", systemImage: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()
            }

            // Main actions
            VStack(spacing: 0) {
                if captureManager.isCapturing {
                    MenuButton(title: "停止", icon: "stop.fill", color: .orange) {
                        captureManager.stopCapturing()
                    }
                } else {
                    MenuButton(title: "開始", icon: "play.fill", color: .green) {
                        captureManager.startCapturing()
                    }
                    .disabled(!screenCapture.isAuthorized)
                }

                MenuButton(title: "今すぐキャプチャ", icon: "camera") {
                    Task { await captureManager.performCapture() }
                }
                .disabled(!screenCapture.isAuthorized)
            }

            Divider()

            // Navigation
            VStack(spacing: 0) {
                MenuButton(title: "履歴を開く", icon: "clock") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }

                SettingsLink {
                    HStack {
                        Image(systemName: "gear")
                            .frame(width: 16)
                        Text("設定...")
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Quit
            MenuButton(title: "終了", icon: "xmark.circle", color: .secondary) {
                NSApplication.shared.terminate(nil)
            }
        }
        .frame(width: 200)
    }
}

// MARK: - Simple Menu Button

private struct MenuButton: View {
    let title: String
    let icon: String
    var color: Color = .primary
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 16)
                Text(title)
                    .foregroundColor(color)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
