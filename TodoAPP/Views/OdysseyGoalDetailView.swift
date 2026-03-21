// OdysseyGoalDetailView.swift
// TickTick — 目标详情页（第二层）
//
// 职责：
//   · 编辑目标字段（title / summary / timeHorizon / successCriteria）
//   · 展示项目列表，点击进入 OdysseyProjectDetailView
//   · FAB = 新建项目

import SwiftUI
import SwiftData

// MARK: - ProjectNavTarget（导航上下文包装）

struct ProjectNavTarget: Hashable {
    let pathID:    UUID
    let goalID:    UUID
    let projectID: UUID
}

// MARK: - OdysseyGoalDetailView

struct OdysseyGoalDetailView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore
    @Environment(\.dismiss) private var dismiss

    let pathID: UUID
    let goalID: UUID

    @State private var draft: OdysseyGoal? = nil
    @State private var hasChanges             = false
    @State private var showNewProject         = false
    @State private var showDeleteAlert        = false
    @State private var deleteProjectTarget: OdysseyProject? = nil
    @State private var showDeleteProjectAlert = false

    private var goal: OdysseyGoal? {
        store.paths.first { $0.id == pathID }?
            .goals.first { $0.id == goalID }
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
        .onAppear { if draft == nil { draft = goal } }
        .onChange(of: goal) { _, newGoal in
            if !hasChanges { draft = newGoal }
        }
        .alert("删除目标", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) {
                store.deleteGoal(id: goalID, from: pathID); dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(draft.map { "删除「\($0.title)」？所有子项目也会被删除。" } ?? "")
        }
        .alert("删除项目", isPresented: $showDeleteProjectAlert) {
            Button("删除", role: .destructive) {
                if let p = deleteProjectTarget {
                    store.deleteProject(id: p.id, from: goalID, in: pathID)
                    // 删除后安全刷新 draft
                    draft = store.paths.first { $0.id == pathID }?
                        .goals.first { $0.id == goalID }
                    hasChanges = false
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(deleteProjectTarget.map { "删除「\($0.name)」？关联任务不会被删除。" } ?? "")
        }
        .sheet(isPresented: $showNewProject) {
            NewProjectSheet(pathID: pathID, goalID: goalID)
                .environmentObject(theme)
                .environmentObject(store)
        }
    }

    // MARK: - 主体

    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    infoCard
                    criteriaCard
                    projectsSection
                    deleteButton
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, DS.paddingScreen)
                .padding(.top, DS.spacingMD)
            }
            .background(Color.clear)

            // FAB：新建项目
            FloatingPlusButton { showNewProject = true }
        }
    }

    // MARK: - 基础信息卡

    @ViewBuilder
    private var infoCard: some View {
        if let d = draft {
            VStack(alignment: .leading, spacing: 14) {
                // 时间范围
                VStack(alignment: .leading, spacing: 4) {
                    captionLabel("时间范围")
                    Picker("时间范围", selection: horizonBinding) {
                        ForEach(GoalTimeHorizon.allCases, id: \.self) { h in
                            Text(h.rawValue).tag(h)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Divider().background(theme.current.divider.opacity(0.5))

                // 完成状态
                HStack {
                    Button {
                        draft?.isCompleted.toggle()
                        save()
                    } label: {
                        Image(systemName: d.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(d.isCompleted ? theme.current.successColor : theme.current.textMuted)
                    }
                    .buttonStyle(.plain)
                    Text(d.isCompleted ? "已完成" : "进行中")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(d.isCompleted ? theme.current.successColor : theme.current.primaryAccent)
                }

                Divider().background(theme.current.divider.opacity(0.5))

                VStack(alignment: .leading, spacing: 4) {
                    captionLabel("目标名称")
                    TextField("目标名称", text: titleBinding)
                        .font(.headline).foregroundStyle(theme.current.textPrimary)
                }

                Divider().background(theme.current.divider.opacity(0.5))

                VStack(alignment: .leading, spacing: 4) {
                    captionLabel("简短描述")
                    TextField("简短描述……", text: summaryBinding)
                        .font(.body).foregroundStyle(theme.current.textPrimary)
                }
            }
            .padding(DS.paddingCard)
            .background(OdysseyCardBG(accent: false))
        }
    }

    // MARK: - 成功标准

    @ViewBuilder
    private var criteriaCard: some View {
        if let d = draft {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "成功标准", icon: "checkmark.seal.fill")
                TextEditor(text: criteriaBinding)
                    .frame(minHeight: 70)
                    .foregroundStyle(theme.current.textPrimary)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .overlay(alignment: .topLeading) {
                        if d.successCriteria.isEmpty {
                            Text("当达到什么条件时，你会认为这个目标完成了？")
                                .foregroundStyle(theme.current.textMuted).font(.body)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .padding(DS.paddingCard)
            .background(OdysseyCardBG(accent: false))
        }
    }

    // MARK: - 项目列表

    @ViewBuilder
    private var projectsSection: some View {
        if let d = draft {
            VStack(alignment: .leading, spacing: 10) {
                // 标题行 + 内联新建按钮
                HStack {
                    SectionHeader(title: "项目（\(d.projects.count)）", icon: "folder.fill")
                    Spacer()
                    Button {
                        showNewProject = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.caption.weight(.bold))
                            Text("新建项目")
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

                if d.projects.isEmpty {
                    Text("还没有项目\n点击上方 + 新建第一个项目")
                        .font(.subheadline).foregroundStyle(theme.current.textMuted)
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(OdysseyCardBG(accent: false))
                } else {
                    ForEach(d.projects) { project in
                        NavigationLink(destination:
                            OdysseyProjectDetailView(pathID: pathID, goalID: goalID, projectID: project.id)
                                .environmentObject(theme)
                                .environmentObject(store)
                        ) {
                            ProjectRowCard(project: project) {
                                deleteProjectTarget = project
                                showDeleteProjectAlert = true
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - 删除目标

    private var deleteButton: some View {
        Button { showDeleteAlert = true } label: {
            Label("删除此目标", systemImage: "trash")
                .font(.subheadline.weight(.medium)).foregroundStyle(.red)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                    .fill(Color.red.opacity(0.06))
                    .strokeBorder(Color.red.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var navToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(draft?.title ?? "目标详情").font(.headline).foregroundStyle(theme.current.textPrimary)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("保存") { save() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(hasChanges ? theme.current.primaryAccent : theme.current.textMuted)
                .disabled(!hasChanges)
        }
    }

    // MARK: - Bindings & Save

    private var titleBinding:    Binding<String>          { binding(\.title) }
    private var summaryBinding:  Binding<String>          { binding(\.summary) }
    private var criteriaBinding: Binding<String>          { binding(\.successCriteria) }
    private var horizonBinding:  Binding<GoalTimeHorizon> { binding(\.timeHorizon) }

    private func binding<V: Equatable>(_ kp: WritableKeyPath<OdysseyGoal, V>) -> Binding<V> {
        Binding(
            get: {
                if let d = draft { return d[keyPath: kp] }
                if let g = goal  { return g[keyPath: kp] }
                return draft![keyPath: kp]  // 实际上不会到达（body 已把 nil 拦截）
            },
            set: { draft?[keyPath: kp] = $0; hasChanges = true }
        )
    }

    private func save() {
        guard let d = draft else { return }
        store.updateGoal(d, in: pathID)
        hasChanges = false
    }

    private func captionLabel(_ text: String) -> some View {
        Text(text).font(.caption.weight(.medium)).foregroundStyle(theme.current.textMuted)
    }
}

// MARK: - ProjectRowCard

private struct ProjectRowCard: View {
    @EnvironmentObject private var theme: ThemeManager
    let project:  OdysseyProject
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: project.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(project.isCompleted ? theme.current.successColor : theme.current.textMuted)

            VStack(alignment: .leading, spacing: 3) {
                Text(project.name).font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.current.textPrimary)
                if !project.summary.isEmpty {
                    Text(project.summary).font(.caption).foregroundStyle(theme.current.textSecondary).lineLimit(1)
                }
                HStack(spacing: 3) {
                    Image(systemName: "link").font(.system(size: 9)).foregroundStyle(theme.current.textMuted)
                    Text("\(project.linkedTaskIDs.count) 项关联任务").font(.system(size: 10)).foregroundStyle(theme.current.textMuted)
                }
                .padding(.top, 1)
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
}

// MARK: - NewProjectSheet

private struct NewProjectSheet: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore
    @Environment(\.dismiss) private var dismiss

    let pathID: UUID
    let goalID: UUID

    @State private var name    = ""
    @State private var summary = ""

    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("项目名称 *") { TextField("例：完成 MVP 原型", text: $name) }
                Section("简短描述") { TextField("简短描述……", text: $summary) }
            }
            .scrollContentBackground(.hidden).background(Color.clear)
            .navigationTitle("新建项目").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        store.addProject(OdysseyProject(name: name, summary: summary),
                                         to: goalID, in: pathID)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(theme.current.colorScheme)
    }
}
