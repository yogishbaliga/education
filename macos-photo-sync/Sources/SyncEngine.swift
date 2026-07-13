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
    @Published var elapsedSeconds: Double = 0
    @Published var etaMinutes: Double?          // nil until there's enough data to estimate

    /// When the current timed phase (indexing's hashing loop, or the folder
    /// comparison loop) started. Reset per-phase so elapsed/ETA reflect just
    /// that phase's own progress, not the whole run.
    private var phaseStartTime: Date?

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
        elapsedSeconds = 0
        etaMinutes = nil
        phaseStartTime = nil

        runTask = Task { await run(directory: directoryURL) }
    }

    /// Call after each unit of work completes in a timed phase. Updates
    /// elapsed time and, once there's at least one completed item, a
    /// straight-line ETA (remaining items ÷ observed rate so far).
    private func updateTiming(completed: Int, total: Int) {
        guard let phaseStartTime else { return }
        let elapsed = Date().timeIntervalSince(phaseStartTime)
        elapsedSeconds = elapsed
        guard completed > 0, elapsed > 0 else {
            etaMinutes = nil
            return
        }
        let rate = Double(completed) / elapsed // items per second
        let remaining = Double(max(0, total - completed))
        etaMinutes = (remaining / rate) / 60
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
        // Mutable copy of the index's assets; newly imported photos are folded
        // in below and the result is persisted at the end of the run, so a
        // later run (even against a different folder) doesn't have to
        // re-fetch and re-hash the whole library just to learn about photos
        // this very run already imported and knows the hashes of.
        var workingAssets = index.assets

        // 3. Enumerate directory images
        phase = .comparing
        statusLine = "Scanning folder for images…"
        elapsedSeconds = 0
        etaMinutes = nil
        phaseStartTime = nil
        let files = enumerateImages(in: directory)
        totalCount = files.count
        if files.isEmpty {
            statusLine = "No image files found in the selected folder."
            phase = .done
            return
        }
        appendLog("Found \(files.count) image file(s) in the folder.")
        phaseStartTime = Date()

        // 4. Compare each file
        for (i, url) in files.enumerated() {
            if Task.isCancelled {
                persistIncrementalIndexUpdate(workingAssets: workingAssets)
                phase = .idle
                statusLine = "Cancelled."
                return
            }

            scannedCount = i + 1
            currentName = url.lastPathComponent
            progress = Double(i) / Double(files.count)
            updateTiming(completed: i, total: files.count)
            statusLine = "Comparing \(i + 1) of \(files.count) — \(url.lastPathComponent)"

            // Decode + hash + thumbnail off the main thread so the UI stays responsive.
            // The thumbnail crosses back as a CGImage (safely Sendable at our macOS 12
            // deployment target) and is only wrapped as an NSImage once we're back here
            // on the main actor.
            let result = await Task.detached(priority: .userInitiated) {
                () -> (exact: String?, phash: UInt64?, thumb: CGImage?, decoded: Bool) in
                guard let cg = ImageHasher.decode(url: url) else {
                    return (nil, nil, nil, false)
                }
                return (ImageHasher.exactHash(cg),
                        ImageHasher.perceptualHash(cg),
                        ImageHasher.thumbnailCGImage(url: url),
                        true)
            }.value

            if let thumb = result.thumb {
                currentThumbnail = NSImage(cgImage: thumb, size: NSSize(width: thumb.width, height: thumb.height))
            }
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
                if let newID = await importImage(at: url) {
                    importedCount += 1
                    // Keep the in-memory index current so later duplicates in this
                    // same run also match without re-scanning the library.
                    if let exact { exactHashes.insert(exact) }
                    if let phash { perceptualHashes.append(phash) }
                    if let exact, let phash {
                        workingAssets.append(IndexedAsset(localIdentifier: newID,
                                                          exactHash: exact,
                                                          perceptualHash: phash,
                                                          filename: url.lastPathComponent))
                    }
                    toDelete.append(DeletionItem(url: url, reason: "Imported now"))
                    appendLog("＋ \(url.lastPathComponent) imported (copied into library) — marked for deletion.")
                } else {
                    appendLog("✗ \(url.lastPathComponent) failed to import — left in place.")
                }
            }
        }

        persistIncrementalIndexUpdate(workingAssets: workingAssets)

        progress = 1
        updateTiming(completed: files.count, total: files.count)
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

        let cached = LibraryIndex.load(libraryKey: libraryKey)
        if let cached, cached.fingerprint == fingerprint {
            appendLog("Loaded cached index (\(cached.assets.count) assets) — library unchanged.")
            statusLine = "Using cached library index."
            return cached
        }

        // The library changed (or there's no cache), but that doesn't mean
        // every asset needs re-hashing. Look up whatever we already know by
        // asset identifier and only fetch + hash assets that are new to us.
        // A cached hash was computed from the asset's *original* bytes,
        // which never change even if the photo is later edited
        // non-destructively, so a hit here is always safe to carry forward
        // as-is — no need to touch it again. Assets that were indexed before
        // but no longer exist in the library (deleted via Photos) are simply
        // not carried forward, since we only walk the current asset list.
        var known: [String: IndexedAsset] = [:]
        if let cached {
            known.reserveCapacity(cached.assets.count)
            for entry in cached.assets { known[entry.localIdentifier] = entry }
        }

        var entries: [IndexedAsset] = []
        entries.reserveCapacity(assets.count)
        var assetsToHash: [PHAsset] = []
        for asset in assets {
            if let existing = known[asset.localIdentifier] {
                entries.append(existing)
            } else {
                assetsToHash.append(asset)
            }
        }
        let reusedCount = entries.count

        if assetsToHash.isEmpty {
            appendLog(cached != nil
                ? "Library changed — reused all \(reusedCount) already-indexed asset(s); nothing new to hash."
                : "Library is empty — nothing to index.")
            let index = LibraryIndex(fingerprint: fingerprint, assets: entries)
            index.save(libraryKey: libraryKey)
            currentThumbnail = nil
            return index
        }

        // Fetching each new asset's data from PhotoKit and hashing its pixels
        // are both independent, one-asset-at-a-time operations, so a bounded
        // pool of concurrent workers speeds this up substantially on
        // multi-core Macs. The pool size is capped (not just set to core
        // count) because each in-flight worker may be holding a full-size
        // decoded image in memory, and some may be triggering iCloud
        // downloads over the network.
        let concurrency = max(2, min(ProcessInfo.processInfo.activeProcessorCount, 6))
        appendLog(cached != nil
            ? "Library changed — reusing \(reusedCount) already-indexed asset(s), hashing \(assetsToHash.count) new one(s) using up to \(concurrency) parallel workers…"
            : "No cache found — building index for \(assetsToHash.count) asset(s) using up to \(concurrency) parallel workers…")

        let total = assetsToHash.count
        var completed = 0
        var failures = 0
        phaseStartTime = Date()

        // The thumbnail crosses task/actor boundaries as a CGImage (see the note on
        // ImageHasher.thumbnailCGImage) and is only wrapped as an NSImage once we're
        // back on the main actor in the consuming loop below.
        try await withThrowingTaskGroup(of: (IndexedAsset?, CGImage?, String?).self) { group in
            var nextIndex = 0

            func submitNext() {
                guard nextIndex < total else { return }
                let asset = assetsToHash[nextIndex]
                let wantsThumb = (nextIndex % 25 == 0)
                nextIndex += 1
                group.addTask { [weak self] in
                    guard let self else { return (nil, nil, asset.localIdentifier) }
                    if Task.isCancelled { throw CancellationError() }
                    guard let data = await self.requestImageData(for: asset) else {
                        return (nil, nil, asset.localIdentifier)
                    }
                    return await Task.detached(priority: .userInitiated) {
                        guard let cg = ImageHasher.decode(data: data),
                              let exact = ImageHasher.exactHash(cg),
                              let phash = ImageHasher.perceptualHash(cg) else {
                            return (nil, nil, asset.localIdentifier)
                        }
                        let filename = PHAssetResource.assetResources(for: asset).first?.originalFilename
                        let entry = IndexedAsset(localIdentifier: asset.localIdentifier,
                                                 exactHash: exact,
                                                 perceptualHash: phash,
                                                 filename: filename)
                        return (entry, wantsThumb ? ImageHasher.thumbnailCGImage(data: data) : nil, nil as String?)
                    }.value
                }
            }

            for _ in 0..<concurrency { submitNext() }

            while let (entry, thumb, failedID) = try await group.next() {
                if Task.isCancelled { throw CancellationError() }
                completed += 1
                if let entry {
                    entries.append(entry)
                    currentName = entry.filename ?? entry.localIdentifier
                } else if let failedID {
                    failures += 1
                    appendLog("⚠️ Could not read asset \(failedID) — likely still syncing with iCloud; will retry next launch.")
                }
                if let thumb {
                    currentThumbnail = NSImage(cgImage: thumb, size: NSSize(width: thumb.width, height: thumb.height))
                }
                progress = total == 0 ? 1 : Double(completed) / Double(total)
                updateTiming(completed: completed, total: total)
                statusLine = "Indexing \(completed) of \(total) new asset(s) (\(concurrency)x parallel)…"
                submitNext()
            }
        }

        let index = LibraryIndex(fingerprint: fingerprint, assets: entries)
        // Only persist a complete index. If some assets couldn't be read this
        // time (e.g. still downloading from iCloud right after an import), the
        // library's fingerprint (asset count + latest date) already matches —
        // so a partial index saved under that fingerprint would look "fully
        // synced" forever, permanently hiding those assets from future
        // comparisons and causing them to be re-imported on every run.
        // Skipping the save here forces a full re-check of the unhashed
        // assets next launch instead, which self-heals once they become
        // readable (already-reused entries aren't at risk either way, since
        // they aren't touched again until the library changes further).
        if failures > 0 {
            appendLog("⚠️ \(failures) asset(s) were skipped this time and were NOT saved to the index cache, so those will be retried from scratch next launch instead of trusting an incomplete result.")
        } else {
            index.save(libraryKey: libraryKey)
            appendLog("Index updated and saved (\(entries.count) total asset(s): \(reusedCount) reused, \(entries.count - reusedCount) newly hashed).")
        }
        currentThumbnail = nil
        return index
    }

    /// Called at the end of a run that imported one or more photos. Saves an
    /// updated index — old entries plus this run's new imports — so a later
    /// run (a different folder, or this same one re-run) can reuse it instead
    /// of paying for a full library re-index just to relearn what this run
    /// already knows.
    ///
    /// Safety check: re-fetches the live asset count and only saves if it
    /// matches exactly what we expect (the index we loaded/built + this run's
    /// imports). If it doesn't — e.g. the user also added or removed photos
    /// via the Photos app while this ran — our in-memory view is incomplete
    /// relative to the library's real current state, so saving it under a
    /// fingerprint that claims full coverage would risk the same
    /// permanently-hidden-asset bug fixed earlier. Skipping the save in that
    /// case just falls back to a full rebuild on the next run.
    private func persistIncrementalIndexUpdate(workingAssets: [IndexedAsset]) {
        guard importedCount > 0 else { return }
        let liveAssets = fetchLibraryImageAssets()
        guard liveAssets.count == workingAssets.count else {
            appendLog("⚠️ Library changed by more than this run's imports (now \(liveAssets.count) asset(s), expected \(workingAssets.count)) — skipping incremental index update; a full re-index will run next time.")
            return
        }
        let fingerprint = computeFingerprint(assets: liveAssets)
        LibraryIndex(fingerprint: fingerprint, assets: workingAssets).save(libraryKey: libraryKey)
        appendLog("Library index updated in place with \(importedCount) newly imported photo(s) — the next run won't need to re-index the whole library.")
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
            // Must be .original, not .current: with iCloud Photos "Optimize Mac
            // Storage" enabled, the local copy can be replaced by a smaller,
            // re-encoded proxy. .current is happy to hand back that proxy, whose
            // pixels (and therefore exact-content hash) no longer match the
            // original file — which made every synced photo look "missing" and
            // get re-imported on every run. .original forces the real bytes,
            // downloading from iCloud if needed.
            opts.version = .original
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: opts) { data, _, _, _ in
                cont.resume(returning: data)
            }
        }
    }

    /// Imports the file and, on success, returns the new asset's local
    /// identifier so the caller can fold it straight into the in-memory index
    /// instead of waiting for a future full re-index to discover it.
    private func importImage(at url: URL) async -> String? {
        await withCheckedContinuation { cont in
            var newIdentifier: String?
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                // false → Photos *copies* the file into the managed library,
                // leaving the original in place (which we then trash).
                options.shouldMoveFile = false
                request.addResource(with: .photo, fileURL: url, options: options)
                newIdentifier = request.placeholderForCreatedAsset?.localIdentifier
            } completionHandler: { success, _ in
                cont.resume(returning: success ? newIdentifier : nil)
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
