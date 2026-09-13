//
//  PanelTopBarView.swift
//  Stash
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

    var body: some View {
        HStack(spacing: 10) {
            SearchFieldView(viewModel: viewModel, searchFieldFocused: $searchFieldFocused)

            ListMenuButton(viewModel: viewModel)

            PinboardChipsView(viewModel: viewModel)

            AddMenuButton(viewModel: viewModel)

            if viewModel.panelMode == .pasteStack {
                ModeChip(title: String(localized: "mainpanel.pasteStack.title"),
                         icon: "rectangle.stack.fill",
                         tint: .accentColor) {
                    viewModel.exitPasteStack()
                }
            }

            Spacer(minLength: 0)

            // Paste-target app indicator.
            if !viewModel.pasteTargetAppName.isEmpty {
                HStack(spacing: 4) {
                    if let icon = viewModel.pasteTargetAppIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 14, height: 14)
                    }
                    Text(String(format: String(localized: "mainpanel.pasteTarget.format"), viewModel.pasteTargetAppName))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel(String(format: String(localized: "accessibility.mainpanel.pasteTarget"), viewModel.pasteTargetAppName))
            }

            if !viewModel.isAboutMode {
                Text(String(format: String(localized: "mainpanel.itemCountFormat"), viewModel.effectiveDisplayItems.count))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            ActionsMenuButton(viewModel: viewModel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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

// MARK: - Current list menu ("Clipboard" + pinboards)

struct ListMenuButton: View {
    @ObservedObject var viewModel: ClipboardViewModel

    private var currentListName: String {
        if let idx = viewModel.activePinboardIndex {
            return AppSettings.pinboardName(at: idx)
        }
        return String(localized: "mainpanel.list.clipboard")
    }

    var body: some View {
        Menu {
            Button {
                viewModel.exitPinboard()
                viewModel.isAboutMode = false
            } label: {
                Label(String(localized: "mainpanel.list.clipboardHistory"), systemImage: "clock")
            }
            if AppSettings.pinboardCount > 0 {
                Divider()
                ForEach(0..<AppSettings.pinboardCount, id: \.self) { index in
                    Button {
                        viewModel.selectedType = nil
                        viewModel.isRegexPresetMode = false
                        viewModel.isAboutMode = false
                        viewModel.showPinboard(index: index)
                    } label: {
                        Label(AppSettings.pinboardName(at: index), systemImage: "circle.fill")
                            .tint(AppSettings.pinboardColor(at: index))
                    }
                }
            }
            Divider()
            Button { viewModel.createNewPinboard() } label: {
                Label(String(localized: "mainpanel.context.createPinboard"), systemImage: "plus")
            }
        } label: {
            HStack(spacing: 5) {
                if let idx = viewModel.activePinboardIndex {
                    Circle()
                        .fill(AppSettings.pinboardColor(at: idx))
                        .frame(width: 8, height: 8)
                } else {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .medium))
                }
                Text(currentListName)
                    .font(.system(size: 12, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

// MARK: - Pinboard chips

struct PinboardChipsView: View {
    @ObservedObject var viewModel: ClipboardViewModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<AppSettings.pinboardCount, id: \.self) { index in
                Button {
                    if viewModel.activePinboardIndex == index {
                        viewModel.exitPinboard()
                    } else {
                        viewModel.selectedType = nil
                        viewModel.isRegexPresetMode = false
                        viewModel.isAboutMode = false
                        viewModel.showPinboard(index: index)
                    }
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(AppSettings.pinboardColor(at: index))
                            .frame(width: 8, height: 8)
                        Text(AppSettings.pinboardName(at: index))
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(viewModel.activePinboardIndex == index
                                ? AppSettings.pinboardColor(at: index).opacity(0.18)
                                : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(AppSettings.pinboardName(at: index)))
            }
        }
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
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 26, height: 26)
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
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 26, height: 26)
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
                ListMenuButton(viewModel: viewModel)
                PinboardChipsView(viewModel: viewModel)
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
