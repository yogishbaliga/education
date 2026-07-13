import Foundation
import CryptoKit

/// One entry in the on-disk index describing a single asset in the Photos library.
struct IndexedAsset: Codable {
    let localIdentifier: String
    let exactHash: String
    let perceptualHash: UInt64
    let filename: String?
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

    /// A stable, filesystem-safe filename derived from the library key
    /// (the selected library path). Different libraries get different caches.
    static func cacheURL(forLibraryKey key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }.joined()
        return cacheDirectory().appendingPathComponent("index-\(digest).json")
    }

    static func load(libraryKey: String) -> LibraryIndex? {
        let url = cacheURL(forLibraryKey: libraryKey)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(LibraryIndex.self, from: data)
    }

    func save(libraryKey: String) {
        let url = LibraryIndex.cacheURL(forLibraryKey: libraryKey)
        if let data = try? JSONEncoder().encode(self) {
            try? data.write(to: url, options: .atomic)
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
