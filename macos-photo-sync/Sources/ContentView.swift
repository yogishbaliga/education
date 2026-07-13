import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var engine: SyncEngine

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            switch engine.phase {
            case .confirming:
                confirmationView
            default:
                setupAndProgressView
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 22))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Photo Library Sync").font(.headline)
                Text("Import new pictures, flag duplicates for deletion.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
    }

    // MARK: - Setup + progress

    private var setupAndProgressView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                pickerRow(title: "Source folder",
                          subtitle: "Images here are scanned recursively.",
                          value: engine.directoryURL?.path ?? "None selected",
                          buttonTitle: "Choose Folder…",
                          disabled: engine.isRunning) {
                    if let url = pickDirectory() { engine.directoryURL = url }
                }

                pickerRow(title: "Photos library",
                          subtitle: "Select your .photoslibrary. See note below.",
                          value: engine.libraryURL?.lastPathComponent ?? "System Photo Library (default)",
                          buttonTitle: "Choose Library…",
                          disabled: engine.isRunning) {
                    if let url = pickLibrary() { engine.libraryURL = url }
                }

                comparisonOptions

                Text("Note: macOS only exposes the **System Photo Library** to apps. "
                     + "The library you pick sets the on-disk index name; make sure it is the "
                     + "one currently set as your System Photo Library (Photos ▸ Settings ▸ General).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                controlButtons
                progressPanel
                logPanel
            }
            .padding(16)
        }
    }

    private func pickerRow(title: String, subtitle: String, value: String,
                           buttonTitle: String, disabled: Bool,
                           action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline).bold()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(value).font(.callout).lineLimit(1).truncationMode(.middle)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(buttonTitle, action: action).disabled(disabled)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
        }
    }

    private var comparisonOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comparison method").font(.subheadline).bold()
            Picker("", selection: $engine.matchMode) {
                ForEach(MatchMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .disabled(engine.isRunning)

            if engine.matchMode == .similarity {
                HStack {
                    Text("Sensitivity")
                    Slider(value: Binding(
                        get: { Double(engine.similarityThreshold) },
                        set: { engine.similarityThreshold = Int($0) }
                    ), in: 0...20, step: 1)
                    .disabled(engine.isRunning)
                    Text("≤ \(engine.similarityThreshold) bits")
                        .monospacedDigit().frame(width: 70, alignment: .trailing)
                }
                Text("Lower = stricter (near-identical). Higher = looser (catches edits, crops, re-compressions).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }

    private var controlButtons: some View {
        HStack {
            Button {
                engine.start()
            } label: {
                Label("Start", systemImage: "play.fill")
            }
            .keyboardShortcut(.defaultAction)
            .disabled(engine.isRunning || engine.directoryURL == nil)

            if engine.isRunning {
                Button(role: .cancel) { engine.cancel() } label: {
                    Label("Cancel", systemImage: "stop.fill")
                }
            }
            Spacer()
            summaryChips
        }
    }

    private var summaryChips: some View {
        HStack(spacing: 8) {
            chip("Imported", engine.importedCount, .green)
            chip("Matched", engine.matchedCount, .blue)
            if engine.totalCount > 0 {
                chip("Scanned", engine.scannedCount, .gray, of: engine.totalCount)
            }
        }
    }

    private func chip(_ label: String, _ n: Int, _ color: Color, of total: Int? = nil) -> some View {
        let text = total != nil ? "\(n)/\(total!)" : "\(n)"
        return Text("\(label): \(text)")
            .font(.caption).monospacedDigit()
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
            .foregroundStyle(color)
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(phaseLabel).font(.subheadline).bold()
                Spacer()
                if engine.phase == .indexing || engine.phase == .comparing || engine.phase == .deleting {
                    Text("\(Int(engine.progress * 100))%").monospacedDigit().font(.subheadline)
                }
            }
            ProgressView(value: engine.progress)
            Text(engine.statusLine).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let thumb = engine.currentThumbnail {
                HStack(alignment: .top, spacing: 12) {
                    Image(nsImage: thumb)
                        .resizable().scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.25)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Currently comparing").font(.caption).foregroundStyle(.secondary)
                        Text(engine.currentName).font(.callout).lineLimit(2)
                    }
                    Spacer()
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.08)))
    }

    private var phaseLabel: String {
        switch engine.phase {
        case .idle: return "Ready"
        case .indexing: return "Building library index"
        case .comparing: return "Comparing images"
        case .confirming: return "Awaiting confirmation"
        case .deleting: return "Deleting"
        case .done: return "Done"
        case .error(let m): return "Error: \(m)"
        }
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Activity").font(.subheadline).bold()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(engine.log.enumerated()), id: \.offset) { i, line in
                            Text(line).font(.caption.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(i)
                        }
                    }
                    .padding(6)
                }
                .frame(height: 160)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.05)))
                .onChange(of: engine.log.count) { _ in
                    if let last = engine.log.indices.last {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }
        }
    }

    // MARK: - Confirmation

    private var confirmationView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(engine.toDelete.filter { $0.selected }.count) of \(engine.toDelete.count) file(s) selected for deletion")
                    .font(.subheadline)
                Spacer()
                Button("Select All") { engine.setAllSelected(true) }
                Button("Deselect All") { engine.setAllSelected(false) }
            }
            .padding(12)
            Divider()

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(engine.toDelete) { item in
                        DeletionCell(item: item) { engine.toggle(item) }
                    }
                }
                .padding(12)
            }

            Divider()
            HStack {
                Text("Selected files are moved to the Trash (recoverable).")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Keep All") { engine.skipDeletion() }
                Button(role: .destructive) {
                    engine.confirmDeletion()
                } label: {
                    Label("Delete Selected", systemImage: "trash")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(engine.toDelete.allSatisfy { !$0.selected })
            }
            .padding(12)
        }
    }

    // MARK: - Pickers

    private func pickDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select the folder containing images to sync"
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func pickLibrary() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select your Photos library (.photoslibrary)"
        panel.treatsFilePackagesAsDirectories = false
        if #available(macOS 12.0, *), let photosType = UTType("com.apple.photos.library") {
            panel.allowedContentTypes = [photosType]
        }
        return panel.runModal() == .OK ? panel.url : nil
    }
}

// MARK: - Deletion cell

private struct DeletionCell: View {
    let item: DeletionItem
    let onToggle: () -> Void
    @State private var thumb: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumb {
                        Image(nsImage: thumb).resizable().scaledToFill()
                    } else {
                        Rectangle().fill(Color.secondary.opacity(0.15))
                            .overlay(ProgressView())
                    }
                }
                .frame(height: 120)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))

                Image(systemName: item.selected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.selected ? Color.accentColor : Color.white)
                    .background(Circle().fill(.black.opacity(0.35)))
                    .padding(6)
            }
            Text(item.url.lastPathComponent).font(.caption).lineLimit(1).truncationMode(.middle)
            Text(item.reason)
                .font(.caption2)
                .foregroundStyle(item.reason == "Imported now" ? .green : .blue)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 10)
            .stroke(item.selected ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 2))
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
        .task {
            if thumb == nil {
                let url = item.url
                // Cross the Task.detached boundary as a CGImage — safely Sendable at
                // our macOS 12 deployment target, unlike NSImage (Sendable since 14) —
                // then wrap as NSImage only after hopping back to the main actor.
                let cg = await Task.detached { ImageHasher.thumbnailCGImage(url: url, maxPixel: 320) }.value
                if let cg {
                    let image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                    await MainActor.run { self.thumb = image }
                }
            }
        }
    }
}
