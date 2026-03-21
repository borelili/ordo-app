//
//  EditTagView.swift
//  TodoAPP
//
//  新建 & 编辑标签 — 卡片表单风格
//

import SwiftUI
import SwiftData

// MARK: - 共享卡片容器（EditListView / EditTagView 共用）

struct FormCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
    }
}

// MARK: - 颜色数据结构

struct TagColor: Identifiable {
    let id: Int
    let name: String   // 持久化到 Tag.color / TaskList.color 的字符串键
    let color: Color
}

// MARK: - 共享配色方案

enum AppPalette {
    static let colors: [TagColor] = [
        TagColor(id: 0,  name: "blue",   color: .blue),
        TagColor(id: 1,  name: "cyan",   color: .cyan),
        TagColor(id: 2,  name: "teal",   color: Color(.systemTeal)),
        TagColor(id: 3,  name: "green",  color: .green),
        TagColor(id: 4,  name: "mint",   color: Color(.systemMint)),
        TagColor(id: 5,  name: "yellow", color: .yellow),
        TagColor(id: 6,  name: "orange", color: .orange),
        TagColor(id: 7,  name: "red",    color: .red),
        TagColor(id: 8,  name: "pink",   color: .pink),
        TagColor(id: 9,  name: "purple", color: .purple),
        TagColor(id: 10, name: "indigo", color: .indigo),
        TagColor(id: 11, name: "brown",  color: .brown),
        TagColor(id: 12, name: "gray",   color: .gray),
    ]

    /// 根据颜色名称字符串查找对应 TagColor，找不到返回 blue
    static func tagColor(for name: String) -> TagColor {
        colors.first(where: { $0.name == name }) ?? colors[0]
    }

    /// 根据唯一整数 ID 查找对应 TagColor，找不到返回 blue
    static func tagColor(forID id: Int) -> TagColor {
        colors.first(where: { $0.id == id }) ?? colors[0]
    }
}

// MARK: - EditTagView

struct EditTagView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let tag: Tag?   // nil = 新建，non-nil = 编辑

    @State private var name: String
    @State private var selectedColorID: Int
    @FocusState private var nameFocused: Bool

    init(tag: Tag?) {
        self.tag          = tag
        _name             = State(initialValue: tag?.name ?? "")
        _selectedColorID  = State(initialValue: AppPalette.tagColor(for: tag?.color ?? "blue").id)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        previewPill
                        nameCard
                        colorCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(tag == nil ? "新建标签" : "编辑标签")
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

    // MARK: - Subviews

    private var previewPill: some View {
        let label = name.trimmingCharacters(in: .whitespaces)
        return HStack(spacing: 6) {
            Circle().fill(currentColor).frame(width: 10, height: 10)
            Text(label.isEmpty ? "标签名称" : label)
                .font(.subheadline.weight(.medium))
                .foregroundColor(label.isEmpty ? .secondary : .primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(currentColor.opacity(0.12))
                .overlay(Capsule().stroke(currentColor.opacity(0.25), lineWidth: 1))
        )
        .animation(.easeInOut(duration: 0.15), value: selectedColorID)
    }

    private var nameCard: some View {
        FormCard {
            VStack(alignment: .leading, spacing: 6) {
                cardLabel("名称")
                TextField("输入标签名称", text: $name)
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
        if let tag {
            tag.name  = trimmed
            tag.color = colorName
        } else {
            modelContext.insert(Tag(name: trimmed, color: colorName))
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - ColorDotButton（共享）

struct ColorDotButton: View {
    let color: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 36, height: 36)
                    .shadow(color: isSelected ? color.opacity(0.5) : .clear, radius: 6, y: 2)
                if isSelected {
                    Circle().strokeBorder(.white, lineWidth: 2.5).frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
