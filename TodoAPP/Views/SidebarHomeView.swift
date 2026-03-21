//
//  SidebarHomeView.swift
//  TodoAPP
//
//  Created on 2026/02/23
//
//  iPhone 侧边栏主页：3 个圆角卡片分组
//    1. 智能列表  2. 我的列表  3. 我的标签
//

import SwiftUI
import SwiftData

struct SidebarHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var theme: ThemeManager
    @Query private var taskLists: [TaskList]
    @Query private var tags: [Tag]
    @Query private var tasks: [Task]

    // 由 ContentView 传入，双向绑定（iPad/macOS 直接更新 selection）
    @Binding var selectedFilter: ContentView.TaskFilter
    @Binding var selectedList: TaskList?
    @Binding var selectedTag: Tag?
    @Binding var editingList: TaskList?
    @Binding var showingAddList: Bool
    @Binding var showingTagManagement: Bool
    @Binding var showingSettings: Bool
    @Binding var renamingList: TaskList?
    @Binding var renameText: String
    @Binding var showingRenameList: Bool

    let currentDate: Date
    let onDeleteList: (TaskList) -> Void
    /// iPhone push 导航回调（nil 时为 iPad/macOS 模式，直接更新 selection）
    var onNavigate: ((ContentView.SmartListDestination) -> Void)? = nil

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                smartListCard
                myListsCard
                myTagsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        // 统一底部避让
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: DS.homeBottomInset)
        }
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    // MARK: - 智能列表卡片

    private var smartListCard: some View {
        CardContainer(title: "智能列表") {
            ForEach(Array(ContentView.TaskFilter.allCases.enumerated()), id: \.element) { index, filter in
                if index > 0 { Divider().padding(.leading, 48) }
                SidebarSmartListRow(
                    filter: filter,
                    isSelected: selectedFilter == filter && selectedList == nil && selectedTag == nil,
                    badge: ListBadgeService.count(for: filter, tasks: tasks, now: currentDate)
                ) {
                    let dest = ContentView.SmartListDestination.filter(filter)
                    if let navigate = onNavigate {
                        navigate(dest)
                    } else {
                        selectedFilter = filter
                        selectedList  = nil
                        selectedTag   = nil
                    }
                }
            }
        }
    }

    // MARK: - 我的列表卡片

    private var myListsCard: some View {
        CardContainer(title: "我的列表") {
            let sorted = taskLists.sorted { $0.sortOrder < $1.sortOrder }
            if sorted.isEmpty {
                emptyHint("暂无列表，点击 + 新建")
            } else {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, list in
                    if index > 0 { Divider().padding(.leading, 48) }
                    SidebarListRow(
                        icon: list.icon,
                        color: list.colorValue,
                        name: list.name,
                        isSelected: selectedList?.id == list.id,
                        badge: ListBadgeService.count(for: list)
                    ) {
                        let dest = ContentView.SmartListDestination.customList(list)
                        if let navigate = onNavigate {
                            navigate(dest)
                        } else {
                            selectedFilter = .all
                            selectedList   = list
                            selectedTag    = nil
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { onDeleteList(list) } label: {
                            Label("删除", systemImage: "trash")
                        }
                        Button { editingList = list } label: {
                            Label("编辑", systemImage: "slider.horizontal.3")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button { editingList = list } label: {
                            Label("编辑", systemImage: "slider.horizontal.3")
                        }
                        Button {
                            renamingList = list
                            renameText   = list.name
                            showingRenameList = true
                        } label: {
                            Label("重命名", systemImage: "pencil")
                        }
                        Button(role: .destructive) { onDeleteList(list) } label: {
                            Label("删除列表", systemImage: "trash")
                        }
                    }
                }
            }

            // 底部操作行
            Divider()

            SidebarActionRow(icon: "plus.circle.fill", color: .blue, title: "新建列表") {
                showingAddList = true
            }
        }
    }

    // MARK: - 我的标签卡片

    private var myTagsCard: some View {
        CardContainer(title: "我的标签") {
            if tags.isEmpty {
                emptyHint("暂无标签，在「标签管理」中新建")
            } else {
                ForEach(Array(tags.enumerated()), id: \.element.id) { index, tag in
                    if index > 0 { Divider().padding(.leading, 48) }
                    SidebarListRow(
                        icon: "tag.fill",
                        color: tag.colorValue,
                        name: tag.name,
                        isSelected: selectedTag?.id == tag.id,
                        badge: ListBadgeService.count(for: tag)
                    ) {
                        let dest = ContentView.SmartListDestination.tag(tag)
                        if let navigate = onNavigate {
                            navigate(dest)
                        } else {
                            selectedTag    = tag
                            selectedList   = nil
                            selectedFilter = .all
                        }
                    }
                }
            }

            Divider()

            SidebarActionRow(icon: "tag.fill", color: .orange, title: "标签管理") {
                showingTagManagement = true
            }
            Divider().padding(.leading, 48)
            SidebarActionRow(icon: "gearshape.fill", color: .gray, title: "列表设置") {
                showingSettings = true
            }
        }
    }

    // MARK: - Helpers

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
    }
}

// MARK: - CardContainer

private struct CardContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.current.textSecondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            VStack(spacing: 0) {
                content()
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(theme.current.cardSecondaryBackground)
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(theme.current.cardBorderColor, lineWidth: 1)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - SidebarSmartListRow

private struct SidebarSmartListRow: View {
    let filter: ContentView.TaskFilter
    let isSelected: Bool
    let badge: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 图标圆形背景
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(filterColor.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: filterIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(filterColor)
                }

                Text(filter.rawValue)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                if badge > 0 {
                    BadgeView(count: badge, color: filterColor)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(isSelected ? filterColor.opacity(0.10) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private var filterIcon: String {
        switch filter {
        case .all:       return "tray"
        case .today:     return "calendar"
        case .upcoming:  return "calendar.badge.clock"
        case .overdue:   return "exclamationmark.triangle"
        case .scheduled: return "calendar.circle"
        case .flagged:   return "flag.fill"
        case .noDate:    return "calendar.badge.minus"
        case .completed: return "checkmark.circle"
        }
    }

    private var filterColor: Color {
        switch filter {
        case .all:       return .blue
        case .today:     return .green
        case .upcoming:  return .orange
        case .overdue:   return .red
        case .scheduled: return .purple
        case .flagged:   return .pink
        case .noDate:    return .gray
        case .completed: return Color(.systemTeal)
        }
    }
}

// MARK: - SidebarListRow （自定义列表 & 标签 通用）

private struct SidebarListRow: View {
    let icon: String
    let color: Color
    let name: String
    let isSelected: Bool
    let badge: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(color)
                }

                Text(name)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                Spacer()

                if badge > 0 {
                    BadgeView(count: badge, color: color)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(isSelected ? color.opacity(0.10) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SidebarActionRow

private struct SidebarActionRow: View {
    let icon: String
    let color: Color
    let title: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(color)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - BadgeView

struct BadgeView: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, count > 9 ? 7 : 6)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(color.opacity(0.85))
            )
            .fixedSize()
    }
}
