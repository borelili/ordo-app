// OdysseyProjectDetailView.swift
// TickTick — 项目详情页（第三层，关联任务）

import SwiftUI
import SwiftData

struct OdysseyProjectDetailView: View {
    @EnvironmentObject private var theme: ThemeManager
    @EnvironmentObject private var store: OdysseyStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allTasks: [Task]

    let pathID:    UUID
    let goalID:    UUID
    let projectID: UUID

    @State private var draft: OdysseyProject? = nil
    @State private var hasChanges = false
    @State private var showDeleteAlert  = false
    @State private var showLinkPicker   = false
    @State private var showNewTaskSheet = false

    private var project: OdysseyProject? {
        store.paths.first { $0.id == pathID }?
            .goals.first { $0.id == goalID }?
            .projects.first { $0.id == projectID }
    }

    private var linkedTasks: [Task] {
        guard let d = draft else { return [] }
        return allTasks.filter { d.linkedTaskIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if draft != nil {
                mainContent
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.clear)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar { navToolbar }
        .onAppear { if draft == nil { draft = project } }
        .alert("确认删除项目", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) {
                store.deleteProject(id: projectID, from: goalID, in: pathID)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(draft.map { "删除「\($0.name)」？所有关联将被解除，原任务不会删除。" } ?? "")
        }
        .sheet(isPresented: $showLinkPicker) {
            OdysseyTaskPickerView(
                alreadyLinked: draft?.linkedTaskIDs ?? [],
                onConfirm: { newIDs in
                    // 把新选中（排除已有）的全部 link
                    let existing = Set(draft?.linkedTaskIDs ?? [])
                    newIDs.subtracting(existing).forEach {
                        store.linkTask(id: $0, to: projectID, goalID: goalID, pathID: pathID)
                    }
                    // 把本次未选中但之前已关联的 unlink
                    existing.subtracting(newIDs).forEach {
                        store.unlinkTask(id: $0, from: projectID, goalID: goalID, pathID: pathID)
                    }
                    draft = project
                }
            )
            .environmentObject(theme)
        }
        .sheet(isPresented: $showNewTaskSheet) {
            QuickAddAndLinkTaskView(
                pathID: pathID, goalID: goalID, projectID: projectID, store: store
            )
            .environmentObject(theme)
        }
    }

    // MARK: - 主体

    private var mainContent: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    infoCard
                    tasksSection
                    dangerZone
                    Color.clear.frame(height: 90)
                }
                .padding(.horizontal, DS.paddingScreen)
                .padding(.top, DS.spacingMD)
            }
            floatingMenu
        }
    }

    // MARK: - 信息卡

    @ViewBuilder
    private var infoCard: some View {
        if let d = draft {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Button {
                        draft?.isCompleted.toggle()
                        save()
                    } label: {
                        Image(systemName: d.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(
                                d.isCompleted ? theme.current.successColor : theme.current.textMuted
                            )
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(d.isCompleted ? "已完成" : "进行中")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            d.isCompleted ? theme.current.successColor : theme.current.primaryAccent
                        )
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(
                            Capsule().fill(
                                (d.isCompleted
                                    ? theme.current.successColor
                                    : theme.current.primaryAccent
                                ).opacity(0.12)
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    captionLabel("项目名称")
                    TextField("项目名称", text: nameBinding)
                        .font(.headline).foregroundStyle(theme.current.textPrimary)
                }

                Divider().background(theme.current.divider.opacity(0.5))

                VStack(alignment: .leading, spacing: 4) {
                    captionLabel("摘要")
                    TextField("简短描述", text: summaryBinding)
                        .font(.body).foregroundStyle(theme.current.textPrimary)
                }
            }
            .padding(DS.paddingCard)
            .background(OdysseyCardBG(accent: false))
        }
    }

    // MARK: - 任务区

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "关联任务（\(linkedTasks.count)）", icon: "checkmark.square.fill")
                Spacer()
                Button {
                    showLinkPicker = true
                } label: {
                    Label("选择已有", systemImage: "link.badge.plus")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.current.primaryAccent)
                }
                .buttonStyle(.plain)
            }

            if linkedTasks.isEmpty {
                Text("还没有关联任务\n点击右下 + 新建任务，或点击\"选择已有\"关联现有任务")
                    .font(.subheadline)
                    .foregroundStyle(theme.current.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(OdysseyCardBG(accent: false))
            } else {
                ForEach(linkedTasks) { task in
                    NavigationLink(destination: TaskDetailView(task: task)) {
                        LinkedTaskRow(task: task) {
                            store.unlinkTask(
                                id: task.id, from: projectID,
                                goalID: goalID, pathID: pathID
                            )
                            draft = project
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 危险区

    private var dangerZone: some View {
        Button { showDeleteAlert = true } label: {
            Label("删除此项目", systemImage: "trash")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                        .fill(Color.red.opacity(0.06))
                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - FAB

    private var floatingMenu: some View {
        // FAB：直接新建并关联任务
        FloatingPlusButton { showNewTaskSheet = true }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var navToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text(draft?.name ?? "项目详情")
                .font(.headline).foregroundStyle(theme.current.textPrimary)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button("保存") { save() }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(hasChanges ? theme.current.primaryAccent : theme.current.textMuted)
                .disabled(!hasChanges)
        }
    }

    // MARK: - Bindings

    private var nameBinding: Binding<String> {
        Binding(
            get: { draft?.name ?? "" },
            set: { draft?.name = $0; hasChanges = true }
        )
    }

    private var summaryBinding: Binding<String> {
        Binding(
            get: { draft?.summary ?? "" },
            set: { draft?.summary = $0; hasChanges = true }
        )
    }

    private func save() {
        guard let d = draft else { return }
        store.updateProject(d, in: goalID, pathID: pathID)
        hasChanges = false
    }

    private func captionLabel(_ text: String) -> some View {
        Text(text).font(.caption.weight(.medium)).foregroundStyle(theme.current.textMuted)
    }
}

// MARK: - LinkedTaskRow

private struct LinkedTaskRow: View {
    @EnvironmentObject private var theme: ThemeManager
    let task: Task
    let onUnlink: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isCompleted ? theme.current.successColor : theme.current.textMuted)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .foregroundStyle(
                        task.isCompleted ? theme.current.textMuted : theme.current.textPrimary
                    )
                    .strikethrough(task.isCompleted)
                if let list = task.taskList {
                    Text(list.name).font(.caption2).foregroundStyle(theme.current.textMuted)
                }
            }

            Spacer()

            Button(action: onUnlink) {
                Image(systemName: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(theme.current.textMuted.opacity(0.7))
            }
            .buttonStyle(.plain)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.current.textMuted.opacity(0.5))
        }
        .padding(DS.paddingCard)
        .background(OdysseyCardBG(accent: false))
    }
}

// MARK: - QuickAddAndLinkTaskView

/// 快速新建任务并自动关联至指定 Project（不打开完整 TaskDetailView）
private struct QuickAddAndLinkTaskView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskList.sortOrder) private var taskLists: [TaskList]

    let pathID:    UUID
    let goalID:    UUID
    let projectID: UUID
    let store:     OdysseyStore

    @State private var title = ""
    @State private var selectedList: TaskList? = nil

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务标题 *") {
                    TextField("例: 完成竞品分析", text: $title)
                }
                Section("所属清单") {
                    Picker("清单", selection: $selectedList) {
                        Text("无").tag(Optional<TaskList>.none)
                        ForEach(taskLists) { list in
                            Text(list.name).tag(Optional(list))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .navigationTitle("新建并关联任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { createAndLink() }.disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(theme.current.colorScheme)
    }

    private func createAndLink() {
        let task = Task(title: title, taskList: selectedList)
        modelContext.insert(task)
        store.linkTask(id: task.id, to: projectID, goalID: goalID, pathID: pathID)
        dismiss()
    }
}
