import Foundation
import Photos
import AppKit
import UniformTypeIdentifiers

/// An image in the directory that has been resolved to a deletion candidate.
struct DeletionItem: Identifiable {
    let id = UUID()
    let url: URL
    let reason: String          // "Already in library" | "Imported now"
    var selected: Bool = true
}

/// How the engine decides whether a directory image already exists in the library.
enum MatchMode: String, CaseIterable, Identifiable {
    case exact       = "Exact content (ignores EXIF)"
    case similarity  = "Visually similar (perceptual)"
    var id: String { rawValue }
}

enum Phase: Equatable {
    case idle
    case indexing
    case comparing
    case confirming
    case deleting
    case done
    case error(String)
}

@MainActor
final class SyncEngine: ObservableObject {

    // MARK: - Inputs (bound from the UI)
    @Published var directoryURL: URL?
    @Published var libraryURL: URL?          // the selected .photoslibrary (see note below)
    @Published var matchMode: MatchMode = .exact
    @Published var similarityThreshold: Int = 6   // max Hamming distance for a "match"

    // MARK: - Progress / status
    @Published var phase: Phase = .idle
    @Published var statusLine: String = "Choose a folder and your Photos library, then Start."
    @Published var progress: Double = 0        // 0...1
    @Published var currentName: String = ""
    @Published var currentThumbnail: NSImage?
    @Published var log: [String] = []

    // MARK: - Results
    @Published var toDelete: [DeletionItem] = []
    @Published var importedCount = 0
    @Published var matchedCount = 0
    @Published var scannedCount = 0
    @Published var totalCount = 0

    private var runTask: Task<Void, Never>?

    var isRunning: Bool {
        switch phase {
        case .indexing, .comparing, .deleting: return true
        default: return false
        }
    }

    var libraryKey: String {
        libraryURL?.path ?? "system-photo-library"
    }

    // MARK: - Public controls

    func start() {
        guard let directoryURL else {
            phase = .error("Please choose a source folder first.")
            statusLine = "No source folder selected."
            return
        }
        runTask?.cancel()
        toDelete = []
        importedCount = 0
        matchedCount = 0
        scannedCount = 0
        totalCount = 0
        log = []
        progress = 0
        currentThumbnail = nil
        currentName = ""

        runTask = Task { await run(directory: directoryURL) }
    }

    func cancel() {
        runTask?.cancel()
        statusLine = "Cancelled."
        phase = .idle
    }

    // MARK: - Main flow

    private func run(directory: URL) async {
        // 1. Authorization
        let status = await requestAuthorization()
        guard status == .authorized || status == .limited else {
            phase = .error("Photos access was not granted. Enable it in System Settings › Privacy & Security › Photos.")
            statusLine = "Photos access denied."
            return
        }
        if status == .limited {
            appendLog("⚠️ Photos access is limited — only a subset of the library is visible, so matching may be incomplete.")
        }

        // 2. Build or load the library index
        phase = .indexing
        statusLine = "Preparing the Photos library index…"
        let index: LibraryIndex
        do {
            index = try await buildOrLoadIndex()
        } catch is CancellationError {
            statusLine = "Cancelled."
            phase = .idle
            return
        } catch {
            phase = .error("Failed to index the library: \(error.localizedDescription)")
            statusLine = "Indexing failed."
            return
        }
        if Task.isCancelled { phase = .idle; return }

        var exactHashes = index.exactHashSet()
        var perceptualHashes = index.perceptualHashes()

        // 3. Enumerate directory images
        phase = .comparing
        statusLine = "Scanning folder for images…"
        let files = enumerateImages(in: directory)
        totalCount = files.count
        if files.isEmpty {
            statusLine = "No image files found in the selected folder."
            phase = .done
            return
        }
        appendLog("Found \(files.count) image file(s) in the folder.")

        // 4. Compare each file
        for (i, url) in files.enumerated() {
            if Task.isCancelled { phase = .idle; statusLine = "Cancelled."; return }

            scannedCount = i + 1
            currentName = url.lastPathComponent
            progress = Double(i) / Double(files.count)
            statusLine = "Comparing \(i + 1) of \(files.count) — \(url.lastPathComponent)"

            // Decode + hash + thumbnail off the main thread so the UI stays responsive.
            let result = await Task.detached(priority: .userInitiated) {
                () -> (exact: String?, phash: UInt64?, thumb: NSImage?, decoded: Bool) in
                guard let cg = ImageHasher.decode(url: url) else {
                    return (nil, nil, nil, false)
                }
                return (ImageHasher.exactHash(cg),
                        ImageHasher.perceptualHash(cg),
                        ImageHasher.thumbnail(url: url),
                        true)
            }.value

            currentThumbnail = result.thumb
            guard result.decoded else {
                appendLog("⚠️ Could not decode \(url.lastPathComponent) — skipped.")
                continue
            }
            let exact = result.exact
            let phash = result.phash

            let existsInLibrary = matches(exact: exact,
                                          phash: phash,
                                          exactHashes: exactHashes,
                                          perceptualHashes: perceptualHashes)

            if existsInLibrary {
                matchedCount += 1
                toDelete.append(DeletionItem(url: url, reason: "Already in library"))
                appendLog("✓ \(url.lastPathComponent) already in library — marked for deletion.")
            } else {
                let imported = await importImage(at: url)
                if imported {
                    importedCount += 1
                    // Keep the in-memory index current so later duplicates in this
                    // same run also match without re-scanning the library.
                    if let exact { exactHashes.insert(exact) }
                    if let phash { perceptualHashes.append(phash) }
                    toDelete.append(DeletionItem(url: url, reason: "Imported now"))
                    appendLog("＋ \(url.lastPathComponent) imported (copied into library) — marked for deletion.")
                } else {
                    appendLog("✗ \(url.lastPathComponent) failed to import — left in place.")
                }
            }
        }

        progress = 1
        currentThumbnail = nil
        currentName = ""
        phase = .confirming
        statusLine = "Done comparing. Review \(toDelete.count) file(s) below, then confirm deletion."
    }

    // MARK: - Matching

    private func matches(exact: String?,
                         phash: UInt64?,
                         exactHashes: Set<String>,
                         perceptualHashes: [UInt64]) -> Bool {
        if let exact, exactHashes.contains(exact) { return true }
        if matchMode == .similarity, let phash {
            for candidate in perceptualHashes {
                if ImageHasher.hammingDistance(phash, candidate) <= similarityThreshold {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Index construction

    /// The library's state signature. If any of these change, we rebuild.
    private func computeFingerprint(assets: [PHAsset]) -> String {
        var latest: TimeInterval = 0
        for a in assets {
            if let m = a.modificationDate?.timeIntervalSince1970, m > latest { latest = m }
        }
        return "count=\(assets.count);latest=\(Int(latest));key=\(libraryKey)"
    }

    private func buildOrLoadIndex() async throws -> LibraryIndex {
        let assets = fetchLibraryImageAssets()
        let fingerprint = computeFingerprint(assets: assets)

        if let cached = LibraryIndex.load(libraryKey: libraryKey), cached.fingerprint == fingerprint {
            appendLog("Loaded cached index (\(cached.assets.count) assets) — library unchanged.")
            statusLine = "Using cached library index."
            return cached
        }

        // Fetching each asset's data from PhotoKit and hashing its pixels are both
        // independent, one-asset-at-a-time operations, so a bounded pool of
        // concurrent workers speeds this up substantially on multi-core Macs.
        // The pool size is capped (not just set to core count) because each
        // in-flight worker may be holding a full-size decoded image in memory,
        // and some may be triggering iCloud downloads over the network.
        let concurrency = max(2, min(ProcessInfo.processInfo.activeProcessorCount, 6))
        appendLog("Library changed or no cache — building index for \(assets.count) assets using up to \(concurrency) parallel workers…")

        let total = assets.count
        var entries: [IndexedAsset] = []
        entries.reserveCapacity(total)
        var completed = 0

        try await withThrowingTaskGroup(of: (IndexedAsset?, NSImage?).self) { group in
            var nextIndex = 0

            func submitNext() {
                guard nextIndex < total else { return }
                let asset = assets[nextIndex]
                let wantsThumb = (nextIndex % 25 == 0)
                nextIndex += 1
                group.addTask { [weak self] in
                    guard let self else { return (nil, nil) }
                    if Task.isCancelled { throw CancellationError() }
                    guard let data = await self.requestImageData(for: asset) else { return (nil, nil) }
                    return await Task.detached(priority: .userInitiated) {
                        guard let cg = ImageHasher.decode(data: data),
                              let exact = ImageHasher.exactHash(cg),
                              let phash = ImageHasher.perceptualHash(cg) else {
                            return (nil, nil)
                        }
                        let filename = PHAssetResource.assetResources(for: asset).first?.originalFilename
                        let entry = IndexedAsset(localIdentifier: asset.localIdentifier,
                                                 exactHash: exact,
                                                 perceptualHash: phash,
                                                 filename: filename)
                        return (entry, wantsThumb ? NSImage(data: data) : nil)
                    }.value
                }
            }

            for _ in 0..<concurrency { submitNext() }

            while let (entry, thumb) = try await group.next() {
                if Task.isCancelled { throw CancellationError() }
                completed += 1
                if let entry { entries.append(entry) }
                if let thumb { currentThumbnail = thumb }
                progress = total == 0 ? 1 : Double(completed) / Double(total)
                statusLine = "Indexing library \(completed) of \(total) (\(concurrency)x parallel)…"
                submitNext()
            }
        }

        let index = LibraryIndex(fingerprint: fingerprint, assets: entries)
        index.save(libraryKey: libraryKey)
        appendLog("Index built and saved (\(entries.count) assets).")
        currentThumbnail = nil
        return index
    }

    // MARK: - Deletion (after user confirmation)

    func confirmDeletion() {
        runTask?.cancel()
        runTask = Task {
            phase = .deleting
            let selected = toDelete.filter { $0.selected }
            var deleted = 0
            var failed = 0
            for (i, item) in selected.enumerated() {
                progress = selected.isEmpty ? 1 : Double(i) / Double(selected.count)
                statusLine = "Moving \(i + 1) of \(selected.count) to Trash…"
                currentName = item.url.lastPathComponent
                do {
                    // Moved to Trash (recoverable) rather than permanently removed.
                    try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                    deleted += 1
                } catch {
                    failed += 1
                    appendLog("✗ Could not delete \(item.url.lastPathComponent): \(error.localizedDescription)")
                }
            }
            progress = 1
            phase = .done
            statusLine = "Finished. Moved \(deleted) file(s) to Trash" + (failed > 0 ? ", \(failed) failed." : ".")
            appendLog("Deletion complete: \(deleted) trashed, \(failed) failed.")
        }
    }

    func skipDeletion() {
        phase = .done
        statusLine = "No files were deleted."
    }

    // MARK: - Selection helpers for the confirmation list

    func toggle(_ item: DeletionItem) {
        if let idx = toDelete.firstIndex(where: { $0.id == item.id }) {
            toDelete[idx].selected.toggle()
        }
    }

    func setAllSelected(_ value: Bool) {
        for idx in toDelete.indices { toDelete[idx].selected = value }
    }

    // MARK: - Photos framework wrappers

    private func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                cont.resume(returning: status)
            }
        }
    }

    private func fetchLibraryImageAssets() -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        options.includeHiddenAssets = false
        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    nonisolated private func requestImageData(for asset: PHAsset) async -> Data? {
        await withCheckedContinuation { cont in
            let opts = PHImageRequestOptions()
            opts.isNetworkAccessAllowed = true
            opts.isSynchronous = false
            opts.deliveryMode = .highQualityFormat
            opts.version = .current
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opts) { data, _, _, _ in
                cont.resume(returning: data)
            }
        }
    }

    private func importImage(at url: URL) async -> Bool {
        await withCheckedContinuation { cont in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                // false → Photos *copies* the file into the managed library,
                // leaving the original in place (which we then trash).
                options.shouldMoveFile = false
                request.addResource(with: .photo, fileURL: url, options: options)
            } completionHandler: { success, _ in
                cont.resume(returning: success)
            }
        }
    }

    // MARK: - Directory enumeration

    private func enumerateImages(in directory: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile ?? false
            if isRegular && isImageFile(url) { urls.append(url) }
        }
        return urls.sorted { $0.path < $1.path }
    }

    private func isImageFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext.isEmpty { return false }
        if let type = UTType(filenameExtension: ext) {
            return type.conforms(to: .image)
        }
        let fallback: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tiff",
                                     "tif", "gif", "bmp", "webp", "dng", "raw"]
        return fallback.contains(ext)
    }

    // MARK: - Logging

    private func appendLog(_ line: String) {
        log.append(line)
        if log.count > 500 { log.removeFirst(log.count - 500) }
    }
}
