// OdysseyOverviewView.swift
// TickTick — 奥德赛各维度总览页
//
// 由首页统计块导航进入，四个视图：路径 / 目标 / 项目 / 关联任务

import SwiftUI
import SwiftData

// MARK: - OdysseyOverviewView（路由分发）

struct OdysseyOverviewView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore
    let tab: OdysseyOverviewTab

    var body: some View {
        Group {
            switch tab {
            case .paths:    OdysseyPathsOverviewView()
            case .goals:    OdysseyGoalsOverviewView()
            case .projects: OdysseyProjectsOverviewView()
            case .tasks:    OdysseyLinkedTasksView()
            }
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .environmentObject(theme)
        .environmentObject(store)
    }
}

// MARK: - 路径总览

struct OdysseyPathsOverviewView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SectionHeader(title: "活跃路径", icon: "map.fill")
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(store.activePaths) { path in
                    NavigationLink(destination:
                        OdysseyPathDetailView(pathID: path.id)
                            .environmentObject(theme)
                            .environmentObject(store)
                    ) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(path.isFocused
                                          ? theme.current.primaryAccent
                                          : theme.current.primaryAccent.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                Text(path.label).font(.headline.bold())
                                    .foregroundStyle(path.isFocused ? .white : theme.current.primaryAccent)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 5) {
                                    Text(path.title.isEmpty ? "（未命名）" : path.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(theme.current.textPrimary)
                                    if path.isFocused {
                                        Image(systemName: "bolt.fill").font(.caption2)
                                            .foregroundStyle(theme.current.primaryAccent)
                                    }
                                }
                                Text("\(path.goals.count) 目标 · \(path.totalProjectCount) 项目")
                                    .font(.caption).foregroundStyle(theme.current.textMuted)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                                .foregroundStyle(theme.current.textMuted)
                        }
                        .padding(DS.paddingCard)
                        .background(OdysseyCardBG(accent: path.isFocused))
                    }
                    .buttonStyle(.plain)
                }

                if !store.archivedPaths.isEmpty {
                    Divider().padding(.vertical, 4)
                    Text("已归档（\(store.archivedPaths.count)）")
                        .font(.caption).foregroundStyle(theme.current.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(store.archivedPaths) { path in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(theme.current.primaryAccent.opacity(0.08))
                                    .frame(width: 34, height: 34)
                                Text(path.label).font(.caption.bold())
                                    .foregroundStyle(theme.current.textMuted)
                            }
                            Text(path.title).font(.subheadline)
                                .foregroundStyle(theme.current.textSecondary)
                            Spacer()
                            Button("恢复") { store.unarchivePath(id: path.id) }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(theme.current.primaryAccent)
                        }
                        .padding(DS.paddingCard)
                        .background(OdysseyCardBG(accent: false))
                    }
                }
            }
            .padding(DS.paddingScreen)
        }
        .background(Color.clear)
        .navigationTitle("路径总览")
    }
}

// MARK: - 目标总览

struct OdysseyGoalsOverviewView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if store.allGoals.isEmpty {
                    overviewEmpty("暂无目标", "在路径详情页点击 + 创建目标")
                } else {
                    ForEach(store.activePaths.filter { !$0.goals.isEmpty }) { path in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle().fill(theme.current.primaryAccent.opacity(0.15))
                                        .frame(width: 22, height: 22)
                                    Text(path.label).font(.caption2.bold())
                                        .foregroundStyle(theme.current.primaryAccent)
                                }
                                Text(path.title.isEmpty ? "（未命名路径）" : path.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(theme.current.textSecondary)
                            }
                            ForEach(path.goals) { goal in
                                NavigationLink(destination:
                                    OdysseyGoalDetailView(pathID: path.id, goalID: goal.id)
                                        .environmentObject(theme)
                                        .environmentObject(store)
                                ) {
                                    goalRow(goal)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(DS.paddingScreen)
        }
        .background(Color.clear)
        .navigationTitle("目标总览")
    }

    @ViewBuilder
    private func goalRow(_ goal: OdysseyGoal) -> some View {
        HStack(spacing: 12) {
            Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(goal.isCompleted ? theme.current.successColor : theme.current.textMuted)
            VStack(alignment: .leading, spacing: 3) {
                Text(goal.title.isEmpty ? "（未命名目标）" : goal.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.current.textPrimary)
                    .strikethrough(goal.isCompleted)
                HStack(spacing: 8) {
                    Text(goal.timeHorizon.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(theme.current.primaryAccent.opacity(0.12)))
                        .foregroundStyle(theme.current.primaryAccent)
                    Text("\(goal.projects.count) 项目")
                        .font(.caption2).foregroundStyle(theme.current.textMuted)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(theme.current.textMuted)
        }
        .padding(DS.paddingCard)
        .background(OdysseyCardBG(accent: false))
    }
}

// MARK: - GoalNavTarget

struct GoalNavTarget: Hashable {
    let pathID: UUID
    let goalID: UUID
}

// MARK: - 项目总览

struct OdysseyProjectsOverviewView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if store.allProjects.isEmpty {
                    overviewEmpty("暂无项目", "在目标详情页点击 + 创建项目")
                } else {
                    ForEach(store.activePaths.filter { $0.totalProjectCount > 0 }) { path in
                        ForEach(path.goals.filter { !$0.projects.isEmpty }) { goal in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 4) {
                                    ZStack {
                                        Circle().fill(theme.current.primaryAccent.opacity(0.12))
                                            .frame(width: 18, height: 18)
                                        Text(path.label).font(.system(size: 9).bold())
                                            .foregroundStyle(theme.current.primaryAccent)
                                    }
                                    Text("·").foregroundStyle(theme.current.textMuted).font(.caption2)
                                    Text(goal.title.isEmpty ? "（未命名目标）" : goal.title)
                                        .font(.caption).foregroundStyle(theme.current.textSecondary)
                                }
                                ForEach(goal.projects) { project in
                                    NavigationLink(destination:
                                        OdysseyProjectDetailView(pathID: path.id, goalID: goal.id, projectID: project.id)
                                            .environmentObject(theme)
                                            .environmentObject(store)
                                    ) {
                                        projectRow(project)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
            .padding(DS.paddingScreen)
        }
        .background(Color.clear)
        .navigationTitle("项目总览")
    }

    @ViewBuilder
    private func projectRow(_ project: OdysseyProject) -> some View {
        HStack(spacing: 12) {
            Image(systemName: project.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(project.isCompleted ? theme.current.successColor : theme.current.textMuted)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name.isEmpty ? "（未命名项目）" : project.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.current.textPrimary)
                    .strikethrough(project.isCompleted)
                if !project.summary.isEmpty {
                    Text(project.summary).font(.caption)
                        .foregroundStyle(theme.current.textMuted).lineLimit(1)
                }
            }
            Spacer()
            if !project.linkedTaskIDs.isEmpty {
                Text("\(project.linkedTaskIDs.count) 任务")
                    .font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(theme.current.successColor.opacity(0.15)))
                    .foregroundStyle(theme.current.successColor)
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(theme.current.textMuted)
        }
        .padding(DS.paddingCard)
        .background(OdysseyCardBG(accent: false))
    }
}

// MARK: - 关联任务总览

struct OdysseyLinkedTasksView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore
    @Query(sort: \Task.order) private var allTasks: [Task]

    /// 收集所有层级的关联任务 ID（Project 层 + Goal 层 + Path 层）
    private var linkedTaskIDs: Set<UUID> {
        var ids = Set<UUID>()
        for path in store.paths {
            ids.formUnion(path.linkedTaskIDs)
            for goal in path.goals {
                ids.formUnion(goal.linkedTaskIDs)
                for project in goal.projects {
                    ids.formUnion(project.linkedTaskIDs)
                }
            }
        }
        return ids
    }

    private var linkedTasks: [Task] {
        allTasks.filter { linkedTaskIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if linkedTasks.isEmpty {
                    overviewEmpty("暂无关联任务", "在项目详情页点击 + 新建任务")
                } else {
                    ForEach(linkedTasks) { task in
                        NavigationLink(destination: TaskDetailView(task: task)) {
                            HStack(spacing: 12) {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isCompleted
                                                     ? theme.current.successColor
                                                     : theme.current.textMuted)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(task.title.isEmpty ? "（无标题）" : task.title)
                                        .font(.subheadline)
                                        .foregroundStyle(theme.current.textPrimary)
                                        .strikethrough(task.isCompleted)
                                    if let ctx = store.context(for: task.id) {
                                        Text(ctx.displayText)
                                            .font(.caption2)
                                            .foregroundStyle(theme.current.textMuted)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2).foregroundStyle(theme.current.textMuted)
                            }
                            .padding(DS.paddingCard)
                            .background(OdysseyCardBG(accent: false))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(DS.paddingScreen)
        }
        .background(Color.clear)
        .navigationTitle("关联任务")
    }
}

// MARK: - 空状态

@ViewBuilder
private func overviewEmpty(_ title: String, _ subtitle: String) -> some View {
    VStack(spacing: 10) {
        Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
        Text(title).font(.headline).foregroundStyle(.secondary)
        Text(subtitle).font(.caption).foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 60)
}
