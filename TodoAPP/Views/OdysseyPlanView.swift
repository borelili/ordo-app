// OdysseyPlanView.swift
// TickTick — 奥德赛计划首页 v4
//
// 设计规则：
//   1. 始终显示 A / B / C 三张路径卡片（默认路径由 OdysseyStore 保障）
//   2. 顶部统计块可点击 → 进入对应总览页
//   3. 编辑模式保留卡片样式，仅在卡片内叠加操作控件
//   4. 首页 FAB = 为当前聚焦路径新建目标
//   5. PathCard 支持 contextMenu / 编辑模式按钮

import SwiftUI
import SwiftData

// MARK: - OdysseyPlanView

struct OdysseyPlanView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore
    @Query private var allTasks: [Task]   // 用于实时计算关联任务数，自动过滤已删除任务

    @State private var isEditing          = false
    @State private var showNewGoal        = false
    @State private var showAddPath        = false
    @State private var showArchived       = false
    @State private var editingPath: OdysseyPath?
    @State private var archiveTarget: OdysseyPath?
    @State private var deleteTarget: OdysseyPath?
    @State private var showArchiveAlert   = false
    @State private var showDeleteAlert    = false
    // 统计块导航
    @State private var navPathsOverview    = false
    @State private var navGoalsOverview    = false
    @State private var navProjectsOverview = false
    @State private var navTasksOverview    = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    statsNavRow
                    pathsSection
                    if !store.archivedPaths.isEmpty { archivedSection }
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, DS.paddingScreen)
                .padding(.top, DS.spacingMD)
            }
            .background(Color.clear)

            if !isEditing {
                FloatingPlusButton { showNewGoal = true }
            }
        }
        .navigationTitle("奥德赛计划")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationDestination(for: OdysseyPath.self) { path in
            OdysseyPathDetailView(pathID: path.id)
                .environmentObject(theme)
                .environmentObject(store)
        }
        .navigationDestination(isPresented: $navPathsOverview) {
            OdysseyPathsOverviewView()
                .environmentObject(theme)
                .environmentObject(store)
        }
        .navigationDestination(isPresented: $navGoalsOverview) {
            OdysseyGoalsOverviewView()
                .environmentObject(theme)
                .environmentObject(store)
        }
        .navigationDestination(isPresented: $navProjectsOverview) {
            OdysseyProjectsOverviewView()
                .environmentObject(theme)
                .environmentObject(store)
        }
        .navigationDestination(isPresented: $navTasksOverview) {
            OdysseyLinkedTasksView()
                .environmentObject(theme)
                .environmentObject(store)
        }
        .sheet(isPresented: $showNewGoal) {
            NewGoalFromHomeSheet()
                .environmentObject(theme)
                .environmentObject(store)
        }
        .sheet(isPresented: $showAddPath) {
            AddExtraPathSheet()
                .environmentObject(theme)
                .environmentObject(store)
        }
        .sheet(item: $editingPath) { path in
            PathEditSheet(path: path)
                .environmentObject(theme)
                .environmentObject(store)
        }
        .alert("归档路径", isPresented: $showArchiveAlert) {
            Button("归档", role: .destructive) {
                if let p = archiveTarget { store.archivePath(id: p.id) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(archiveTarget.map { "归档「\($0.title)」后，它不再出现在主列表中，但数据保留。" } ?? "")
        }
        .alert("删除路径", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) {
                if let p = deleteTarget { store.deletePath(id: p.id) }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(deleteTarget.map { "彻底删除「\($0.title)」及所有目标和项目？此操作不可撤销。" } ?? "")
        }
    }

    // MARK: - 统计导航块

    private var statsNavRow: some View {
        HStack(spacing: 10) {
            Button { navPathsOverview = true } label: {
                OdysseyStatPill(value: store.activePaths.count,
                                label: "路径",    icon: "map.fill",
                                color: theme.current.primaryAccent)
            }.buttonStyle(.plain)

            Button { navGoalsOverview = true } label: {
                OdysseyStatPill(value: store.totalGoalCount,
                                label: "目标",    icon: "target",
                                color: theme.current.secondaryAccent)
            }.buttonStyle(.plain)

            Button { navProjectsOverview = true } label: {
                OdysseyStatPill(value: store.totalProjectCount,
                                label: "项目",    icon: "folder.fill",
                                color: theme.current.warningColor)
            }.buttonStyle(.plain)

            Button { navTasksOverview = true } label: {
                OdysseyStatPill(value: store.liveTaskCount(existingIDs: Set(allTasks.map(\.id))),
                                label: "关联任务", icon: "checkmark.square.fill",
                                color: theme.current.successColor)
            }.buttonStyle(.plain)
        }
    }

    // MARK: - 路径列表

    private var pathsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "我的路径", icon: "map.fill")
                Spacer()
                Button(isEditing ? "完成" : "编辑") {
                    withAnimation(.spring(response: 0.3)) { isEditing.toggle() }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.current.primaryAccent)

                if isEditing {
                    Button {
                        withAnimation { isEditing = false; showAddPath = true }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.current.primaryAccent)
                    }
                    .padding(.leading, 6)
                }
            }

            ForEach(store.activePaths) { path in
                PathCardRow(
                    path:      path,
                    isEditing: isEditing,
                    onFocus:   { store.setFocus(pathID: path.id) },
                    onEdit:    { editingPath = path },
                    onArchive: { archiveTarget = path; showArchiveAlert = true },
                    onDelete:  { deleteTarget  = path; showDeleteAlert  = true }
                )
            }
        }
    }

    // MARK: - 归档折叠区

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation { showArchived.toggle() }
            } label: {
                HStack {
                    SectionHeader(title: "已归档（\(store.archivedPaths.count)）", icon: "archivebox")
                    Spacer()
                    Image(systemName: showArchived ? "chevron.up" : "chevron.down")
                        .font(.caption2).foregroundStyle(theme.current.textMuted)
                }
            }.buttonStyle(.plain)

            if showArchived {
                ForEach(store.archivedPaths) { path in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(theme.current.primaryAccent.opacity(0.1))
                                .frame(width: 32, height: 32)
                            Text(path.label).font(.caption.bold())
                                .foregroundStyle(theme.current.textMuted)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(path.title).font(.subheadline)
                                .foregroundStyle(theme.current.textSecondary)
                            Text("已归档").font(.caption2).foregroundStyle(theme.current.textMuted)
                        }
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
    }
}

// MARK: - PathCardRow

private struct PathCardRow: View {
    @EnvironmentObject private var theme: ThemeManager
    let path:      OdysseyPath
    let isEditing: Bool
    let onFocus:   () -> Void
    let onEdit:    () -> Void
    let onArchive: () -> Void
    let onDelete:  () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // 卡片主体
            NavigationLink(value: path) {
                PathCardContent(path: path, onFocus: onFocus, showFocusButton: !isEditing)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!isEditing)

            // 编辑模式覆盖层
            if isEditing {
                HStack(spacing: 8) {
                    Button(action: onFocus) {
                        Image(systemName: path.isFocused ? "bolt.fill" : "bolt")
                            .font(.subheadline)
                            .foregroundStyle(path.isFocused ? theme.current.primaryAccent : theme.current.textMuted)
                            .editModeCircle()
                    }.buttonStyle(.plain)

                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.subheadline)
                            .foregroundStyle(theme.current.textPrimary)
                            .editModeCircle()
                    }.buttonStyle(.plain)

                    if !path.isDefault {
                        Button(action: onArchive) {
                            Image(systemName: "archivebox")
                                .font(.subheadline)
                                .foregroundStyle(theme.current.warningColor)
                                .editModeCircle()
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.top, 10)
                .padding(.trailing, 10)
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
        .contextMenu(menuItems: {
            Button { onFocus() } label: {
                Label(path.isFocused ? "当前聚焦" : "设为聚焦",
                      systemImage: path.isFocused ? "bolt.fill" : "bolt")
            }
            Button { onEdit() } label: {
                Label("编辑路径", systemImage: "pencil")
            }
            if !path.isDefault {
                Divider()
                Button(role: .destructive) { onArchive() } label: {
                    Label("归档", systemImage: "archivebox")
                }
                Button(role: .destructive) { onDelete() } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        })
    }
}

// MARK: - 编辑模式圆形按钮背景辅助

private extension View {
    func editModeCircle() -> some View {
        self.frame(width: 32, height: 32)
            .background(Circle().fill(.ultraThinMaterial))
    }
}

// MARK: - PathCardContent

private struct PathCardContent: View {
    @EnvironmentObject private var theme: ThemeManager
    let path:            OdysseyPath
    let onFocus:         () -> Void
    var showFocusButton: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            // 标签圆章
            ZStack {
                Circle()
                    .fill(path.isFocused
                          ? theme.current.primaryAccent
                          : theme.current.primaryAccent.opacity(0.15))
                    .frame(width: 42, height: 42)
                Text(path.label)
                    .font(.headline.bold())
                    .foregroundStyle(path.isFocused ? .white : theme.current.primaryAccent)
            }

            // 文字区
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(path.title.isEmpty ? "（未命名）" : path.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.current.textPrimary)
                    if path.isFocused {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(theme.current.primaryAccent)
                    }
                }
                if !path.summary.isEmpty {
                    Text(path.summary)
                        .font(.caption)
                        .foregroundStyle(theme.current.textSecondary)
                        .lineLimit(2)
                }
                HStack(spacing: 10) {
                    miniStat("\(path.goals.count)", "目标")
                    miniStat("\(path.totalProjectCount)", "项目")
                    miniStat("\(path.totalLinkedTaskCount)", "任务")
                }.padding(.top, 2)
            }

            Spacer()

            if showFocusButton {
                Button(action: onFocus) {
                    Image(systemName: path.isFocused ? "bolt.fill" : "bolt")
                        .font(.subheadline)
                        .foregroundStyle(path.isFocused
                                         ? theme.current.primaryAccent
                                         : theme.current.textMuted)
                }.buttonStyle(.plain)
            } else {
                // 占位，防止布局抖动
                Image(systemName: "bolt")
                    .font(.subheadline)
                    .foregroundStyle(Color.clear)
            }
        }
        .padding(DS.paddingCard)
        .background(OdysseyCardBG(accent: path.isFocused))
    }

    @ViewBuilder
    private func miniStat(_ value: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(value).font(.caption2.bold().monospacedDigit())
                .foregroundStyle(theme.current.textPrimary)
            Text(label).font(.caption2).foregroundStyle(theme.current.textMuted)
        }
    }
}

// MARK: - NewGoalFromHomeSheet（首页 FAB）

struct NewGoalFromHomeSheet: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPathID: UUID? = nil
    @State private var title   = ""
    @State private var summary = ""
    @State private var horizon = GoalTimeHorizon.oneYear

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("添加到路径") {
                    Picker("路径", selection: Binding(
                        get: { selectedPathID ?? store.focusedPath?.id ?? store.activePaths.first?.id },
                        set: { selectedPathID = $0 }
                    )) {
                        ForEach(store.activePaths) { p in
                            HStack {
                                Text(p.label).bold()
                                Text("·")
                                Text(p.title)
                            }
                            .tag(Optional(p.id))
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("目标名称 *") {
                    TextField("例：在 1 年内完成……", text: $title)
                }
                Section("简介") {
                    TextField("为什么这个目标对你重要？", text: $summary)
                }
                Section("时间范围") {
                    Picker("时间范围", selection: $horizon) {
                        ForEach(GoalTimeHorizon.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                }
            }
            .scrollContentBackground(.hidden).background(Color.clear)
            .navigationTitle("新建目标").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        let pid = selectedPathID ?? store.focusedPath?.id ?? store.activePaths.first?.id
                        guard let pathID = pid else { dismiss(); return }
                        store.addGoal(
                            OdysseyGoal(title: title, summary: summary, timeHorizon: horizon),
                            to: pathID
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(theme.current.colorScheme)
        .onAppear {
            if selectedPathID == nil {
                selectedPathID = store.focusedPath?.id ?? store.activePaths.first?.id
            }
        }
    }
}

// MARK: - AddExtraPathSheet

private struct AddExtraPathSheet: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore
    @Environment(\.dismiss) private var dismiss

    @State private var label   = ""
    @State private var title   = ""
    @State private var summary = ""
    @State private var isDraft = true

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("路径标签（如 D / E……）") { TextField("例：D", text: $label) }
                Section("路径名称 *") { TextField("例：海外创业", text: $title) }
                Section("简介") { TextField("如果走这条路……", text: $summary) }
                Section { Toggle("标记为探索草稿", isOn: $isDraft) }
                Section {
                    Text("A / B / C 是系统固定路径，此处添加额外实验路径（可删除）。")
                        .font(.caption).foregroundStyle(theme.current.textMuted)
                }
            }
            .scrollContentBackground(.hidden).background(Color.clear)
            .navigationTitle("添加实验路径").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        store.addPath(OdysseyPath(
                            label:     label.isEmpty ? "?" : String(label.prefix(2)),
                            title:     title,
                            summary:   summary,
                            kind:      isDraft ? .draft : .core,
                            isDefault: false
                        ))
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(theme.current.colorScheme)
    }
}

// MARK: - PathEditSheet

private struct PathEditSheet: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore
    @Environment(\.dismiss) private var dismiss

    let path: OdysseyPath
    @State private var title:      String
    @State private var summary:    String
    @State private var visionText: String
    @State private var kind:       PathKind

    init(path: OdysseyPath) {
        self.path   = path
        _title      = State(initialValue: path.title)
        _summary    = State(initialValue: path.summary)
        _visionText = State(initialValue: path.visionText)
        _kind       = State(initialValue: path.kind)
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("路径名称 *") { TextField("名称", text: $title) }
                Section("一句话简介") { TextField("这条路线的方向是……", text: $summary) }
                Section("愿景描述") {
                    TextEditor(text: $visionText).frame(minHeight: 80)
                }
                if !path.isDefault {
                    Section("类型") {
                        Picker("类型", selection: $kind) {
                            ForEach(PathKind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Color.clear)
            .navigationTitle("编辑路径 \(path.label)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        var up = path
                        up.title = title; up.summary = summary
                        up.visionText = visionText; up.kind = kind
                        store.updatePath(up)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(theme.current.colorScheme)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        OdysseyPlanView()
            .environmentObject(ThemeManager())
            .environmentObject(OdysseyStore())
    }
    .preferredColorScheme(.dark)
}
