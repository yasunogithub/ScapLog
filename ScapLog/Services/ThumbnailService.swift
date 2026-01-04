//
//  ThumbnailService.swift
//  ScapLog
//
//  サムネイル生成・キャッシュサービス
//

import Foundation
import AppKit

class ThumbnailService {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSString, NSImage>()
    private let thumbnailSize = CGSize(width: 200, height: 120)
    private let queue = DispatchQueue(label: "thumbnail.generation", qos: .utility, attributes: .concurrent)

    private init() {
        cache.countLimit = 100 // Keep max 100 thumbnails in memory
    }

    /// Get thumbnail for screenshot path, generating if needed
    func getThumbnail(for path: String, completion: @escaping (NSImage?) -> Void) {
        let cacheKey = path as NSString

        // Check memory cache first
        if let cached = cache.object(forKey: cacheKey) {
            completion(cached)
            return
        }

        // Check disk cache
        if let diskCached = loadFromDiskCache(path: path) {
            cache.setObject(diskCached, forKey: cacheKey)
            completion(diskCached)
            return
        }

        // Generate thumbnail
        queue.async { [weak self] in
            guard let self = self else { return }

            guard let thumbnail = self.generateThumbnail(from: path) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            // Save to disk cache
            self.saveToDiskCache(thumbnail, path: path)

            // Update memory cache
            self.cache.setObject(thumbnail, forKey: cacheKey)

            DispatchQueue.main.async {
                completion(thumbnail)
            }
        }
    }

    /// Async version
    func getThumbnail(for path: String) async -> NSImage? {
        await withCheckedContinuation { continuation in
            getThumbnail(for: path) { image in
                continuation.resume(returning: image)
            }
        }
    }

    /// Generate thumbnail from image file
    private func generateThumbnail(from path: String) -> NSImage? {
        guard let image = NSImage(contentsOfFile: path) else {
            return nil
        }

        let originalSize = image.size
        guard originalSize.width > 0 && originalSize.height > 0 else {
            return nil
        }

        // Calculate aspect-fit size
        let widthRatio = thumbnailSize.width / originalSize.width
        let heightRatio = thumbnailSize.height / originalSize.height
        let scale = min(widthRatio, heightRatio)

        let newSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        // Create thumbnail
        let thumbnail = NSImage(size: newSize)
        thumbnail.lockFocus()

        NSGraphicsContext.current?.imageInterpolation = .high

        image.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )

        thumbnail.unlockFocus()

        return thumbnail
    }

    // MARK: - Disk Cache

    private var cacheDirectory: URL {
        let dir = AppSettings.applicationSupportDirectory.appendingPathComponent("thumbnails")
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private func diskCachePath(for originalPath: String) -> URL {
        let hash = originalPath.hashValue
        return cacheDirectory.appendingPathComponent("\(hash).jpg")
    }

    private func loadFromDiskCache(path: String) -> NSImage? {
        let cachePath = diskCachePath(for: path)
        guard FileManager.default.fileExists(atPath: cachePath.path) else {
            return nil
        }
        return NSImage(contentsOf: cachePath)
    }

    private func saveToDiskCache(_ image: NSImage, path: String) {
        let cachePath = diskCachePath(for: path)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
            return
        }

        try? jpegData.write(to: cachePath)
    }

    /// Clear all cached thumbnails
    func clearCache() {
        cache.removeAllObjects()

        let cacheDir = cacheDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    /// Preload thumbnails for a list of paths
    func preloadThumbnails(for paths: [String]) {
        for path in paths.prefix(20) { // Limit preloading
            getThumbnail(for: path) { _ in }
        }
    }
}
