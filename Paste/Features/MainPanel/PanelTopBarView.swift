//
//  PanelTopBarView.swift
//  Copydock
//
//  Toolbar for the main panel, styled after Paste for macOS:
//  search field on the left, then the current list ("Clipboard") menu,
//  pinboard chips with color dots, an add (+) menu, and an actions (⋯) menu.
//

import SwiftUI
import AppKit

// MARK: - PanelTopBarView (horizontal, for top/bottom panels)

struct PanelTopBarView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @FocusState private var searchFieldFocused: Bool
    @State private var searchVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)

            // Search: a bare magnifier like Paste; expands into the field on click.
            if searchVisible || !viewModel.searchText.isEmpty {
                SearchFieldView(viewModel: viewModel, searchFieldFocused: $searchFieldFocused)
            } else {
                Button {
                    searchVisible = true
                    searchFieldFocused = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(width: 34, height: 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("accessibility.mainpanel.search"))
            }

            ListChipsView(viewModel: viewModel)

            AddMenuButton(viewModel: viewModel)

            if viewModel.panelMode == .pasteStack {
                ModeChip(title: String(localized: "mainpanel.pasteStack.title"),
                         icon: "rectangle.stack.fill",
                         tint: .accentColor) {
                    viewModel.exitPasteStack()
                }
            }

            Spacer(minLength: 0)

            ActionsMenuButton(viewModel: viewModel)
        }
        .frame(height: PanelLayout.topBarHeightH)
        .padding(.horizontal, PanelLayout.panelPadding)
    }
}

// MARK: - Search field with filters menu

struct SearchFieldView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    var searchFieldFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))

            TextField("mainpanel.search.placeholder", text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused(searchFieldFocused)
                .onChange(of: searchFieldFocused.wrappedValue) { _, new in viewModel.focusSearch = new }
                .onChange(of: viewModel.focusSearch) { _, new in if searchFieldFocused.wrappedValue != new { searchFieldFocused.wrappedValue = new } }
                .accessibilityLabel(Text("accessibility.mainpanel.search"))
                .accessibilityHint(Text("accessibility.mainpanel.search.hint"))

            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("accessibility.mainpanel.clearAll"))
            }

            FiltersMenuButton(viewModel: viewModel)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
        )
        .frame(width: 260)
    }
}

// MARK: - Filters menu (type, custom categories, regex presets)

struct FiltersMenuButton: View {
    @ObservedObject var viewModel: ClipboardViewModel

    private var isFiltering: Bool {
        viewModel.selectedType != nil || viewModel.isRegexPresetMode || viewModel.selectedCustomTypeId != nil
    }

    var body: some View {
        Menu {
            Button {
                viewModel.selectedType = nil
                viewModel.isRegexPresetMode = false
                viewModel.selectedCustomTypeId = nil
            } label: {
                Label(String(localized: "mainpanel.filter.all"), systemImage: "square.grid.2x2")
            }
            Button { viewModel.selectedType = .text } label: {
                Label(String(localized: "mainpanel.filter.text"), systemImage: "doc.text")
            }
            Button { viewModel.selectedType = .image } label: {
                Label(String(localized: "mainpanel.filter.image"), systemImage: "photo")
            }
            Button { viewModel.selectedType = .file } label: {
                Label(String(localized: "mainpanel.filter.file"), systemImage: "folder")
            }
            Button { viewModel.isRegexPresetMode = true } label: {
                Label(String(localized: "mainpanel.filter.regex"), systemImage: "curlybraces")
            }
            if !viewModel.customTypes.isEmpty {
                Divider()
                ForEach(viewModel.customTypes) { custom in
                    Button { viewModel.selectedCustomTypeId = custom.id } label: {
                        Label(custom.name, systemImage: "tag")
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(isFiltering ? .accentColor : .secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 18)
        .accessibilityLabel(Text("accessibility.mainpanel.filters"))
    }
}

// MARK: - List chips (Clipboard + pinboards, Paste-style)

struct ListChipsView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @State private var contentWidth: CGFloat = 300

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ListChip(
                    title: String(localized: "mainpanel.list.clipboard"),
                    icon: "clock",
                    dotColor: nil,
                    isSelected: viewModel.activePinboardIndex == nil && !viewModel.isAboutMode
                ) {
                    viewModel.exitPinboard()
                    viewModel.isAboutMode = false
                }
                ForEach(0..<AppSettings.pinboardCount, id: \.self) { index in
                    ListChip(
                        title: AppSettings.pinboardName(at: index),
                        icon: nil,
                        dotColor: AppSettings.pinboardColor(at: index),
                        isSelected: viewModel.activePinboardIndex == index
                    ) {
                        if viewModel.activePinboardIndex == index {
                            viewModel.exitPinboard()
                        } else {
                            viewModel.selectedType = nil
                            viewModel.isRegexPresetMode = false
                            viewModel.isAboutMode = false
                            viewModel.showPinboard(index: index)
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { contentWidth = $0 }
        }
        .frame(width: min(contentWidth, 640))
    }
}

private struct ListChip: View {
    let title: String
    let icon: String?
    let dotColor: Color?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                }
                if let dotColor {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 8, height: 8)
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : Color(white: 0.82))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isSelected ? Color.white.opacity(0.09) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.white.opacity(0.18) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}

// MARK: - Add (+) menu

struct AddMenuButton: View {
    @ObservedObject var viewModel: ClipboardViewModel

    var body: some View {
        Menu {
            Button { viewModel.showNewItemSheet = true } label: {
                Label(String(localized: "mainpanel.newItem.title"), systemImage: "doc.text")
            }
            Button { viewModel.createNewPinboard() } label: {
                Label(String(localized: "mainpanel.context.createPinboard"), systemImage: "pin")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel(Text("accessibility.mainpanel.add"))
    }
}

// MARK: - Actions (⋯) menu

struct ActionsMenuButton: View {
    @ObservedObject var viewModel: ClipboardViewModel

    var body: some View {
        Menu {
            Button {
                NotificationCenter.default.post(name: AppNotification.requestTogglePause, object: nil)
            } label: {
                Label(String(localized: "status.menu.pause"), systemImage: "pause.circle")
            }
            Divider()
            Button {
                NotificationCenter.default.post(name: AppNotification.requestShowPreferences, object: nil)
            } label: {
                Label(String(localized: "status.menu.preferences"), systemImage: "gear")
            }
            Button { viewModel.isAboutMode = true } label: {
                Label(String(localized: "status.menu.about"), systemImage: "info.circle")
            }
            Divider()
            Button(role: .destructive) { viewModel.clearAll() } label: {
                Label(String(localized: "mainpanel.clearAll.help"), systemImage: "trash")
            }
            Divider()
            Button {
                NotificationCenter.default.post(name: AppNotification.requestQuit, object: nil)
            } label: {
                Label(String(localized: "status.menu.quit"), systemImage: "power")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .accessibilityLabel(Text("accessibility.mainpanel.actions"))
    }
}

// MARK: - Mode chip (Paste Stack indicator)

struct ModeChip: View {
    let title: String
    let icon: String
    let tint: Color
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(title)
                .font(.system(size: 11, weight: .semibold))
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .foregroundColor(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - PanelTopBarVerticalView (for left/right panels, compact 2-row layout)

struct PanelTopBarVerticalView: View {
    @ObservedObject var viewModel: ClipboardViewModel
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                SearchFieldView(viewModel: viewModel, searchFieldFocused: $searchFieldFocused)
                    .frame(maxWidth: .infinity)
                AddMenuButton(viewModel: viewModel)
                ActionsMenuButton(viewModel: viewModel)
            }

            HStack(spacing: 6) {
                ListChipsView(viewModel: viewModel)
                if viewModel.panelMode == .pasteStack {
                    ModeChip(title: String(localized: "mainpanel.pasteStack.title"),
                             icon: "rectangle.stack.fill",
                             tint: .accentColor) {
                        viewModel.exitPasteStack()
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
