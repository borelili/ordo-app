// OdysseyPathDetailView.swift
// TickTick — 路径详情页（第一层）
//
// 职责：
//   · 编辑路径基础字段（label / title / summary / visionText / kind / scores）
//   · 展示目标列表，点击进入 OdysseyGoalDetailView
//   · FAB = 新建目标

import SwiftUI
import SwiftData

struct OdysseyPathDetailView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore
    @Environment(\.dismiss) private var dismiss

    let pathID: UUID

    @State private var draft: OdysseyPath? = nil
    @State private var hasChanges          = false
    @State private var showNewGoal         = false
    @State private var showDeleteAlert     = false
    @State private var deleteGoalTarget: OdysseyGoal? = nil
    @State private var showDeleteGoalAlert = false

    private var path: OdysseyPath? {
        store.paths.first { $0.id == pathID }
    }

    var body: some View {
        Group {
            if draft != nil {
                mainContent
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { navToolbar }
        .onAppear { if draft == nil { draft = path } }
        // 当 store 中该路径有更新时，同步刷新 draft（防止持久化后数据撕裂）
        .onChange(of: path) { _, newPath in
            // 仅在没有未保存更改时自动同步
            if !hasChanges { draft = newPath }
        }
        .alert("删除路径", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) {
                store.deletePath(id: pathID); dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(draft.map { "删除「\($0.title)」及所有目标和项目？此操作不可撤销。" } ?? "")
        }
        .alert("删除目标", isPresented: $showDeleteGoalAlert) {
            Button("删除", role: .destructive) {
                if let g = deleteGoalTarget {
                    store.deleteGoal(id: g.id, from: pathID)
                    // 删除后重新读取 store，避免 draft 持有已删除目标
                    draft = store.paths.first { $0.id == pathID }
                    hasChanges = false
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(deleteGoalTarget.map { "删除「\($0.title)」？" } ?? "")
        }
        .sheet(isPresented: $showNewGoal) {
            NewGoalSheet(pathID: pathID)
                .environmentObject(theme)
                .environmentObject(store)
        }
    }

    // MARK: - 主体

    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    visionCard
                    scoreCard
                    goalsSection
                    dangerZone
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, DS.paddingScreen)
                .padding(.top, DS.spacingMD)
            }
            .background(Color.clear)

            // FAB：新建目标
            FloatingPlusButton { showNewGoal = true }
        }
    }

    // MARK: - 路径头部信息卡

    @ViewBuilder
    private var headerCard: some View {
        if let d = draft {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    // 标签输入
                    TextField("?", text: labelBinding)
                        .font(.title2.bold())
                        .foregroundStyle(theme.current.primaryAccent)
                        .multilineTextAlignment(.center)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(theme.current.primaryAccent.opacity(0.12)))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            // 路径类型徽章
                            Text(d.kind == .core ? "核心路径" : "探索草稿")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(d.kind == .core ? theme.current.primaryAccent : theme.current.textMuted)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill((d.kind == .core ? theme.current.primaryAccent : theme.current.textMuted).opacity(0.12)))

                            if d.isFocused {
                                Label("聚焦中", systemImage: "bolt.fill")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(theme.current.primaryAccent)
                            }
                        }
                        // 聚焦切换
                        Button {
                            store.setFocus(pathID: pathID)
                            draft = path
                        } label: {
                            Label(d.isFocused ? "取消聚焦" : "设为当前聚焦",
                                  systemImage: d.isFocused ? "bolt.slash" : "bolt")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(d.isFocused ? theme.current.textMuted : theme.current.primaryAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }

                dividerLine

                fieldBlock("路径名称", text: titleBinding)
                dividerLine
                fieldBlock("简短描述", text: summaryBinding)
            }
            .padding(DS.paddingCard)
            .background(OdysseyCardBG(accent: d.isFocused))
        }
    }

    // MARK: - 愿景文本

    @ViewBuilder
    private var visionCard: some View {
        if let d = draft {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "愿景描述", icon: "sparkles")
                TextEditor(text: visionBinding)
                    .frame(minHeight: 80)
                    .foregroundStyle(theme.current.textPrimary)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .placeholder(when: d.visionText.isEmpty) {
                        Text("如果一切都有可能，这条路会通向哪里……")
                            .foregroundStyle(theme.current.textMuted).font(.body)
                    }
            }
            .padding(DS.paddingCard)
            .background(OdysseyCardBG(accent: false))
        }
    }

    // MARK: - 评分卡

    @ViewBuilder
    private var scoreCard: some View {
        if let d = draft {
            HStack(spacing: 20) {
                scorePicker(title: "吸引力", value: d.attractionScore, icon: "heart.fill",
                             color: theme.current.primaryAccent) {
                    draft?.attractionScore = $0; save()
                }
                divider
                scorePicker(title: "挑战度", value: d.difficultyScore, icon: "bolt.fill",
                             color: theme.current.warningColor) {
                    draft?.difficultyScore = $0; save()
                }
            }
            .padding(DS.paddingCard)
            .background(OdysseyCardBG(accent: false))
        }
    }

    private func scorePicker(title: String, value: Int, icon: String, color: Color,
                              onChange: @escaping (Int) -> Void) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption).foregroundStyle(color)
                Text(title).font(.caption.weight(.medium)).foregroundStyle(theme.current.textMuted)
            }
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { i in
                    Circle().fill(i <= value ? color : color.opacity(0.2))
                        .frame(width: 20, height: 20)
                        .onTapGesture { onChange(i) }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(theme.current.divider.opacity(0.5)).frame(width: 1, height: 48)
    }

    // MARK: - 目标列表

    @ViewBuilder
    private var goalsSection: some View {
        if let d = draft {
            VStack(alignment: .leading, spacing: 10) {
                // 标题行 + 内联新建按钮
                HStack {
                    SectionHeader(title: "目标（\(d.goals.count)）", icon: "target")
                    Spacer()
                    Button {
                        showNewGoal = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.caption.weight(.bold))
                            Text("新建目标")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(theme.current.primaryAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(theme.current.primaryAccent.opacity(0.12))
                        )
                    }
                    .buttonStyle(.plain)
                }

                if d.goals.isEmpty {
                    Text("还没有目标\n点击上方 + 新建第一个目标")
                        .font(.subheadline).foregroundStyle(theme.current.textMuted)
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(OdysseyCardBG(accent: false))
                } else {
                    ForEach(d.goals) { goal in
                        NavigationLink(destination:
                            OdysseyGoalDetailView(pathID: pathID, goalID: goal.id)
                                .environmentObject(theme)
                                .environmentObject(store)
                        ) {
                            GoalRowCard(goal: goal) {
                                deleteGoalTarget = goal
                                showDeleteGoalAlert = true
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 危险区（默认路径仅展示归档，不显示删除）

    private var dangerZone: some View {
        let isDefault = draft?.isDefault ?? (path?.isDefault ?? false)
        return VStack(spacing: 10) {
            // 归档（默认路径不显示归档按钮，始终保留）
            if !isDefault {
                Button {
                    store.archivePath(id: pathID); dismiss()
                } label: {
                    Label("归档路径", systemImage: "archivebox")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.current.primaryAccent)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                            .fill(theme.current.primaryAccent.opacity(0.08))
                            .strokeBorder(theme.current.primaryAccent.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)

                // 删除（仅非默认路径可删）
                Button { showDeleteAlert = true } label: {
                    Label("删除路径", systemImage: "trash")
                        .font(.subheadline.weight(.medium)).foregroundStyle(.red)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                            .fill(Color.red.opacity(0.06))
                            .strokeBorder(Color.red.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
            } else {
                // 默认路径提示
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.caption2)
                    Text("A / B / C 是系统固定路径，不支持删除或归档。")
                        .font(.caption2)
                }
                .foregroundStyle(theme.current.textMuted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                    .fill(theme.current.textMuted.opacity(0.06)))
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var navToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(draft?.title ?? "路径详情").font(.headline).foregroundStyle(theme.current.textPrimary)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("保存") { save() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(hasChanges ? theme.current.primaryAccent : theme.current.textMuted)
                .disabled(!hasChanges)
        }
    }

    // MARK: - Bindings & Save

    private var labelBinding:   Binding<String> { binding(\.label) }
    private var titleBinding:   Binding<String> { binding(\.title) }
    private var summaryBinding: Binding<String> { binding(\.summary) }
    private var visionBinding:  Binding<String> { binding(\.visionText) }

    private func binding<V: Equatable>(_ kp: WritableKeyPath<OdysseyPath, V>) -> Binding<V> {
        Binding(
            get: {
                // 不使用强制解包，draft 为 nil 时直接从 store 读取
                if let d = draft { return d[keyPath: kp] }
                if let p = path  { return p[keyPath: kp] }
                // 最终保底：用空值占位（不会真正触发，因 body 在 draft==nil 时显示 ProgressView）
                return draft![keyPath: kp]
            },
            set: { draft?[keyPath: kp] = $0; hasChanges = true }
        )
    }

    private func save() {
        guard let d = draft else { return }
        store.updatePath(d)
        hasChanges = false
    }

    private func fieldBlock(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.medium)).foregroundStyle(theme.current.textMuted)
            TextField(label, text: text)
                .font(.body).foregroundStyle(theme.current.textPrimary)
        }
    }

    private var dividerLine: some View {
        Divider().background(theme.current.divider.opacity(0.5))
    }
}

// MARK: - GoalRowCard

private struct GoalRowCard: View {
    @EnvironmentObject private var theme: ThemeManager
    let goal:     OdysseyGoal
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(goal.title).font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.current.textPrimary)
                    // 时间范围徽章
                    Text(goal.timeHorizon.rawValue)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(theme.current.secondaryAccent)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(theme.current.secondaryAccent.opacity(0.12)))
                }
                if !goal.summary.isEmpty {
                    Text(goal.summary).font(.caption).foregroundStyle(theme.current.textSecondary).lineLimit(1)
                }
                HStack(spacing: 8) {
                    miniStat("\(goal.projects.count) 项目", icon: "folder")
                    miniStat("\(goal.totalLinkedTaskCount) 任务", icon: "checkmark.square")
                }
                .padding(.top, 2)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash").font(.caption).foregroundStyle(theme.current.textMuted.opacity(0.6))
            }
            .buttonStyle(.plain)

            Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                .foregroundStyle(theme.current.textMuted.opacity(0.5))
        }
        .padding(DS.paddingCard)
        .background(OdysseyCardBG(accent: false))
    }

    private func miniStat(_ text: String, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 9)).foregroundStyle(theme.current.textMuted)
            Text(text).font(.system(size: 10)).foregroundStyle(theme.current.textMuted)
        }
    }
}

// MARK: - NewGoalSheet

private struct NewGoalSheet: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore
    @Environment(\.dismiss) private var dismiss

    let pathID: UUID

    @State private var title           = ""
    @State private var summary         = ""
    @State private var timeHorizon     = GoalTimeHorizon.oneYear
    @State private var successCriteria = ""

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("目标名称 *") { TextField("例：完成第一个商业产品", text: $title) }
                Section("简短描述") { TextField("用一句话概括……", text: $summary) }
                Section("时间范围") {
                    Picker("时间范围", selection: $timeHorizon) {
                        ForEach(GoalTimeHorizon.allCases, id: \.self) { h in
                            Text(h.rawValue).tag(h)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("成功标准（可选）") {
                    TextEditor(text: $successCriteria).frame(minHeight: 60)
                }
            }
            .scrollContentBackground(.hidden).background(Color.clear)
            .navigationTitle("新建目标").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        store.addGoal(OdysseyGoal(
                            title: title, summary: summary,
                            timeHorizon: timeHorizon, successCriteria: successCriteria
                        ), to: pathID)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(theme.current.colorScheme)
    }
}

// MARK: - TextEditor placeholder helper

private extension View {
    @ViewBuilder
    func placeholder<Content: View>(when shouldShow: Bool,
                                    alignment: Alignment = .topLeading,
                                    @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}
