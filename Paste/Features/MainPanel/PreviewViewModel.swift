//
//  PreviewViewModel.swift
//  Paste
//
//  Preview window ViewModel — manages preview content state
//

import Foundation
import AppKit
import Combine

@MainActor
class PreviewViewModel: ObservableObject {
    @Published var item: ClipboardItemModel?
    @Published var preset: RegexPreset?
    @Published private(set) var previewImage: NSImage?
    @Published private(set) var previewImageSizeInfo: String?
    /// Footer statistics pieces, e.g. ["89 characters", "9 words", "1 line"].
    @Published private(set) var statsPieces: [String] = []
    /// Size of the content box (text/image/file area). The popover adds header/footer chrome around it.
    @Published var contentBoxSize: CGSize = PreviewLayout.minBoxSize

    /// Total size of the preview view hosted inside the popover.
    var popoverSize: CGSize {
        CGSize(
            width: contentBoxSize.width + PreviewLayout.horizontalChrome,
            height: contentBoxSize.height + PreviewLayout.verticalChrome
        )
    }

    func updateItem(_ newItem: ClipboardItemModel?) {
        item = newItem
        if newItem != nil { preset = nil }
        loadPreviewImage()
        statsPieces = Self.statsPieces(for: newItem, imageSizeInfo: previewImageSizeInfo)
    }

    func updatePreset(_ newPreset: RegexPreset?) {
        preset = newPreset
        if newPreset != nil { item = nil }
        previewImage = nil
        previewImageSizeInfo = nil
        statsPieces = []
    }

    func updateContentBoxSize(_ size: CGSize) {
        contentBoxSize = size
    }

    private func loadPreviewImage() {
        guard let item, item.itemType == .image else {
            previewImage = nil
            previewImageSizeInfo = nil
            return
        }
        if let data = ThumbnailCache.loadImageData(for: item.id) {
            previewImage = NSImage(data: data)
            if let dims = ThumbnailCache.imageDimensions(from: data) {
                previewImageSizeInfo = "\(dims.width) × \(dims.height)"
            }
        } else {
            previewImage = nil
            previewImageSizeInfo = nil
        }
    }

    // MARK: - Statistics

    /// Mirror of Paste's footer line: "N characters · N words · N lines".
    /// Words are split on spaces only (newlines do not separate words), lines are newline-separated.
    static func statsPieces(for item: ClipboardItemModel?, imageSizeInfo: String?) -> [String] {
        guard let item else { return [] }
        switch item.itemType {
        case .text:
            let text = item.plainText ?? ""
            let characters = text.count
            let words = text.split { $0 == " " || $0 == "\t" }.count
            let lines = text.components(separatedBy: "\n").count
            return [
                countString(characters, singular: "preview.stats.character", plural: "preview.stats.characters"),
                countString(words, singular: "preview.stats.word", plural: "preview.stats.words"),
                countString(lines, singular: "preview.stats.line", plural: "preview.stats.lines")
            ]
        case .image:
            return imageSizeInfo.map { [$0] } ?? []
        case .file:
            guard let count = item.fileCount else { return [] }
            return [countString(count, singular: "preview.stats.file", plural: "preview.stats.files")]
        }
    }

    private static let countFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()

    private static func countString(_ count: Int, singular: String, plural: String) -> String {
        let key = count == 1 ? singular : plural
        let formatted = countFormatter.string(from: NSNumber(value: count)) ?? "\(count)"
        return String(format: String(localized: String.LocalizationValue(key)), formatted)
    }
}

/// Layout constants matching Paste's preview popover measurements.
enum PreviewLayout {
    /// Minimum content box (popover window 416x342 = box + chrome below).
    static let minBoxSize = CGSize(width: 380, height: 240)
    /// Content view width - content box width (5pt inset each side in the
    /// hosting view; NSPopover adds 13pt per side, so the window is box + 36).
    static let horizontalChrome: CGFloat = 10
    /// Header (38) + footer region (38); NSPopover adds 13pt top/bottom, so
    /// the window is box + 102.
    static let verticalChrome: CGFloat = 76
    /// Text line pitch and vertical padding inside the content box.
    static let textLineHeight: CGFloat = 16
    static let textVerticalPadding: CGFloat = 20
    /// Horizontal text padding inside the content box (13.5pt each side).
    static let textHorizontalPadding: CGFloat = 27
    /// Preview body font size.
    static let fontSize: CGFloat = 13
}
