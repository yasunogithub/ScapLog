//
//  ScapLogApp.swift
//  ScapLog
//
//  Created by 坂本泰明 on 2025/12/23.
//

import SwiftUI

@main
struct ScapLogApp: App {
    @State private var captureManager = CaptureManager.shared
    @State private var screenCapture = ScreenCaptureService.shared

    // Initialize hotkey manager
    private let hotkeyManager = HotkeyManager.shared

    init() {
        // Auto-start capturing on app launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            Task { @MainActor in
                // Check permission first
                await ScreenCaptureService.shared.checkPermission()
                if ScreenCaptureService.shared.isAuthorized && !CaptureManager.shared.isCapturing {
                    CaptureManager.shared.startCapturing()
                    print("[App] Auto-started capturing on launch")
                }
            }
        }
    }

    var body: some Scene {
        // Main window - single window app
        Window("Screen Summary", id: "main") {
            MainAppView()
        }
        .defaultSize(width: 900, height: 650)

        MenuBarExtra {
            MenuBarView()
        } label: {
            Label {
                Text("Screen Summary")
            } icon: {
                Image("MenuBarIcon")
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(.primary)
                    .frame(width: 18, height: 18)
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
