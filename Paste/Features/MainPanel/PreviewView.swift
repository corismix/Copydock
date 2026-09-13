//
//  PreviewView.swift
//  Paste
//
//  Preview window view — shows detailed content for the selected item
//

import SwiftUI
import AppKit

// MARK: - Share Anchor

/// Holds the invisible AppKit view the share picker anchors to.
@MainActor
final class ShareAnchorPresenter: ObservableObject {
    weak var anchorView: NSView?

    func present(_ items: [Any]) {
        guard !items.isEmpty, let anchorView, anchorView.window != nil else { return }
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
    }
}

private struct ShareAnchorView: NSViewRepresentable {
    let presenter: ShareAnchorPresenter

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        presenter.anchorView = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        presenter.anchorView = nsView
    }
}

// MARK: - Async File Icon View

/// View component that loads a file icon asynchronously to avoid blocking the main thread.
struct AsyncFileIconView: View {
    let filePath: String
    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon = icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                Image(systemName: "doc")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 32, height: 32)
            }
        }
        .task(id: filePath) {
            await loadIcon()
        }
    }

    private func loadIcon() async {
        icon = nil

        guard FileManager.default.fileExists(atPath: filePath) else {
            return
        }

        let loadedIcon = await Task.detached(priority: .userInitiated) {
            return NSWorkspace.shared.icon(forFile: filePath)
        }.value

        await MainActor.run {
            icon = loadedIcon
        }
    }
}

// MARK: - Preview View

struct PreviewView: View {
    @ObservedObject var viewModel: PreviewViewModel
    @ObservedObject var clipboardViewModel: ClipboardViewModel
    let onClose: () -> Void
    let onEdit: () -> Void

    @StateObject private var sharePresenter = ShareAnchorPresenter()

    private let bodyOpacity: CGFloat = 0.85

    var body: some View {
        VStack(spacing: 0) {
            header
            contentBox
            footer
            Spacer(minLength: 0)
        }
        .frame(width: viewModel.popoverSize.width, height: viewModel.popoverSize.height, alignment: .top)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel())
        .id(viewModel.item?.id ?? viewModel.preset?.id)
    }

    private func accessibilityLabel() -> String {
        if viewModel.preset != nil {
            return String(localized: "accessibility.preview.text")
        }
        guard let item = viewModel.item else { return "" }
        switch item.itemType {
        case .text: return String(localized: "accessibility.preview.text")
        case .image: return String(localized: "accessibility.preview.image")
        case .file: return String(localized: "accessibility.preview.file")
        }
    }

    // MARK: - Header

    private var title: String {
        if viewModel.preset != nil { return String(localized: "mainpanel.filter.regex") }
        return viewModel.item.map { CardKind(item: $0).label } ?? ""
    }

    private var header: some View {
        ZStack {
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                pinMenu
                shareButton
                editButton
            }
            .padding(.trailing, 7)

            HStack(spacing: 6) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(bodyOpacity))
                        .frame(width: 17, height: 11)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "preview.action.close"))

                Text(title)
                    .font(.system(size: PreviewLayout.fontSize, weight: .bold))
                    .foregroundColor(.white.opacity(bodyOpacity))

                Spacer(minLength: 0)
            }
            .padding(.leading, 9)
        }
        .frame(height: 38)
    }

    private var currentPinState: Bool {
        guard let item = viewModel.item else { return false }
        let fresh = clipboardViewModel.items.first(where: { $0.id == item.id }) ?? item
        return ClipboardService.shared.isInAnyPinboard(fresh)
    }

    private var pinMenu: some View {
        Menu {
            if AppSettings.pinboardCount == 0 {
                Text(String(localized: "mainpanel.context.createPinboard"))
            } else {
                ForEach(0..<AppSettings.pinboardCount, id: \.self) { index in
                    Button {
                        if let item = viewModel.item {
                            clipboardViewModel.toggleInPinboard(item, index: index)
                        }
                    } label: {
                        if let item = viewModel.item, ClipboardService.shared.isInPinboard(item, index: index) {
                            Label(AppSettings.pinboardName(at: index), systemImage: "checkmark")
                        } else {
                            Text(AppSettings.pinboardName(at: index))
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: currentPinState ? "circle.inset.filled" : "circle.dashed")
                    .font(.system(size: 13))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundColor(.white.opacity(bodyOpacity))
            .frame(width: 45, height: 24)
            .contentShape(Rectangle())
        }
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel(String(localized: "preview.action.pin"))
    }

    private var shareButton: some View {
        Button {
            sharePresenter.present(shareItems)
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(bodyOpacity))
                .frame(width: 34, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(ShareAnchorView(presenter: sharePresenter).frame(width: 1, height: 1))
        .accessibilityLabel(String(localized: "preview.action.share"))
    }

    private var editButton: some View {
        Button(action: onEdit) {
            Text(String(localized: "preview.action.edit"))
                .font(.system(size: PreviewLayout.fontSize))
                .foregroundColor(.white.opacity(bodyOpacity))
                .frame(width: 45.5, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var shareItems: [Any] {
        guard let item = viewModel.item else { return [] }
        switch item.itemType {
        case .text:
            guard let text = item.plainText, !text.isEmpty else { return [] }
            return [text]
        case .image:
            if let image = viewModel.previewImage { return [image] }
            if let data = item.imageData, let image = NSImage(data: data) { return [image] }
            return []
        case .file:
            return (item.filePathsArray ?? []).map { URL(fileURLWithPath: $0) }
        }
    }

    // MARK: - Content Box

    private var contentBox: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(red: 0.078, green: 0.078, blue: 0.078))
            content
        }
        .frame(width: viewModel.contentBoxSize.width, height: viewModel.contentBoxSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(red: 0.169, green: 0.169, blue: 0.169), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var content: some View {
        if let preset = viewModel.preset {
            presetContent(preset: preset)
        } else if let item = viewModel.item {
            switch item.itemType {
            case .text: textContent(for: item)
            case .image: imageContent(for: item)
            case .file: fileContent(for: item)
            }
        }
    }

    private func presetContent(preset: RegexPreset) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preset.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            Text(preset.pattern)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func textContent(for item: ClipboardItemModel) -> some View {
        ScrollView {
            if let text = item.plainText, !text.isEmpty {
                Text(text)
                    .font(.system(size: PreviewLayout.fontSize))
                    .lineSpacing(0.5)
                    .foregroundColor(.white.opacity(bodyOpacity))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 13.5)
                    .padding(.vertical, 10)
            } else {
                emptyState
            }
        }
    }

    private func imageContent(for item: ClipboardItemModel) -> some View {
        Group {
            if let image = viewModel.previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(10)
            } else {
                emptyState
            }
        }
    }

    private func fileContent(for item: ClipboardItemModel) -> some View {
        ScrollView {
            if let paths = item.filePathsArray, !paths.isEmpty {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(paths.enumerated()), id: \.offset) { _, path in
                        fileRow(path: path)
                    }
                }
                .padding(10)
            } else {
                emptyState
            }
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text(String(localized: "mainpanel.empty.noMatches"))
                .font(.system(size: PreviewLayout.fontSize))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func fileRow(path: String) -> some View {
        HStack(spacing: 12) {
            AsyncFileIconView(filePath: path)

            VStack(alignment: .leading, spacing: 4) {
                let fileURL = URL(fileURLWithPath: path)
                Text(fileURL.lastPathComponent)
                    .font(.system(size: PreviewLayout.fontSize, weight: .medium))
                    .foregroundColor(.white.opacity(bodyOpacity))
                    .lineLimit(1)
                Text(path)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer()

            let fileURL = URL(fileURLWithPath: path)
            if !fileURL.pathExtension.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "tag")
                        .font(.system(size: 9))
                    Text(fileURL.pathExtension.uppercased())
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 0) {
            statsText
            Spacer(minLength: 0)
        }
        .padding(.top, 10)
        .padding(.leading, 11)
        .padding(.trailing, 7)
        .frame(height: 38, alignment: .top)
    }

    private var statsText: Text {
        var result = Text("")
        for (index, piece) in viewModel.statsPieces.enumerated() {
            if index > 0 {
                result = result + Text(" · ").foregroundColor(.white.opacity(0.26))
            }
            result = result + Text(piece).foregroundColor(.white.opacity(0.55))
        }
        return result.font(.system(size: PreviewLayout.fontSize))
    }
}

#Preview {
    let viewModel = PreviewViewModel()
    viewModel.updateItem(ClipboardItemModel(
        itemType: .text,
        plainText: "这是一段预览文本内容\n可以包含多行\n用于测试预览窗口的显示效果"
    ))
    return PreviewView(
        viewModel: viewModel,
        clipboardViewModel: ClipboardViewModel(),
        onClose: {},
        onEdit: {}
    )
}
