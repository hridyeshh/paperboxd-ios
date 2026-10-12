import AVKit
import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// Photos, videos, GIFs and stickers in DMs. Android twin: MessageMedia.kt.

// MARK: - Animated image

/// Plays a GIF / animated WebP from a URL. AsyncImage only shows the first
/// frame; ImageIO animates it frame by frame without decoding it all up front.
struct AnimatedImage: UIViewRepresentable {
    let url: URL?
    var contentMode: UIView.ContentMode = .scaleAspectFill

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIImageView {
        let v = UIImageView()
        v.contentMode = contentMode
        v.clipsToBounds = true
        // Let SwiftUI's frame decide the size, not the image's pixels.
        for axis in [NSLayoutConstraint.Axis.horizontal, .vertical] {
            v.setContentHuggingPriority(.defaultLow, for: axis)
            v.setContentCompressionResistancePriority(.defaultLow, for: axis)
        }
        return v
    }

    func updateUIView(_ v: UIImageView, context: Context) {
        context.coordinator.load(url, into: v)
    }

    static func dismantleUIView(_ v: UIImageView, coordinator: Coordinator) {
        coordinator.stop()
    }

    @MainActor
    final class Coordinator {
        private var current: URL?
        private var task: Task<Void, Never>?
        // Bumped on every load/stop; a stale animation stops itself.
        private var generation = 0

        func load(_ url: URL?, into v: UIImageView) {
            guard url != current else { return }
            current = url
            generation += 1
            let gen = generation
            task?.cancel()
            v.image = nil
            guard let url else { return }
            task = Task { [weak self, weak v] in
                guard let (data, _) = try? await URLSession.shared.data(from: url), !Task.isCancelled else { return }
                // The block runs on the main queue for every frame.
                CGAnimateImageDataWithBlock(data as CFData, nil) { _, frame, stop in
                    guard let self, let v, self.generation == gen else { stop.pointee = true; return }
                    v.image = UIImage(cgImage: frame)
                }
            }
        }

        func stop() {
            generation += 1
            task?.cancel()
        }
    }
}

// MARK: - In a bubble

/// A photo, video, GIF or sticker inside a message, sized from its snapshot.
struct MediaAttachmentView: View {
    let att: MessageAttachment
    let onTap: () -> Void

    var body: some View {
        let size = mediaSize(att)
        Group {
            switch att.kind {
            case AttachKind.photo:
                AsyncImage(url: URL(string: att.str("url"))) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else { BK.paper2 }
                }
                .onTapGesture(perform: onTap)
            case AttachKind.video:
                ZStack {
                    AsyncImage(url: URL(string: att.str("poster_url"))) { phase in
                        if let image = phase.image { image.resizable().scaledToFill() }
                        else { BK.ink }
                    }
                    Image(systemName: "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(.black.opacity(0.45), in: Circle())
                    if let ms = att.int("duration_ms"), ms > 0 {
                        Text(durationLabel(ms))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(.black.opacity(0.5), in: Capsule())
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(8)
                    }
                }
                .onTapGesture(perform: onTap)
            default: // gif, sticker
                AnimatedImage(url: URL(string: att.str("url")),
                              contentMode: att.kind == AttachKind.sticker ? .scaleAspectFit : .scaleAspectFill)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(att.kind == AttachKind.sticker ? Color.clear : BK.paper2)
        .clipShape(RoundedRectangle(cornerRadius: att.kind == AttachKind.sticker ? 0 : 18))
        .accessibilityLabel(att.kind == AttachKind.sticker ? "Sticker" : att.kind.capitalized)
    }
}

/// Fits media into a bubble: 240pt wide at most (stickers 140), 320 tall.
func mediaSize(_ att: MessageAttachment) -> CGSize {
    let w = Double(att.int("width") ?? 0), h = Double(att.int("height") ?? 0)
    // Unknown or extreme shapes fall back to something sensible.
    let ratio = (w > 0 && h > 0) ? min(max(w / h, 0.5), 2.5) : 1
    let maxW: Double = att.kind == AttachKind.sticker ? 140 : 240
    let maxH: Double = att.kind == AttachKind.sticker ? 140 : 320
    var width = maxW, height = maxW / ratio
    if height > maxH { height = maxH; width = maxH * ratio }
    return CGSize(width: width, height: height)
}

func durationLabel(_ ms: Int) -> String {
    let s = ms / 1000
    return String(format: "%d:%02d", s / 60, s % 60)
}

// MARK: - Full screen

/// Tapping a photo or video opens it edge to edge.
struct MediaViewer: View {
    let att: MessageAttachment
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            if att.kind == AttachKind.video {
                VideoPlayer(player: player).ignoresSafeArea()
            } else {
                AsyncImage(url: URL(string: att.str("url"))) { phase in
                    if let image = phase.image { image.resizable().scaledToFit() }
                    else { ProgressView().tint(.white) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .padding(16)
            .accessibilityLabel("Close")
        }
        .onAppear {
            guard att.kind == AttachKind.video, player == nil, let url = URL(string: att.str("url")) else { return }
            let p = AVPlayer(url: url)
            player = p
            p.play()
        }
        .onDisappear { player?.pause() }
    }
}

extension MessageAttachment: Identifiable {
    var id: String { "\(kind)-\(refID)" }
}

// MARK: - GIF / sticker picker

/// GIPHY search. Tapping one sends it straight away.
struct GifPickerSheet: View {
    /// "gifs" or "stickers".
    @State var type: String
    let onPick: (AttachmentRef) -> Void
    @State private var query = ""
    @State private var items: [GifItem] = []
    @State private var loading = true
    @State private var error: String?

    private let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                MonoChip(label: "GIFS", on: type == "gifs") { type = "gifs" }
                MonoChip(label: "STICKERS", on: type == "stickers") { type = "stickers" }
                Spacer()
            }
            TextField(type == "gifs" ? "Search GIFs" : "Search stickers", text: $query)
                .font(.system(size: 15)).foregroundStyle(BK.ink)
                .padding(12).background(BK.card)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(BK.ink.opacity(0.4), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            ScrollView {
                if let error, items.isEmpty {
                    Text(error).font(.system(size: 14)).foregroundStyle(BK.muted).padding(.top, 30)
                } else if loading && items.isEmpty {
                    PBSpinner().padding(.top, 40)
                }
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(items) { item in
                        Button {
                            onPick(AttachmentRef(kind: type == "gifs" ? AttachKind.gif : AttachKind.sticker, refID: item.id))
                        } label: {
                            AnimatedImage(url: URL(string: item.previewURL),
                                          contentMode: type == "gifs" ? .scaleAspectFill : .scaleAspectFit)
                                .frame(height: 104)
                                .frame(maxWidth: .infinity)
                                .background(type == "gifs" ? BK.paper2 : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Text("POWERED BY GIPHY")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced)).tracking(1.6).foregroundStyle(BK.muted)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(BK.paper.ignoresSafeArea())
        .environment(\.colorScheme, .light)
        .presentationDetents([.medium, .large])
        // Debounced: re-runs when the tab or the query changes.
        .task(id: "\(type)|\(query)") {
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            guard !Task.isCancelled else { return }
            loading = true
            do {
                let list = try await MessageService.gifs(type: type, query: query.trimmingCharacters(in: .whitespaces))
                guard !Task.isCancelled else { return }
                items = list.items
                error = list.items.isEmpty ? "Nothing found." : nil
            } catch {
                if !Task.isCancelled { self.error = error.localizedDescription; items = [] }
            }
            loading = false
        }
    }
}

// MARK: - Preparing picks for upload

/// A photo or video picked for the composer, uploading in the background.
struct PendingMedia: Identifiable {
    let id = UUID()
    let kind: String
    var preview: UIImage?
    var upload: MediaUpload?
}

enum MediaPrep {
    struct Prepared {
        let data: Data
        let mimeType: String
        let kind: String
        let preview: UIImage?
    }

    static let maxVideoBytes = 50 * 1024 * 1024

    static func isVideo(_ item: PhotosPickerItem) -> Bool {
        item.supportedContentTypes.contains { $0.conforms(to: .movie) }
    }

    /// Photos become a ≤2048px JPEG (HEIC doesn't travel); videos an MP4 at
    /// 720p, falling back to medium quality when 720p is over the size cap.
    static func prepare(_ item: PhotosPickerItem) async throws -> Prepared {
        if isVideo(item) {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else { throw PrepError.unreadable }
            defer { try? FileManager.default.removeItem(at: movie.url) }
            var out = try await exportMP4(movie.url, preset: AVAssetExportPreset1280x720)
            if fileSize(out) > maxVideoBytes {
                try? FileManager.default.removeItem(at: out)
                out = try await exportMP4(movie.url, preset: AVAssetExportPresetMediumQuality)
            }
            defer { try? FileManager.default.removeItem(at: out) }
            guard fileSize(out) <= maxVideoBytes else { throw PrepError.tooBig }
            let data = try Data(contentsOf: out)
            let gen = AVAssetImageGenerator(asset: AVURLAsset(url: out))
            gen.appliesPreferredTrackTransform = true
            let still = try? await gen.image(at: .zero).image
            return Prepared(data: data, mimeType: "video/mp4", kind: AttachKind.video, preview: still.map { UIImage(cgImage: $0) })
        }
        guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
            throw PrepError.unreadable
        }
        let scaled = downscale(image, maxSide: 2048)
        guard let jpeg = scaled.jpegData(compressionQuality: 0.85) else { throw PrepError.unreadable }
        return Prepared(data: jpeg, mimeType: "image/jpeg", kind: AttachKind.photo, preview: scaled)
    }

    private static func downscale(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        // Drawing also bakes in the photo's orientation.
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func exportMP4(_ src: URL, preset: String) async throws -> URL {
        guard let session = AVAssetExportSession(asset: AVURLAsset(url: src), presetName: preset) else {
            throw PrepError.unreadable
        }
        let out = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        session.outputURL = out
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        await session.export()
        guard session.status == .completed else { throw session.error ?? PrepError.unreadable }
        return out
    }

    private static func fileSize(_ url: URL) -> Int {
        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int) ?? 0
    }

    enum PrepError: LocalizedError {
        case unreadable, tooBig
        var errorDescription: String? {
            switch self {
            case .unreadable: return "Couldn't read that file"
            case .tooBig: return "That video is too long to send"
            }
        }
    }
}

/// A picked video, copied out of the Photos sandbox into tmp.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { received in
            let dst = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: dst)
            return PickedMovie(url: dst)
        }
    }
}
