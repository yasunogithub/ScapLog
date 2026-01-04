//
//  AIService.swift
//  ScapLog
//

import Foundation

class AIService {
    static let shared = AIService()

    private init() {}

    func generateSummary(command: AICommand, imagePath: String, customPrompt: String? = nil) async throws -> String {
        let prompt = customPrompt?.isEmpty == false ? customPrompt : command.defaultPrompt
        let fullCommand = command.buildCommand(imagePath: imagePath, prompt: prompt)

        print("[AI] Executing command: \(fullCommand)")
        let result = try await executeShellCommand(fullCommand)
        print("[AI] Result length: \(result.count) chars")
        return result
    }

    private func executeShellCommand(_ command: String) async throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        // Use login shell to get proper PATH
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-c", command]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Set environment
        var env = ProcessInfo.processInfo.environment
        // Add common paths for CLI tools
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        if let path = env["PATH"] {
            env["PATH"] = "\(homePath)/.local/share/mise/shims:/opt/homebrew/bin:/usr/local/bin:\(path)"
        }
        // Ensure non-interactive mode for Gemini CLI
        env["TERM"] = "dumb"
        env["HOME"] = homePath  // Ensure HOME is set for config access
        env["XDG_CONFIG_HOME"] = "\(homePath)/.config"
        env["GEMINI_HOME"] = "\(homePath)/.gemini"  // Gemini config directory
        // Note: Don't set CI=true or NO_BROWSER=true as it may break auth
        process.environment = env

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            let resumeLock = NSLock()

            func safeResume(_ result: Result<String, Error>) {
                resumeLock.lock()
                defer { resumeLock.unlock() }
                guard !hasResumed else { return }
                hasResumed = true
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            // Create cancellable timeout work item
            var timeoutWorkItem: DispatchWorkItem?
            timeoutWorkItem = DispatchWorkItem { [weak process] in
                guard let process = process, process.isRunning else { return }
                print("[AI] Timeout - killing process")
                process.terminate()
                safeResume(.failure(AIServiceError.commandFailed("タイムアウト (120秒)")))
            }

            do {
                try process.run()
                print("[AI] Process started, waiting for completion...")

                // Schedule timeout after 120 seconds
                if let workItem = timeoutWorkItem {
                    DispatchQueue.global().asyncAfter(deadline: .now() + 120, execute: workItem)
                }

                process.terminationHandler = { [timeoutWorkItem] proc in
                    // Cancel the timeout when process terminates
                    timeoutWorkItem?.cancel()
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    print("[AI] Process terminated with code: \(proc.terminationStatus)")
                    print("[AI] Output length: \(output.count), Error length: \(errorOutput.count)")

                    if proc.terminationStatus == 0 {
                        // Filter out Gemini CLI noise
                        let cleanOutput = self.cleanGeminiOutput(output)
                        if cleanOutput.isEmpty {
                            // If output is empty after cleaning, check if there was an error
                            let cleanError = self.cleanErrorOutput(errorOutput)
                            if !cleanError.isEmpty {
                                safeResume(.failure(AIServiceError.commandFailed(cleanError)))
                            } else {
                                safeResume(.success("(出力なし)"))
                            }
                        } else {
                            safeResume(.success(cleanOutput))
                        }
                    } else {
                        let cleanError = self.cleanErrorOutput(errorOutput)
                        let errorMessage = cleanError.isEmpty ? "コマンドの実行に失敗しました (exit code: \(proc.terminationStatus))" : cleanError
                        safeResume(.failure(AIServiceError.commandFailed(errorMessage)))
                    }
                }
            } catch {
                safeResume(.failure(AIServiceError.executionFailed(error.localizedDescription)))
            }
        }
    }

    private nonisolated func cleanGeminiOutput(_ output: String) -> String {
        // Check for authentication errors first
        if output.contains("Authentication timed out") || output.contains("timed out after") {
            return ""  // Return empty so error handling kicks in
        }

        // Remove Gemini CLI noise lines
        let lines = output.components(separatedBy: "\n")
        let filteredLines = lines.filter { line in
            !line.hasPrefix("YOLO mode") &&
            !line.hasPrefix("Session cleanup") &&
            !line.hasPrefix("Loaded cached") &&
            !line.hasPrefix("`") && !line.hasSuffix("` の内容を確認します。") &&
            !line.contains("[STARTUP]") &&
            !line.contains("Recording metric") &&
            !line.contains("Authentication timed out")
        }
        return filteredLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private nonisolated func cleanErrorOutput(_ error: String) -> String {
        // Make error messages more user-friendly
        if error.contains("Authentication timed out") {
            return "Gemini認証エラー: ターミナルで 'gemini hello' を実行して認証してください"
        }
        if error.contains("not found") || error.contains("command not found") {
            return "コマンドが見つかりません。AIツールがインストールされているか確認してください"
        }
        // Remove noise from error messages
        let lines = error.components(separatedBy: "\n")
        let filteredLines = lines.filter { line in
            !line.hasPrefix("YOLO mode") &&
            !line.hasPrefix("Session cleanup") &&
            !line.contains("[STARTUP]") &&
            !line.contains("Recording metric")
        }
        return filteredLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum AIServiceError: LocalizedError {
        case commandFailed(String)
        case executionFailed(String)

        var errorDescription: String? {
            switch self {
            case .commandFailed(let message):
                return "コマンド実行エラー: \(message)"
            case .executionFailed(let message):
                return "実行エラー: \(message)"
            }
        }
    }
}
