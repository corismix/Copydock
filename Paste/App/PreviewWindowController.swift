//
//  PreviewWindowController.swift
//  Paste
//
//  Preview window controller — manages show/hide of the preview popover
//

import AppKit
import SwiftUI

@MainActor
final class PreviewWindowController {
    private var popover: NSPopover?
    private weak var mainPanel: NSPanel?
    private let viewModel: PreviewViewModel
    private let clipboardViewModel: ClipboardViewModel
    private let onClose: () -> Void
    private let onEdit: () -> Void

    init(clipboardViewModel: ClipboardViewModel,
         onClose: @escaping () -> Void,
         onEdit: @escaping () -> Void) {
        self.viewModel = PreviewViewModel()
        self.clipboardViewModel = clipboardViewModel
        self.onClose = onClose
        self.onEdit = onEdit
    }

    // MARK: - Public API

    func showPreview(for item: ClipboardItemModel?, preset: RegexPreset?, selectedIndex: Int, relativeTo mainPanel: NSPanel) {
        self.mainPanel = mainPanel
        guard item != nil || preset != nil else { return }

        viewModel.updatePreset(nil)
        viewModel.updateItem(nil)
        if let item = item {
            viewModel.updateItem(item)
        } else if let preset = preset {
            viewModel.updatePreset(preset)
        }

        guard let screen = mainPanel.screen ?? NSScreen.main,
              let contentView = mainPanel.contentView else { return }

        viewModel.updateContentBoxSize(contentBoxSize(for: item, preset: preset, screen: screen))

        let anchor = anchorRect(selectedIndex: selectedIndex, panel: mainPanel)
        let edge = preferredEdge()

        if let popover = popover, popover.isShown {
            popover.contentSize = viewModel.popoverSize
            popover.positioningRect = anchor
            // Re-showing an already visible popover repositions it without flicker.
            popover.show(relativeTo: anchor, of: contentView, preferredEdge: edge)
            return
        }

        let popover = NSPopover()
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: PreviewView(
                viewModel: viewModel,
                clipboardViewModel: clipboardViewModel,
                onClose: onClose,
                onEdit: onEdit
            )
        )
        popover.contentSize = viewModel.popoverSize
        popover.show(relativeTo: anchor, of: contentView, preferredEdge: edge)
        self.popover = popover
    }

    func hidePreview() {
        guard let popover = popover else { return }
        popover.performClose(nil)
        self.popover = nil
    }

    var isVisible: Bool {
        popover?.isShown ?? false
    }

    // MARK: - Sizing

    /// Content box size: min 380x240, max half the screen; text items size to their content.
    private func contentBoxSize(for item: ClipboardItemModel?, preset: RegexPreset?, screen: NSScreen) -> CGSize {
        let maxSize = CGSize(width: screen.frame.width / 2, height: screen.frame.height / 2)
        let minSize = PreviewLayout.minBoxSize

        guard let item, preset == nil, item.itemType == .text else {
            return minSize
        }

        let text = item.plainText ?? ""
        let lines = text.components(separatedBy: "\n")
        let longestLine = lines.map(Self.lineWidth).max() ?? 0
        let width = longestLine + PreviewLayout.textHorizontalPadding
        let height = CGFloat(lines.count) * PreviewLayout.textLineHeight + PreviewLayout.textVerticalPadding

        return CGSize(
            width: min(max(width, minSize.width), maxSize.width),
            height: min(max(height, minSize.height), maxSize.height)
        )
    }

    private static func lineWidth(_ line: String) -> CGFloat {
        guard !line.isEmpty else { return 0 }
        let font = NSFont.systemFont(ofSize: PreviewLayout.fontSize)
        return ceil((line as NSString).size(withAttributes: [.font: font]).width)
    }

    // MARK: - Positioning

    /// Screen-coordinate rect of the selected card, converted into the panel's content view.
    private func anchorRect(selectedIndex: Int, panel: NSPanel) -> NSRect {
        let screen = panel.screen ?? NSScreen.main!
        let cardSize = PanelLayout.cardSize(position: AppSettings.panelPosition, screenSize: screen.frame.size)
        let cardPos = calculateCardPosition(selectedIndex: selectedIndex, mainPanel: panel, cardSize: cardSize)
        let screenRect = NSRect(x: cardPos.x, y: cardPos.y, width: cardSize.width, height: cardSize.height)
        let windowRect = panel.convertFromScreen(screenRect)
        return panel.contentView?.convert(windowRect, from: nil) ?? windowRect
    }

    /// Returns the bottom-left screen coordinate of the selected card in AppKit coordinates (origin at bottom-left of screen).
    private func calculateCardPosition(selectedIndex: Int, mainPanel: NSPanel, cardSize: CGSize) -> (x: CGFloat, y: CGFloat) {
        let f = mainPanel.frame
        let position = AppSettings.panelPosition
        let topBarH: CGFloat = position == .left || position == .right
            ? PanelLayout.topBarHeightV : PanelLayout.topBarHeightH

        switch position {
        case .bottom:
            // Horizontal layout, panel at bottom.
            let cardX = PanelLayout.panelPadding + CGFloat(selectedIndex) * (cardSize.width + PanelLayout.cardSpacing)
            let screenX = f.minX + cardX
            let screenY = f.maxY - topBarH - cardSize.height
            return (screenX, screenY)
        case .top:
            // Horizontal layout, panel at top.
            let cardX = PanelLayout.panelPadding + CGFloat(selectedIndex) * (cardSize.width + PanelLayout.cardSpacing)
            let screenX = f.minX + cardX
            let screenY = f.minY + topBarH  // SwiftUI top bar grows downward; AppKit Y is measured from the bottom.
            return (screenX, screenY)
        case .left, .right:
            // Vertical layout, cards from panel top downward.
            let cardY = f.maxY - topBarH - PanelLayout.vertPadding
                        - CGFloat(selectedIndex + 1) * cardSize.height
                        - CGFloat(selectedIndex) * PanelLayout.cardSpacing
            let screenX = f.minX + PanelLayout.panelPadding
            return (screenX, cardY)
        }
    }

    private func preferredEdge() -> NSRectEdge {
        switch AppSettings.panelPosition {
        case .bottom: return .maxY
        case .top: return .minY
        case .left: return .maxX
        case .right: return .minX
        }
    }
}
