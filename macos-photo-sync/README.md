# Photo Library Sync

A small native macOS app that reconciles a folder of image files with your
**Photos** library:

- Recursively walks a **source folder** you choose.
- For each image, checks whether it already exists in your Photos library
  by comparing **image content only** (EXIF / metadata is ignored).
  - **Exists** → the file is marked for deletion.
  - **New** → the file is **imported** into the library (Photos *copies* it
    into the managed library, it is not referenced in place), then the
    original file is marked for deletion.
- When the whole folder is processed, it shows every file marked for
  deletion in a grid so you can **review and confirm** before anything is
  removed. Confirmed files are moved to the **Trash** (recoverable), not
  permanently deleted.

It shows live progress (percentage + the thumbnail of the image currently
being compared) and keeps an on-disk **index** of your library so the
expensive one-time library scan is not repeated on every run.

---

## Comparison methods

You choose the method **before** starting:

| Method | How it works | Use when |
|--------|--------------|----------|
| **Exact content (ignores EXIF)** | Decodes each image to raw pixels and hashes them with SHA-256. Identical pixels → match, regardless of metadata. | You want to catch true duplicates, even if EXIF/date/GPS differs. |
| **Visually similar (perceptual)** | Computes a 64-bit difference hash (dHash) and matches within a **sensitivity** (Hamming distance) you set with a slider. | You also want to catch re-compressed, resized, or lightly edited copies. |

Exact matching is always applied; enabling *Visually similar* additionally
matches near-duplicates within the chosen sensitivity.

---

## The on-disk index

Scanning a large library is slow, so the app builds an index once and stores
it at:

```
~/Library/Application Support/PhotoLibrarySync/index-<hash>.json
```

Each entry holds the asset id, the exact hash, and the perceptual hash.
On the next run the app computes a **fingerprint** of the library
(number of image assets + newest modification date). If the fingerprint is
unchanged the cached index is reused instantly; if the library changed, the
index is rebuilt (with its own progress bar). A separate cache file is kept
per selected library.

---

## Important note about "which library"

Apple's PhotoKit API only lets an app talk to the **System Photo Library**
(the one set in *Photos ▸ Settings ▸ General ▸ Use as System Photo Library*).
There is no public API to point an app at an arbitrary `.photoslibrary`
bundle.

So the library picker in this app is used to (a) name the on-disk index cache
and (b) remind you which library should be active. **Make sure the library
you pick is currently your System Photo Library.** To switch libraries, hold
<kbd>⌥ Option</kbd> while opening Photos, choose the library, then set it as
the System Photo Library in Photos settings, and quit Photos before running
this app.

---

## Building the app

You need the **Xcode command-line tools** (a full Xcode install is *not*
required):

```sh
xcode-select --install
```

Then, from this folder:

```sh
make            # build a native .app for your Mac
# or
make universal  # build a universal binary (Apple Silicon + Intel)
```

The result is `build/PhotoLibrarySync.app`. Other useful targets:

```sh
make run        # build and launch
make clean      # delete the build output
```

The Makefile ad-hoc code-signs the app (`codesign --sign -`). This is what
lets the macOS privacy prompt for Photos access appear. No paid Apple
Developer account is needed.

---

## Running / distributing without the App Store

The app is fully self-contained. To use it on any Mac:

1. Copy `build/PhotoLibrarySync.app` to `/Applications` (or anywhere).
2. Because it is ad-hoc signed (not notarized), Gatekeeper will warn the
   first time. Open it once via **right-click ▸ Open ▸ Open**, or run:
   ```sh
   xattr -dr com.apple.quarantine /Applications/PhotoLibrarySync.app
   ```
3. On first run, macOS asks for **Photos** access — click **Allow** (full
   access is required so the app can both read and add photos). You can later
   manage this in *System Settings ▸ Privacy & Security ▸ Photos*.

For a universal build (`make universal`) the same `.app` runs on both Apple
Silicon and Intel Macs.

---

## Using it

1. **Choose Folder…** — the folder of images to reconcile (scanned
   recursively).
2. **Choose Library…** — your `.photoslibrary` (see the note above).
3. Pick a **comparison method** (and sensitivity, if perceptual).
4. **Start.** Watch the index build (first run) and then the per-image
   comparison progress.
5. **Review** the grid of files marked for deletion, deselect anything you
   want to keep, then **Delete Selected** (moves them to the Trash) or
   **Keep All**.

---

## Project layout

```
macos-photo-sync/
├── Makefile                     build with plain swiftc, no Xcode project
├── Info.plist                   bundle metadata + Photos usage strings
├── README.md
└── Sources/
    ├── PhotoLibrarySyncApp.swift   @main SwiftUI app entry
    ├── ContentView.swift           UI: pickers, progress, confirmation grid
    ├── SyncEngine.swift            core flow: index, compare, import, delete
    ├── ImageHasher.swift           exact (SHA-256) + perceptual (dHash) hashing
    └── LibraryIndex.swift          index model + on-disk persistence
```

## Safety notes

- Deletions go to the **Trash**, so a mistake is recoverable until you empty it.
- Imports use `shouldMoveFile = false`, so Photos **copies** each file into
  the library; the original stays put until you confirm deletion.
- Nothing is deleted or imported without you pressing **Start**, and nothing
  is deleted without the final **Delete Selected** confirmation.
