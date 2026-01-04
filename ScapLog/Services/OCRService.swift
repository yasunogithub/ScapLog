//
//  OCRService.swift
//  ScapLog
//
//  macOS Vision framework を使用したOCR
//

import Foundation
import Vision
import AppKit

class OCRService {
    static let shared = OCRService()

    private init() {}

    /// 画像からテキストを抽出
    func extractText(from imagePath: String) async throws -> String {
        guard let image = NSImage(contentsOfFile: imagePath) else {
            throw OCRError.imageLoadFailed
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageConversionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: text)
            }

            // 設定
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja", "en"]  // 日本語と英語
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.recognitionFailed(error.localizedDescription))
            }
        }
    }

    /// OCRテキストから簡易サマリを生成
    func generateSummary(from imagePath: String) async throws -> String {
        let text = try await extractText(from: imagePath)

        if text.isEmpty {
            return "(テキストが検出されませんでした)"
        }

        // テキストを整形してサマリとして返す
        let lines = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // 最大20行まで
        let limitedLines = Array(lines.prefix(20))
        let summary = limitedLines.joined(separator: "\n")

        // 長すぎる場合は切り詰め
        if summary.count > 1000 {
            return String(summary.prefix(1000)) + "..."
        }

        return summary
    }

    enum OCRError: LocalizedError {
        case imageLoadFailed
        case imageConversionFailed
        case recognitionFailed(String)

        var errorDescription: String? {
            switch self {
            case .imageLoadFailed:
                return "画像の読み込みに失敗しました"
            case .imageConversionFailed:
                return "画像の変換に失敗しました"
            case .recognitionFailed(let message):
                return "OCRエラー: \(message)"
            }
        }
    }
}
