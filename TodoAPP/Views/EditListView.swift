//
//  EditListView.swift
//  TodoAPP
//
//  新建 & 编辑列表 — 卡片表单风格
//

import SwiftUI
import SwiftData

struct EditListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let list: TaskList?   // nil = 新建，non-nil = 编辑

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColorID: Int
    @FocusState private var nameFocused: Bool

    // 5 列 × 4 行 = 20 个常用图标
    private let icons: [(id: String, label: String)] = [
        ("list.bullet",        "清单"),   ("tray.fill",          "收件箱"),
        ("doc.fill",           "文档"),   ("note.text",          "笔记"),
        ("checklist",          "待办"),   ("house.fill",         "家"),
        ("cart.fill",          "购物"),   ("heart.fill",         "心愿"),
        ("airplane",           "旅行"),   ("figure.run",         "运动"),
        ("briefcase.fill",     "工作"),   ("folder.fill",        "文件夹"),
        ("envelope.fill",      "邮件"),   ("person.2.fill",      "团队"),
        ("graduationcap.fill", "学习"),   ("star.fill",          "收藏"),
        ("flag.fill",          "重要"),   ("bookmark.fill",      "书签"),
        ("gamecontroller.fill","游戏"),   ("book.fill",          "阅读"),
    ]

    init(list: TaskList?) {
        self.list      = list
        _name            = State(initialValue: list?.name  ?? "")
        _selectedIcon    = State(initialValue: list?.icon  ?? "list.bullet")
        _selectedColorID = State(initialValue: AppPalette.tagColor(for: list?.color ?? "blue").id)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        previewBadge
                        nameCard
                        colorCard
                        iconCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(list == nil ? "新建列表" : "编辑列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.secondary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, currentColor)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { nameFocused = true }
        }
    }

    // MARK: - Preview Badge

    private var previewBadge: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(currentColor.opacity(0.15))
                    .frame(width: 68, height: 68)
                Image(systemName: selectedIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(currentColor)
            }
            Text(name.trimmingCharacters(in: .whitespaces).isEmpty ? "列表名称" : name)
                .font(.headline)
                .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .primary)
                .lineLimit(1)
        }
        .animation(.easeInOut(duration: 0.15), value: selectedColorID)
        .animation(.easeInOut(duration: 0.15), value: selectedIcon)
    }

    // MARK: - Name Card

    private var nameCard: some View {
        FormCard {
            VStack(alignment: .leading, spacing: 6) {
                cardLabel("名称")
                TextField("输入列表名称", text: $name)
                    .focused($nameFocused)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color(.systemGray6)))
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
            }
        }
    }

    // MARK: - Color Card

    private var colorCard: some View {
        FormCard {
            VStack(alignment: .leading, spacing: 10) {
                cardLabel("颜色")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(AppPalette.colors) { item in
                            ColorDotButton(color: item.color,
                                           isSelected: selectedColorID == item.id) {
                                withAnimation(.easeInOut(duration: 0.15)) { selectedColorID = item.id }
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }
                .padding(.bottom, 14)
            }
        }
    }

    // MARK: - Icon Card

    private var iconCard: some View {
        FormCard {
            VStack(alignment: .leading, spacing: 10) {
                cardLabel("图标")
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                    spacing: 10
                ) {
                    ForEach(icons, id: \.id) { item in
                        Button {
                            withAnimation(.easeInOut(duration: 0.12)) { selectedIcon = item.id }
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selectedIcon == item.id
                                              ? currentColor.opacity(0.18)
                                              : Color(.systemGray6))
                                        .frame(height: 46)
                                    Image(systemName: item.id)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(selectedIcon == item.id
                                                         ? currentColor : .secondary)
                                }
                                Text(item.label)
                                    .font(.system(size: 9))
                                    .foregroundColor(selectedIcon == item.id ? currentColor : .secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
            }
        }
    }

    // MARK: - Helpers

    private func cardLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 14)
            .padding(.top, 14)
    }

    private var currentColor: Color { AppPalette.tagColor(forID: selectedColorID).color }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let colorName = AppPalette.tagColor(forID: selectedColorID).name
        if let list {
            list.name  = trimmed
            list.icon  = selectedIcon
            list.color = colorName
        } else {
            let maxOrder = (try? modelContext.fetch(FetchDescriptor<TaskList>()))?.map(\.sortOrder).max() ?? -1
            let newList = TaskList(name: trimmed, icon: selectedIcon, color: colorName)
            newList.sortOrder = maxOrder + 1
            modelContext.insert(newList)
        }
        try? modelContext.save()
        dismiss()
    }
}
