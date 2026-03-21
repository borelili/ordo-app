// OdysseyTaskPickerView.swift
// TickTick — 多选现有任务关联至奥德赛项目

import SwiftUI
import SwiftData

struct OdysseyTaskPickerView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Task.order) private var allTasks: [Task]

    let alreadyLinked: [UUID]           // 已关联的 task ids（作为初始选中）
    let onConfirm: (Set<UUID>) -> Void  // 返回本次选中集合

    @State private var selection: Set<UUID> = []

    /// 按 TaskList 分组
    private var groups: [(listName: String, tasks: [Task])] {
        let grouped = Dictionary(grouping: allTasks) { $0.taskList?.name ?? "未分类" }
        return grouped.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.clear.ignoresSafeArea()
                List {
                    ForEach(groups, id: \.listName) { group in
                        Section(group.listName) {
                            ForEach(group.tasks) { task in
                                taskRow(task)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("选择关联任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundStyle(theme.current.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认（\(selection.count)）") {
                        onConfirm(selection)
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        selection.isEmpty
                            ? theme.current.textMuted
                            : theme.current.primaryAccent
                    )
                }
            }
        }
        .preferredColorScheme(theme.current.colorScheme)
        .onAppear {
            selection = Set(alreadyLinked)
        }
    }

    // MARK: - 任务行

    private func taskRow(_ task: Task) -> some View {
        let isSelected = selection.contains(task.id)
        return Button {
            if selection.contains(task.id) {
                selection.remove(task.id)
            } else {
                selection.insert(task.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(
                        isSelected ? theme.current.primaryAccent : theme.current.textMuted
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline)
                        .foregroundStyle(
                            task.isCompleted ? theme.current.textMuted : theme.current.textPrimary
                        )
                        .strikethrough(task.isCompleted)

                    if let due = task.dueDate {
                        Text(due, style: .date)
                            .font(.caption2)
                            .foregroundStyle(theme.current.textMuted)
                    }
                }

                Spacer()

                if alreadyLinked.contains(task.id) && isSelected {
                    Text("已关联")
                        .font(.caption2)
                        .foregroundStyle(theme.current.textMuted)
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill(theme.current.textMuted.opacity(0.12)))
                }
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isSelected
                ? theme.current.primaryAccent.opacity(0.07)
                : Color.clear
        )
    }
}
