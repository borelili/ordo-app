//
//  ListDashboardView.swift
//  TodoAPP
//
//  规划页：
//  · Section 1 — 我的列表摘要（紧凑卡片，仅展示名称 + 待办数）
//  · Section 2 — 奥德赛计划入口（大卡，展示全局统计）
//
//  注意：清单页的完整列表内容仍在 ContentView / SidebarHomeView 中展示；
//        本页只是摘要入口，不重复渲染完整列表。
//

import SwiftUI
import SwiftData

// MARK: - 导航目的地（Hashable 枚举）

enum PlanningNavDest: Hashable {
    case list(TaskList)
    case odyssey
}

// MARK: - ListDashboardView（规划）

struct ListDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var odysseyStore: OdysseyStore   // 由 RootView 注入
    @Query(sort: \TaskList.sortOrder) private var taskLists: [TaskList]

    @State private var navPath: [PlanningNavDest] = []

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── Section 1: 我的列表摘要 ─────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("我的列表", icon: "square.grid.2x2.fill")

                        if taskLists.isEmpty {
                            emptyListsHint
                        } else {
                            LazyVGrid(columns: columns, spacing: 14) {
                                ForEach(taskLists) { list in
                                    ListSummaryCard(list: list) {
                                        navPath.append(.list(list))
                                    }
                                }
                            }
                        }
                    }

                    // ── Section 2: 奥德赛计划 ──────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("奥德赛计划", icon: "map.fill")
                        OdysseyModuleCard(store: odysseyStore) {
                            navPath.append(.odyssey)
                        }
                    }

                }
                .padding(.horizontal, DS.paddingScreen)
                .padding(.top, DS.spacingMD)
            }
            // 统一底部避让
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: DS.homeBottomInset)
            }
            .navigationTitle("规划")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.clear)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: PlanningNavDest.self) { dest in
                switch dest {
                case .list(let list):
                    ListDashboardDetailView(list: list)
                case .odyssey:
                    OdysseyPlanView()
                        .environmentObject(theme)
                        .environmentObject(odysseyStore)
                }
            }
        }
        .environmentObject(odysseyStore)
        .environment(\.odysseyStore, odysseyStore)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.current.primaryAccent)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.current.textSecondary)
        }
    }

    // MARK: - 空状态提示

    private var emptyListsHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle")
                .foregroundStyle(theme.current.primaryAccent)
            Text("前往「清单」标签新建列表")
                .font(.subheadline)
                .foregroundStyle(theme.current.textSecondary)
        }
        .padding(DS.paddingCard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                    .strokeBorder(theme.current.cardBorderColor, lineWidth: 1)
            }
        )
    }
}

// MARK: - ListSummaryCard（紧凑摘要卡片，无任务预览，无快捷添加）

struct ListSummaryCard: View {
    @Query private var pendingTasks: [Task]
    @EnvironmentObject private var theme: ThemeManager

    let list: TaskList
    let onTap: () -> Void

    init(list: TaskList, onTap: @escaping () -> Void) {
        self.list = list
        self.onTap = onTap
        let id = list.id
        _pendingTasks = Query(
            filter: #Predicate<Task> { $0.taskList?.id == id && !$0.isCompleted },
            sort: \Task.order
        )
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                // 图标 + 待办数徽章
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(list.colorValue.opacity(0.20))
                            .frame(width: 36, height: 36)
                        Image(systemName: list.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(list.colorValue)
                    }

                    Spacer()

                    if pendingTasks.count > 0 {
                        Text("\(pendingTasks.count)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(list.colorValue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(list.colorValue.opacity(0.18)))
                    }
                }

                // 列表名
                Text(list.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.current.textPrimary)
                    .lineLimit(1)

                // 状态描述
                Text(pendingTasks.isEmpty ? "已全部完成 ✓" : "\(pendingTasks.count) 项待办")
                    .font(.caption)
                    .foregroundStyle(pendingTasks.isEmpty
                                     ? theme.current.successColor
                                     : theme.current.textSecondary)
            }
            .padding(DS.paddingCard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                        .fill(list.colorValue.opacity(0.05))
                    RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                        .strokeBorder(list.colorValue.opacity(0.20), lineWidth: 1)
                }
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - OdysseyModuleCard（奥德赛计划摘要入口卡片）

struct OdysseyModuleCard: View {
    @EnvironmentObject private var theme: ThemeManager
    @ObservedObject var store: OdysseyStore
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                // 标题栏
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.current.primaryAccent)
                        Text("奥德赛计划")
                            .font(.headline)
                            .foregroundStyle(theme.current.textPrimary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.current.textMuted)
                }

                // 当前聚焦路径
                if let focused = store.focusedPath {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(theme.current.primaryAccent)
                                .frame(width: 30, height: 30)
                            Text(focused.label)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("当前聚焦")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(theme.current.primaryAccent)
                            Text(focused.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.current.textPrimary)
                        }
                    }
                } else {
                    Text("尚未设置聚焦路径")
                        .font(.subheadline)
                        .foregroundStyle(theme.current.textSecondary)
                }

                Divider()
                    .background(theme.current.divider)

                // 统计行
                HStack(spacing: 0) {
                    OdysseyStatItem(
                        value: store.activePaths.count,
                        label: "路径",
                        icon: "map"
                    )
                    Spacer()
                    OdysseyStatItem(
                        value: store.totalProjectCount,
                        label: "项目",
                        icon: "folder"
                    )
                    Spacer()
                    OdysseyStatItem(
                        value: store.totalTaskCount,
                        label: "关联任务",
                        icon: "checkmark.square"
                    )
                }
            }
            .padding(DS.paddingCard)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                        .fill(theme.current.primaryAccent.opacity(0.06))
                    RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                        .strokeBorder(theme.current.primaryAccent.opacity(0.25), lineWidth: 1)
                }
            )
            .cardShadow(DS.Shadow.card)
        }
        .buttonStyle(.plain)
    }
}

private struct OdysseyStatItem: View {
    @EnvironmentObject private var theme: ThemeManager
    let value: Int
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(theme.current.primaryAccent)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(value)")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(theme.current.textPrimary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(theme.current.textSecondary)
            }
        }
    }
}

// MARK: - ListDashboardDetailView

struct ListDashboardDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let list: TaskList

    @Query private var tasks: [Task]
    @State private var showingAdd = false

    init(list: TaskList) {
        self.list = list
        let id = list.id
        _tasks = Query(
            filter: #Predicate<Task> { $0.taskList?.id == id && !$0.isCompleted },
            sort: \Task.order
        )
    }

    var body: some View {
        Group {
            if tasks.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: list.icon)
                        .font(.system(size: 40))
                        .foregroundColor(list.colorValue.opacity(0.5))
                    Text("该列表暂无待办任务")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(tasks) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            TaskRowView(task: task)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.large)
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            QuickAddTaskView(defaultList: list)
                .environment(\.modelContext, modelContext)
        }
    }
}
