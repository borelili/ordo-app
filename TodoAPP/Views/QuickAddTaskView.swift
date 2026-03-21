//
//  QuickAddTaskView.swift
//  TodoAPP
//
//  从 Dashboard 卡片底部"+ 添加待办"呼出的轻量快捷创建 Sheet
//

import SwiftUI
import SwiftData

struct QuickAddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let defaultList: TaskList

    @State private var title: String = ""
    @State private var priority: Task.Priority = .medium
    @State private var dueDate: Date? = nil
    @State private var showDatePicker = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                // ── 标题 ─────────────────────────────────
                Section {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(defaultList.colorValue.opacity(0.18))
                                .frame(width: 30, height: 30)
                            Image(systemName: defaultList.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(defaultList.colorValue)
                        }
                        TextField("任务标题", text: $title)
                            .focused($titleFocused)
                    }
                } header: {
                    Text("添加到「\(defaultList.name)」")
                }

                // ── 优先级 ───────────────────────────────
                Section("优先级") {
                    Picker("优先级", selection: $priority) {
                        ForEach(Task.Priority.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // ── 截止日期（可选）──────────────────────
                Section("截止日期（可选）") {
                    Toggle("设置截止日期", isOn: $showDatePicker.animation())
                    if showDatePicker {
                        DatePicker(
                            "截止日期",
                            selection: Binding(
                                get: { dueDate ?? Date() },
                                set: { dueDate = $0 }
                            ),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                        .onAppear { if dueDate == nil { dueDate = Date() } }
                    }
                }
            }
            .navigationTitle("快速添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") { saveTask() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    // MARK: - Save

    private func saveTask() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // 计算新任务的排序值
        let maxOrder = (defaultList.tasks?.map(\.order).max() ?? -1) + 1

        let task = Task(
            title: trimmed,
            priority: priority,
            dueDate: showDatePicker ? dueDate : nil,
            taskList: defaultList
        )
        task.order = maxOrder

        modelContext.insert(task)
        try? modelContext.save()
        dismiss()
    }
}
