import SwiftUI

/// Share options for a book — renders the web-style story/square card and routes
/// it to Instagram Stories, the system share sheet, the photo library, or the clipboard.
struct BookShareSheet: View {
    let book: Book
    let user: User?
    var status: ShareStatus? = nil
    var userRating: Int? = nil
    var note: String? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var coverImage: UIImage?
    @State private var format: BookShareCardView.Format = .story
    @State private var rendered: UIImage?
    @State private var isPreparing = true
    @State private var showSystemShare = false
    @State private var toast: String?

    private var bookURL: URL? {
        URL(string: "https://paperboxd.in/b/\(book.slug ?? book.id)")
    }

    private var handle: String? {
        user?.username.map { "@\($0)" }
    }

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()

            VStack(spacing: 0) {
                grabber
                header
                preview
                controlsRow
                optionsRow
            }

            if let toast {
                toastChip(toast)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .task { await loadCover() }
        .sheet(isPresented: $showSystemShare) {
            SystemShareSheet(items: systemShareItems)
        }
    }

    // MARK: - Chrome (brutalist: hard edges, ink borders, offset shadows)

    private var grabber: some View {
        Rectangle().fill(Color("TextPrimary"))
            .frame(width: 40, height: 5)
            .padding(.top, 10)
    }

    private var header: some View {
        HStack {
            Text("SHARE")
                .font(.system(size: 17, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color("TextPrimary"))
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color("TextPrimary"))
                    .frame(width: 34, height: 34)
                    .background(Color("Surface"))
                    .overlay(Rectangle().strokeBorder(Color("TextPrimary"), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Preview

    private var preview: some View {
        Group {
            if let rendered {
                // Color.clear fixes the container size; the card scales to fit.
                Color.clear
                    .overlay(
                        Image(uiImage: rendered)
                            .resizable()
                            .scaledToFit()
                            .padding(12)
                    )
            } else {
                Color("Surface").overlay(PBSpinner())
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 360)
        .background(Color("Surface"))
        .overlay(Rectangle().strokeBorder(Color("TextPrimary"), lineWidth: 2))
        .background(Rectangle().fill(Color("TextPrimary")).offset(x: 5, y: 5))
        .padding(.leading, 24)
        .padding(.trailing, 29)
        .padding(.top, 8)
        .padding(.bottom, 13)
        .animation(.easeInOut(duration: 0.2), value: rendered)
    }

    private var controlsRow: some View {
        HStack(spacing: 12) {
            formatTab("STORY", .story)
            formatTab("SQUARE", .square)
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
    }

    /// Two separate rectangular buttons (not a fused segmented block), each with
    /// its own ink border so the selected fill never swallows the outline.
    private func formatTab(_ label: String, _ f: BookShareCardView.Format) -> some View {
        Button {
            guard format != f else { return }
            format = f
            rerender()
        } label: {
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundStyle(format == f ? Color("Background") : Color("TextPrimary"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(format == f ? Color("TextPrimary") : Color("Surface"))
                .overlay(Rectangle().strokeBorder(Color("TextPrimary"), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Options

    private var optionsRow: some View {
        HStack(alignment: .top, spacing: 12) {
            if ShareService.canShareToInstagramStories {
                option("STORY", tint: instagramGradient) {
                    shareToInstagram()
                } icon: {
                    InstagramGlyph(size: 24, color: .white)
                }
            }
            option("MORE", tint: AnyShapeStyle(Color("Surface"))) {
                showSystemShare = true
            } icon: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color("TextPrimary"))
            }
            option("SAVE", tint: AnyShapeStyle(Color("Surface"))) {
                saveImage()
            } icon: {
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color("TextPrimary"))
            }
            option("COPY", tint: AnyShapeStyle(Color("Surface"))) {
                copyLink()
            } icon: {
                Image(systemName: "link")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color("TextPrimary"))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity)
    }

    private func option<Icon: View>(
        _ label: String,
        tint: AnyShapeStyle,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        let iconView = icon()
        return Button(action: action) {
            VStack(spacing: 9) {
                ZStack {
                    Rectangle().fill(tint)
                    iconView
                }
                .frame(width: 56, height: 56)
                .overlay(Rectangle().strokeBorder(Color("TextPrimary"), lineWidth: 1.5))
                .background(Rectangle().fill(Color("TextPrimary")).offset(x: 3, y: 3))

                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(Color("TextSecondary"))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(rendered == nil && label != "COPY")
    }

    private var instagramGradient: AnyShapeStyle {
        AnyShapeStyle(LinearGradient(
            colors: [
                Color(red: 0.96, green: 0.27, blue: 0.40),
                Color(red: 0.61, green: 0.20, blue: 0.79),
                Color(red: 0.99, green: 0.69, blue: 0.31),
            ],
            startPoint: .bottomLeading, endPoint: .topTrailing
        ))
    }

    // MARK: - Actions

    private var systemShareItems: [Any] {
        var items: [Any] = []
        if let rendered { items.append(rendered) }
        if let bookURL { items.append(bookURL) }
        return items
    }

    private func shareToInstagram() {
        guard let rendered else { return }
        ShareService.shareToInstagramStories(image: rendered, sourceAppID: "com.paperboxd.PaperBoxd")
        dismiss()
    }

    private func saveImage() {
        guard let rendered else { return }
        ShareService.saveToPhotos(rendered) { success in
            showToast(success ? "Saved to Photos" : "Couldn’t save image")
        }
    }

    private func copyLink() {
        guard let bookURL else { return }
        UIPasteboard.general.string = bookURL.absoluteString
        showToast("Link copied")
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = nil }
        }
    }

    private func toastChip(_ msg: String) -> some View {
        Text(msg)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(white: 0.15).opacity(0.96), in: Capsule())
    }

    // MARK: - Rendering

    private func loadCover() async {
        if let urlStr = book.coverURL?.replacingOccurrences(of: "http://", with: "https://"),
           let url = URL(string: urlStr),
           let (data, _) = try? await URLSession.shared.data(from: url),
           let img = UIImage(data: data) {
            coverImage = img
        }
        rerender()
        isPreparing = false
    }

    @MainActor
    private func rerender() {
        let composition = ShareComposition(
            title: book.title,
            author: book.authorLine,
            year: book.publishedYear,
            coverImage: coverImage,
            handle: handle,
            rating: userRating,
            note: note,
            statusLabel: status?.label ?? "",
            theme: .light,
            format: format
        )
        rendered = ShareService.render(composition, baseSize: format.baseSize, scale: format.renderScale)
    }
}

/// The Instagram camera glyph (rounded square + lens + flash dot), drawn so we
/// don't need to bundle the trademarked logo asset.
struct InstagramGlyph: View {
    var size: CGFloat
    var color: Color = .white

    var body: some View {
        let lw = size * 0.09
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .strokeBorder(color, lineWidth: lw)
                .frame(width: size, height: size)
            Circle()
                .strokeBorder(color, lineWidth: lw)
                .frame(width: size * 0.46, height: size * 0.46)
            Circle()
                .fill(color)
                .frame(width: size * 0.12, height: size * 0.12)
                .offset(x: size * 0.27, y: -size * 0.27)
        }
        .frame(width: size, height: size)
    }
}
