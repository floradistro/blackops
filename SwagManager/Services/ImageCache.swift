import SwiftUI
import AppKit

// MARK: - Image Cache (Ported from iOS Whale app)
// High-performance image caching optimized for product grid performance

actor ImageCache {
    static let shared = ImageCache()

    private var cache = NSCache<NSString, NSImage>()
    private var inFlightTasks: [URL: Task<NSImage?, Never>] = [:]

    // CRITICAL: Hard limit on concurrent downloads to prevent UI freeze
    private let maxConcurrentDownloads = 4
    private var activeDownloads = 0

    // Shared URLSession for connection reuse
    private let session: URLSession

    private init() {
        // Memory cache - fast access for recently viewed images
        cache.countLimit = 300
        cache.totalCostLimit = 75 * 1024 * 1024 // 75MB

        // URLCache - persistent disk cache (survives app restart)
        // Apple's approach: memory + disk caching
        let urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,   // 50MB memory
            diskCapacity: 500 * 1024 * 1024     // 500MB disk (persistent)
        )

        let config = URLSessionConfiguration.default
        config.urlCache = urlCache              // Enable disk caching
        config.requestCachePolicy = .returnCacheDataElseLoad  // Use cache first
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        config.httpMaximumConnectionsPerHost = 4
        session = URLSession(configuration: config)
    }

    /// Wait for a download slot to become available
    private func acquireSlot() async {
        while activeDownloads >= maxConcurrentDownloads {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        activeDownloads += 1
    }

    /// Release a download slot
    private func releaseSlot() {
        activeDownloads = max(0, activeDownloads - 1)
    }

    /// Get cached image synchronously (for checking cache only)
    func cachedImage(for url: URL) -> NSImage? {
        let key = url.absoluteString as NSString
        return cache.object(forKey: key)
    }

    /// Get cached image or fetch if needed
    func image(for url: URL) async -> NSImage? {
        let key = url.absoluteString as NSString

        // Check cache first (fast path)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        // Check if already fetching
        if let existingTask = inFlightTasks[url] {
            return await existingTask.value
        }

        // Start new fetch
        let task = Task<NSImage?, Never> {
            await fetchImage(url: url, key: key)
        }

        inFlightTasks[url] = task
        let result = await task.value
        inFlightTasks[url] = nil

        return result
    }

    private func fetchImage(url: URL, key: NSString) async -> NSImage? {
        // Wait for a download slot
        await acquireSlot()
        defer { releaseSlot() }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = NSImage(data: data) else {
                return nil
            }

            // Downsample large images to reduce memory
            let maxDimension: CGFloat = 500
            let downsampledImage = await downsample(image, maxDimension: maxDimension)

            // Cache the processed image
            let cost = data.count
            cache.setObject(downsampledImage, forKey: key, cost: cost)

            return downsampledImage
        } catch {
            return nil
        }
    }

    /// Downsample image to reduce memory footprint
    private func downsample(_ image: NSImage, maxDimension: CGFloat) async -> NSImage {
        await Task.detached(priority: .utility) {
            let size = image.size
            guard size.width > maxDimension || size.height > maxDimension else {
                return image
            }

            let scale = maxDimension / max(size.width, size.height)
            let newSize = CGSize(width: size.width * scale, height: size.height * scale)

            let newImage = NSImage(size: newSize)
            newImage.lockFocus()
            image.draw(in: NSRect(origin: .zero, size: newSize))
            newImage.unlockFocus()

            return newImage
        }.value
    }

    /// Clear cache
    func clear() {
        cache.removeAllObjects()
    }
}

// MARK: - Cached Async Image

struct CachedAsyncImage: View {
    let url: URL?

    @State private var image: NSImage?
    @State private var loadState: LoadState = .idle

    private enum LoadState {
        case idle
        case loading
        case loaded
        case failed
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
            } else if loadState == .loading {
                Color.black.opacity(0.3)
            } else {
                Color.black.opacity(0.3)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.white.opacity(0.15))
                            .font(.system(size: 24))
                    )
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let url else {
            loadState = .failed
            return
        }

        // Check cache synchronously first for instant display
        if let cached = await ImageCache.shared.cachedImage(for: url) {
            image = cached
            loadState = .loaded
            return
        }

        // CRITICAL: Delay image loading to let first frame render
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        guard !Task.isCancelled else { return }

        loadState = .loading

        if let loadedImage = await ImageCache.shared.image(for: url) {
            image = loadedImage
            loadState = .loaded
        } else {
            loadState = .failed
        }
    }
}
