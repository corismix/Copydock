//
//  ClipboardCardView.swift
//  Copydock
//
//  Card view for individual clipboard history items, styled after Paste for macOS:
//  a vivid color header with the item kind, relative time and source-app icon,
//  a content body, and a metadata footer.
//

import SwiftUI
import AppKit
import QuickLookThumbnailing

// MARK: - Accessibility Helper

func clipboardCardAccessibilityLabel(for item: ClipboardItemModel) -> String {
    let time = item.formattedTime
    switch item.itemType {
    case .text:
        let kind = CardKind(item: item)
        if kind == .color {
            let raw = item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return String(format: String(localized: "accessibility.mainpanel.card.colorFormat"), raw, time)
        }
        if kind == .link {
            return String(format: String(localized: "accessibility.mainpanel.card.linkFormat"), CardKind.displayURL(item.plainText ?? ""), time)
        }
        let preview = String((item.displayText).prefix(50))
        let count = item.characterCount ?? 0
        return String(format: String(localized: "accessibility.mainpanel.card.textFormat"), preview, count, time)
    case .image:
        let sizeInfo = item.imageSizeInfo ?? ""
        return String(format: String(localized: "accessibility.mainpanel.card.imageFormat"), sizeInfo, time)
    case .file:
        let name = item.filePathsArray?.first.flatMap { URL(fileURLWithPath: $0).lastPathComponent } ?? ""
        return String(format: String(localized: "accessibility.mainpanel.card.fileFormat"), name, time)
    }
}

// MARK: - ClipboardCardView

struct ClipboardCardView: View {
    let item: ClipboardItemModel
    let isSelected: Bool
    let activePinboardIndex: Int?
    let pinboardCount: Int
    let onSelect: () -> Void
    let onPaste: (_ plainTextOnly: Bool) -> Void
    /// On drag end, writes to the clipboard only; the paste notification is posted by AppDelegate after the ghost animation.
    let onWriteClipboard: (_ plainTextOnly: Bool) -> Void
    let onTogglePinboard: (_ pinboardIndex: Int) -> Void
    let onMoveToPinboard: (_ pinboardIndex: Int) -> Void
    let onAddToPasteStack: () -> Void
    let onRemoveFromPasteStack: () -> Void
    let isPasteStackMode: Bool
    let onDelete: () -> Void
    var onEdit: (() -> Void)?
    var onRename: (() -> Void)?
    var onCopy: (() -> Void)?
    var onQuickLook: (() -> Void)?
    var onOpen: (() -> Void)?
    var onNewPinboard: (() -> Void)?

    @State private var isHovered = false
    @State private var isDragging = false
    @Environment(\.cardSize) private var cardSize

    private var kind: CardKind { CardKind(item: item) }

    /// In a pinboard, headers take the pinboard's color; in history they take the source app's color.
    private var headerColor: Color {
        if let pinboard = activePinboardIndex {
            return AppSettings.pinboardColor(at: pinboard)
        }
        return Color(nsColor: CardStyle.headerColor(for: item, kind: kind))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            ZStack(alignment: .bottom) {
                contentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                footerView
            }
            .background(Color(red: 0.078, green: 0.078, blue: 0.078))
        }
        .frame(width: cardSize.width, height: cardSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.accentColor : Color.black.opacity(0.08),
                              lineWidth: isSelected ? 2.5 : 0.5)
        )
        .overlay(alignment: .topTrailing) {
            // Source app icon, large, bleeding off the card's trailing edge
            // and overlapping the header/body boundary (Paste's signature look).
            if let appIcon = item.sourceAppIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .offset(x: 0, y: 0)
                    .allowsHitTesting(false)
            }
        }
        .shadow(color: .black.opacity(isDragging ? 0.35 : isHovered ? 0.22 : 0.14),
                radius: isDragging ? 16 : isHovered ? 10 : 6,
                y: isDragging ? 8 : 3)
        .scaleEffect(isDragging ? 1.05 : isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isDragging)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .contentShape(Rectangle())
        // NSView overlay: directly handles AppKit mouse events, bypassing ScrollView gesture interception,
        // and also handles hover tracking, replacing .onHover and .highPriorityGesture(TapGesture()).
        .overlay(
            CardInteractionOverlay(
                isHovered: $isHovered,
                isDragging: $isDragging,
                onTap: handleTap,
                onDragBegan: {
                    NotificationCenter.default.post(name: AppNotification.clipboardItemDragBegan, object: item)
                },
                onDragEnded: { mouseLocation in
                    onSelect()
                    let plainText = AppSettings.pastePlainTextByDefault
                        || NSEvent.modifierFlags.contains(AppSettings.plainTextModifier)
                    onWriteClipboard(plainText)
                    NotificationCenter.default.post(
                        name: AppNotification.clipboardItemDragEnded,
                        object: nil,
                        userInfo: ["location": NSValue(point: mouseLocation)]
                    )
                }
            )
        )
        .contextMenu { contextMenuContent }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(clipboardCardAccessibilityLabel(for: item))
        .accessibilityHint(Text("accessibility.mainpanel.card.hint"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func handleTap() {
        onSelect()
        guard AppSettings.directPasteEnabled else { return }
        let shouldPlainText = AppSettings.pastePlainTextByDefault
            || NSEvent.modifierFlags.contains(AppSettings.plainTextModifier)
        onPaste(shouldPlainText)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(kind.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(item.formattedTime)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }
            .padding(.leading, 14)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: 48)
        .background(headerColor)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        switch item.itemType {
        case .text:
            switch kind {
            case .color: colorContentView
            case .link:  linkContentView
            default:     textContentView
            }
        case .image: imageContentView
        case .file:
            if item.isImageFile, let path = item.filePathsArray?.first {
                FileImagePreview(path: path)
            } else {
                fileContentView
            }
        }
    }

    private var textContentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.displayText)
                .font(.system(size: 12))
                .lineLimit(5)
                .foregroundColor(Color(white: 0.88))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var linkContentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.plainText ?? CardKind.displayURL(item.plainText ?? ""))
                .font(.system(size: 12))
                .lineLimit(4)
                .foregroundColor(Color(white: 0.88))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var colorContentView: some View {
        let raw = item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let nsColor = ColorCodeHelper.color(from: raw) ?? .clear
        return ZStack {
            Color(nsColor: nsColor)
            Text(raw)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(Color(nsColor: ColorCodeHelper.contrastingTextColor(for: nsColor)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var imageContentView: some View {
        Group {
            if let thumbnail = ThumbnailCache.shared.thumbnail(for: item.id) {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Color(red: 0.16, green: 0.16, blue: 0.17)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    )
            }
        }
    }

    private var fileContentView: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)
            if let icon = item.fileIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 32))
                    .foregroundColor(.secondary)
            }
            if let paths = item.filePathsArray, let firstPath = paths.first {
                Text(URL(fileURLWithPath: firstPath).lastPathComponent)
                    .font(.system(size: 10))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(white: 0.85))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(8)
    }

    // MARK: - Footer

    private var footerView: some View {
        Text(footerText)
            .font(.system(size: 11))
            .foregroundColor(Color(white: 0.6))
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 10)
    }

    private var footerText: String {
        switch item.itemType {
        case .text:
            if kind == .link { return "" }
            let count = item.characterCount ?? 0
            return String(format: String(localized: "mainpanel.text.characterCountFormat"), count)
        case .image:
            return item.imageSizeInfo ?? ""
        case .file:
            if let paths = item.filePathsArray, let first = paths.first {
                if paths.count > 1 {
                    return String(format: String(localized: "mainpanel.file.fileCountFormat"), paths.count)
                }
                return first
            }
            return ""
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        Button { onPaste(AppSettings.pastePlainTextByDefault) } label: {
            Label(String(localized: "mainpanel.context.paste"), systemImage: "doc.on.clipboard")
        }
        Button { onPaste(true) } label: {
            Label(String(localized: "mainpanel.context.pastePlainText"), systemImage: "text.alignleft")
        }
        Button { onCopy?() } label: {
            Label(String(localized: "mainpanel.context.copy"), systemImage: "doc.on.doc")
        }
        Divider()
        if item.itemType == .text {
            Button { onEdit?() } label: {
                Label(String(localized: "mainpanel.edit.title"), systemImage: "pencil")
            }
            Button { onRename?() } label: {
                Label(String(localized: "mainpanel.rename.title"), systemImage: "character.cursor.ibeam")
            }
        }
        Button { onQuickLook?() } label: {
            Label(String(localized: "mainpanel.context.quickLook"), systemImage: "eye")
        }
        if item.itemType == .file || kind == .link {
            Button { onOpen?() } label: {
                Label(String(localized: "mainpanel.context.open"), systemImage: "arrow.up.forward.app")
            }
        }
        Menu {
            ForEach(0..<pinboardCount, id: \.self) { index in
                Button {
                    onMoveToPinboard(index)
                } label: {
                    Label(AppSettings.pinboardName(at: index), systemImage: "circle.fill")
                        .tint(AppSettings.pinboardColor(at: index))
                }
            }
            Divider()
            Button { onNewPinboard?() } label: {
                Label(String(localized: "mainpanel.context.createPinboard"), systemImage: "plus")
            }
        } label: {
            Label(String(localized: "mainpanel.context.pin"), systemImage: "pin")
        }
        Menu {
            shareButtons
        } label: {
            Label(String(localized: "mainpanel.context.share"), systemImage: "square.and.arrow.up")
        }
        if isPasteStackMode {
            Button { onRemoveFromPasteStack() } label: {
                Label(String(localized: "mainpanel.context.removeFromPasteStack"), systemImage: "rectangle.stack.badge.minus")
            }
        } else {
            Button { onAddToPasteStack() } label: {
                Label(String(localized: "mainpanel.context.addToPasteStack"), systemImage: "rectangle.stack.badge.plus")
            }
        }
        Divider()
        Button(role: .destructive) { onDelete() } label: {
            Label(String(localized: "mainpanel.context.delete"), systemImage: "trash")
        }
    }

    @ViewBuilder
    private var shareButtons: some View {
        let payload = sharePayload
        if payload.isEmpty {
            Text("mainpanel.context.shareUnavailable")
        } else {
            ForEach(NSSharingService.sharingServices(forItems: payload), id: \.title) { service in
                Button {
                    service.perform(withItems: payload)
                } label: {
                    Label(service.title, systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    private var sharePayload: [Any] {
        switch item.itemType {
        case .text:
            if let text = item.plainText { return [text] }
        case .image:
            if let data = item.imageData, let image = NSImage(data: data) { return [image] }
        case .file:
            return (item.filePathsArray ?? []).map { URL(fileURLWithPath: $0) as Any }
        }
        return []
    }
}

// MARK: - File Image Preview

/// Asynchronously loads a Quick Look thumbnail for an image file stored as a .file clipboard item.
/// Falls back to a raw NSImage load and then to a generic photo placeholder.
private struct FileImagePreview: View {
    let path: String

    @State private var thumbnail: NSImage?
    @State private var didAttemptLoad = false

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if didAttemptLoad {
                Color(red: 0.16, green: 0.16, blue: 0.17)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    )
            } else {
                Color(nsColor: .controlBackgroundColor)
            }
        }
        .task(id: path) {
            thumbnail = await loadThumbnail(for: path)
            didAttemptLoad = true
        }
    }

    private func loadThumbnail(for path: String) async -> NSImage? {
        let url = URL(fileURLWithPath: path)

        // Try Quick Look (works within sandbox for clipboard-accessible files).
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 300, height: 300),
            scale: 2.0,
            representationTypes: .thumbnail
        )
        if let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
            return rep.nsImage
        }

        // Fallback: try loading the raw file data directly.
        if let data = try? Data(contentsOf: url), let image = NSImage(data: data) {
            return image
        }

        return nil
    }
}
