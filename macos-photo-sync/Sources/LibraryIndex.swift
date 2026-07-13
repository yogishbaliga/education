import Foundation
import CryptoKit

/// One entry in the on-disk index describing a single asset in the Photos library.
struct IndexedAsset: Codable {
    let localIdentifier: String
    let exactHash: String
    let perceptualHash: UInt64
    let filename: String?
}

/// Tiny pointer file that records which versioned index file is current for
/// a given library. Saving writes a new versioned file, then updates this
/// manifest to point at it, then deletes the previous version — in that
/// order, so a crash mid-save can never leave the manifest pointing at a
/// missing or partially-written file (see `LibraryIndex.save`).
private struct LibraryIndexManifest: Codable {
    var version: Int
    var filename: String
}

/// The full index for one Photos library, persisted to disk so the (expensive)
/// scan of the whole library only has to happen once. The `fingerprint`
/// captures the library's state; if it changes, the index is rebuilt.
struct LibraryIndex: Codable {
    var fingerprint: String
    var assets: [IndexedAsset]

    // MARK: - On-disk location

    static func cacheDirectory() -> URL {
        let fm = FileManager.default
        let base = (fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                    ?? fm.temporaryDirectory)
            .appendingPathComponent("PhotoLibrarySync", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// A stable, filesystem-safe digest derived from the library key (the
    /// selected library path). Different libraries get different caches.
    private static func keyDigest(_ key: String) -> String {
        SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func manifestURL(forLibraryKey key: String) -> URL {
        cacheDirectory().appendingPathComponent("index-\(keyDigest(key))-manifest.json")
    }

    private static func versionedFilename(forLibraryKey key: String, version: Int) -> String {
        "index-\(keyDigest(key))-v\(version).json"
    }

    private static func loadManifest(libraryKey: String) -> LibraryIndexManifest? {
        guard let data = try? Data(contentsOf: manifestURL(forLibraryKey: libraryKey)) else { return nil }
        return try? JSONDecoder().decode(LibraryIndexManifest.self, from: data)
    }

    static func load(libraryKey: String) -> LibraryIndex? {
        guard let manifest = loadManifest(libraryKey: libraryKey) else { return nil }
        let url = cacheDirectory().appendingPathComponent(manifest.filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LibraryIndex.self, from: data)
    }

    /// Writes a new version and only then repoints the manifest at it,
    /// deleting the previous version last. That ordering — new file first,
    /// manifest second, delete third — means an interruption at any point
    /// (app quit, crash) leaves the manifest referencing a file that's
    /// either the old, still-intact version or the new, fully-written one:
    /// never a half-written file. Keeping just the current version (instead
    /// of an unbounded history) is what keeps this cheap on disk space even
    /// though it may be saved frequently (e.g. a periodic background flush).
    func save(libraryKey: String) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        let previous = LibraryIndex.loadManifest(libraryKey: libraryKey)
        let nextVersion = (previous?.version ?? 0) + 1
        let filename = LibraryIndex.versionedFilename(forLibraryKey: libraryKey, version: nextVersion)
        let dataURL = LibraryIndex.cacheDirectory().appendingPathComponent(filename)

        guard (try? data.write(to: dataURL, options: .atomic)) != nil else { return }

        let manifest = LibraryIndexManifest(version: nextVersion, filename: filename)
        guard let manifestData = try? JSONEncoder().encode(manifest) else { return }
        let manifestURL = LibraryIndex.manifestURL(forLibraryKey: libraryKey)
        guard (try? manifestData.write(to: manifestURL, options: .atomic)) != nil else { return }

        if let previous, previous.filename != filename {
            try? FileManager.default.removeItem(
                at: LibraryIndex.cacheDirectory().appendingPathComponent(previous.filename))
        }
    }

    // MARK: - Fast in-memory lookup structures

    /// Set of exact hashes for O(1) exact-match tests.
    func exactHashSet() -> Set<String> {
        Set(assets.map { $0.exactHash })
    }

    /// All perceptual hashes, for similarity scans.
    func perceptualHashes() -> [UInt64] {
        assets.map { $0.perceptualHash }
    }
}
