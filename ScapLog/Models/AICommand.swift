//
//  AICommand.swift
//  ScapLog
//

import Foundation

struct AICommand: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var template: String
    var defaultPrompt: String
    var isEnabled: Bool

    // Special command name for built-in OCR
    static let ocrCommandName = "OCR (macOS内蔵)"

    static let presets: [AICommand] = [
        AICommand(
            name: ocrCommandName,
            template: "__OCR__",  // Special marker for OCR
            defaultPrompt: "",
            isEnabled: true
        ),
        AICommand(
            name: "Gemini",
            template: "cd \"{image_dir}\" && gemini \"{prompt} ファイル名: {image_name}\" -o text -y",
            defaultPrompt: "この画面のスクリーンショットを見て、ユーザーが何をしているか簡潔に日本語で要約してください。",
            isEnabled: true
        ),
        AICommand(
            name: "Claude (API)",
            template: "cat \"{image_path}\" | base64 | xargs -I {} claude -p \"{prompt}\" --no-session-persistence",
            defaultPrompt: "この画面のスクリーンショットを見て、ユーザーが何をしているか簡潔に日本語で要約してください。",
            isEnabled: false
        ),
        AICommand(
            name: "llm (GPT-4o)",
            template: "llm -m gpt-4o \"{prompt}\" -a \"{image_path}\"",
            defaultPrompt: "この画面のスクリーンショットを見て、ユーザーが何をしているか簡潔に日本語で要約してください。",
            isEnabled: false
        )
    ]

    var isOCR: Bool {
        return template == "__OCR__"
    }

    /// Escape a string for safe use in shell commands
    /// Uses single quotes and escapes any embedded single quotes
    private func shellEscape(_ string: String) -> String {
        // Replace single quotes with the sequence: end quote, escaped quote, start quote
        // 'foo'bar' becomes 'foo'\''bar'
        let escaped = string.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    func buildCommand(imagePath: String, prompt: String? = nil) -> String {
        let actualPrompt = prompt ?? defaultPrompt
        let url = URL(fileURLWithPath: imagePath)
        let imageDir = url.deletingLastPathComponent().path
        let imageName = url.lastPathComponent

        // Escape all user-controlled values to prevent command injection
        return template
            .replacingOccurrences(of: "\"{image_path}\"", with: shellEscape(imagePath))
            .replacingOccurrences(of: "{image_path}", with: shellEscape(imagePath))
            .replacingOccurrences(of: "\"{image_dir}\"", with: shellEscape(imageDir))
            .replacingOccurrences(of: "{image_dir}", with: shellEscape(imageDir))
            .replacingOccurrences(of: "\"{image_name}\"", with: shellEscape(imageName))
            .replacingOccurrences(of: "{image_name}", with: shellEscape(imageName))
            .replacingOccurrences(of: "\"{prompt}\"", with: shellEscape(actualPrompt))
            .replacingOccurrences(of: "{prompt}", with: shellEscape(actualPrompt))
    }
}
