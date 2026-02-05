import SwiftUI
import AppKit

// MARK: - Image Cache
// Singleton NSCache for product thumbnail images.
// NSCache automatically evicts under memory pressure (Apple best practice).

final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 300
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func image(for key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: NSImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

// MARK: - CachedAsyncImage
// Drop-in replacement for AsyncImage that caches loaded images in NSCache.
// Prevents re-fetching on every scroll reuse — the #1 cause of list lag.

struct CachedAsyncImage: View {
    let url: URL?
    let size: CGFloat

    @State private var image: NSImage?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .quaternaryLabelColor))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear { loadImage() }
        .onDisappear { loadTask?.cancel() }
        .onChange(of: url) { _, _ in loadImage() }
    }

    private func loadImage() {
        guard let url else {
            image = nil
            return
        }

        let key = url.absoluteString

        // Check cache first (synchronous, no network)
        if let cached = ImageCache.shared.image(for: key) {
            image = cached
            return
        }

        // Load in background
        loadTask?.cancel()
        loadTask = Task.detached(priority: .utility) {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                if let nsImage = NSImage(data: data) {
                    // Downscale to target size for memory efficiency
                    let scaled = nsImage.resized(to: NSSize(width: size * 2, height: size * 2))
                    ImageCache.shared.set(scaled, for: key)
                    await MainActor.run {
                        image = scaled
                    }
                }
            } catch {
                // Silently fail — placeholder stays visible
            }
        }
    }
}

// MARK: - NSImage Resize Helper

private extension NSImage {
    func resized(to targetSize: NSSize) -> NSImage {
        let newImage = NSImage(size: targetSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: targetSize),
             from: NSRect(origin: .zero, size: size),
             operation: .copy,
             fraction: 1.0)
        newImage.unlockFocus()
        return newImage
    }
}
