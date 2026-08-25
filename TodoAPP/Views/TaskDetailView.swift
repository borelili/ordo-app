//
//  TaskDetailView.swift
//  TodoAPP
//
//  Created on 2025/12/06
//

import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.odysseyStore) private var odysseyStore   // 可空，不强制依赖
    @StateObject private var errorHandler = ErrorHandler.shared
    @Query private var allTags: [Tag]
    @Bindable var task: Task
    
    @State private var isEditing = false
    @State private var showDeleteAlert = false
    @State private var showingTagPicker = false
    @State private var selectedTags: Set<Tag> = []
    @State private var hasDueDate = false
    @State private var hasReminder = false
    @State private var tagPickerDismissAction: (() -> Void)?
    @State private var newSubtaskTitle = ""
    @State private var showingAddSubtask = false
    @State private var editingSubtask: Subtask?
    @State private var editSubtaskTitle = ""
    @State private var showNotificationPermissionAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 完成状态
                HStack {
                    Button(action: {
                        toggleTaskCompletion()
                    }) {
                        HStack {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title)
                                .foregroundColor(task.isCompleted ? .green : .gray)
                            Text(task.isCompleted ? "已完成" : "标记为完成")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal)
                
                Divider()
                
                // 标题
                VStack(alignment: .leading, spacing: 8) {
                    Text("标题")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if isEditing {
                        TextField("标题", text: $task.title)
                            .textFieldStyle(.roundedBorder)
                            .font(.title3)
                    } else {
                        Text(task.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.horizontal)
                
                // 描述
                VStack(alignment: .leading, spacing: 8) {
                    Text("描述")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if isEditing {
                        TextEditor(text: $task.taskDescription)
                            .frame(minHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    } else {
                        if !task.taskDescription.isEmpty {
                            Text(task.taskDescription)
                                .foregroundColor(.primary)
                        } else {
                            Text("无描述")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 规划归属模块（仅当任务关联了奥德赛路径/目标/项目时显示）
                if let store = odysseyStore,
                   let dctx = store.detailedContext(for: task.id) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("规划归属")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        VStack(spacing: 0) {
                            // 路径行（始终存在）
                            NavigationLink(destination:
                                OdysseyPathDetailView(pathID: dctx.pathID)
                                    .environmentObject(store)
                            ) {
                                odysseyAttributionRow(
                                    icon: "map.fill",
                                    label: "路径",
                                    value: dctx.pathTitle
                                )
                            }
                            .buttonStyle(.plain)

                            // 目标行
                            if let goalID = dctx.goalID, !dctx.goalTitle.isEmpty {
                                Divider().padding(.leading, 40)
                                NavigationLink(destination:
                                    OdysseyGoalDetailView(pathID: dctx.pathID, goalID: goalID)
                                        .environmentObject(store)
                                ) {
                                    odysseyAttributionRow(
                                        icon: "target",
                                        label: "目标",
                                        value: dctx.goalTitle
                                    )
                                }
                                .buttonStyle(.plain)
                            }

                            // 项目行
                            if let goalID = dctx.goalID,
                               let projectID = dctx.projectID,
                               !dctx.projectName.isEmpty {
                                Divider().padding(.leading, 40)
                                NavigationLink(destination:
                                    OdysseyProjectDetailView(
                                        pathID: dctx.pathID,
                                        goalID: goalID,
                                        projectID: projectID
                                    )
                                    .environmentObject(store)
                                ) {
                                    odysseyAttributionRow(
                                        icon: "folder.fill",
                                        label: "项目",
                                        value: dctx.projectName
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.accentColor.opacity(0.06))
                                .strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal)
                }

                Divider()
                
                // 优先级
                VStack(alignment: .leading, spacing: 8) {
                    Text("优先级")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if isEditing {
                        Picker("优先级", selection: $task.priority) {
                            ForEach(Task.Priority.allCases, id: \.self) { priority in
                                Text(priority.rawValue).tag(priority)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        HStack {
                            Image(systemName: "flag.fill")
                                .foregroundColor(task.priority.color)
                            Text(task.priority.rawValue)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 截止日期
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("截止日期")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    if isEditing {
                        Toggle("设置截止日期", isOn: $hasDueDate)
                            .onChange(of: hasDueDate) { oldValue, newValue in
                                if !newValue {
                                    task.dueDate = nil
                                } else if task.dueDate == nil {
                                    task.dueDate = Date()
                                }
                            }
                        
                        if hasDueDate {
                            DatePicker("", selection: Binding(
                                get: { task.dueDate ?? Date() },
                                set: { task.dueDate = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                        }
                    } else {
                        if let dueDate = task.dueDate {
                            Text(formatDate(dueDate))
                        } else {
                            Text("未设置")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 提醒时间
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("提醒时间")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    
                    if isEditing {
                        Toggle("设置提醒", isOn: $hasReminder)
                            .onChange(of: hasReminder) { oldValue, newValue in
                                if !newValue {
                                    // 关闭提醒
                                    if task.reminderDate != nil {
                                        task.reminderDate = nil
                                        NotificationManager.shared.cancelNotification(for: task)
                                        try? modelContext.save()
                                    }
                                } else {
                                    // 打开提醒 - 需要检查权限
                                    // 先设置一个默认的提醒时间
                                    task.reminderDate = Date()
                                    NotificationManager.shared.scheduleNotification(for: task) { result in
                                        switch result {
                                        case .success:
                                            // 权限已授予，保存任务
                                            try? modelContext.save()
                                        case .failure:
                                            // 权限被拒绝，显示提示并回滚
                                            task.reminderDate = nil
                                            hasReminder = false
                                            showNotificationPermissionAlert = true
                                        }
                                    }
                                }
                            }
                        
                        if hasReminder {
                            DatePicker("", selection: Binding(
                                get: { task.reminderDate ?? Date() },
                                set: { newDate in
                                    // 先更新 reminderDate
                                    task.reminderDate = newDate
                                    // 然后重新调度通知
                                    NotificationManager.shared.scheduleNotification(for: task) { result in
                                        switch result {
                                        case .success:
                                            try? modelContext.save()
                                        case .failure:
                                            // 权限被拒绝，显示提示
                                            showNotificationPermissionAlert = true
                                        }
                                    }
                                }
                            ), displayedComponents: [.date, .hourAndMinute])
                        }
                    } else {
                        if let reminderDate = task.reminderDate {
                            Text(formatDate(reminderDate))
                        } else {
                            Text("未设置")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                // 标签
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("标签")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button(isEditing ? "编辑标签" : "管理标签") {
                            selectedTags = Set(task.tags ?? [])
                            showingTagPicker = true
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    if let tags = task.tags, !tags.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(tags, id: \.id) { tag in
                                HStack {
                                    Circle()
                                        .fill(tag.colorValue)
                                        .frame(width: 10, height: 10)
                                    Text(tag.name)
                                        .font(.callout)
                                    Spacer()
                                    if isEditing {
                                        Button(action: {
                                            removeTag(tag)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(tag.colorValue.opacity(0.2))
                                .cornerRadius(12)
                            }
                        }
                    } else {
                        Text("未设置标签")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // 子任务
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("子任务")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Spacer()
                        if isEditing {
                            Button(action: {
                                showingAddSubtask = true
                            }) {
                                Label("添加", systemImage: "plus.circle")
                                    .font(.subheadline)
                            }
                        }
                    }
                    
                    if let subtasks = task.subtasks, !subtasks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(subtasks, id: \.id) { subtask in
                                SubtaskRowView(
                                    subtask: subtask,
                                    isEditing: isEditing,
                                    onToggle: {
                                        toggleSubtask(subtask)
                                    },
                                    onEdit: {
                                        editingSubtask = subtask
                                        editSubtaskTitle = subtask.title
                                    },
                                    onDelete: {
                                        deleteSubtask(subtask)
                                    }
                                )
                            }
                        }
                    } else {
                        Text("暂无子任务")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                Divider()
                
                // 时间信息
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("创建时间")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(task.createdAt))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("更新时间")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(task.updatedAt))
                            .foregroundColor(.secondary)
                    }
                }
                .font(.caption)
                .padding(.horizontal)
                
                // 删除按钮
                if !isEditing {
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        Label("删除任务", systemImage: "trash")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                }
                
                #if DEBUG
                // Debug 测试通知按钮
                VStack(spacing: 8) {
                    Divider()
                        .padding(.horizontal)
                    
                    TestNotificationButton()
                        .padding(.horizontal)
                    
                    Text("仅 Debug 构建可见")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 16)
                #endif
                
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("任务详情")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .handleNotificationPermission(
            showAlert: $showNotificationPermissionAlert,
            onSettingsOpened: {
                // 用户去设置页后，关闭提醒开关
                hasReminder = false
                task.reminderDate = nil
                try? modelContext.save()
            },
            onDismissed: {
                // 用户取消后，也关闭提醒开关
                hasReminder = false
                task.reminderDate = nil
                try? modelContext.save()
            }
        )
        .onAppear {
            hasDueDate = task.dueDate != nil
            hasReminder = task.reminderDate != nil
        }
        .sheet(isPresented: $showingTagPicker) {
            TagPickerView(selectedTags: $selectedTags, onComplete: {
                // 用户点击"完成"时保存标签
                task.tags = Array(selectedTags)
                task.updatedAt = Date()
                do {
                    try modelContext.save()
                } catch {
                    errorHandler.handle(error, context: "保存任务标签")
                }
            })
                .environment(\.modelContext, modelContext)
                .environmentObject(errorHandler)
        }
        .toolbar {
#if os(macOS)
            ToolbarItem(placement: .navigation) {
                Button(action: {
                    dismiss()
                }) {
                    Label("返回", systemImage: "chevron.left")
                }
            }
#endif
            
            ToolbarItem(placement: .automatic) {
                Button(isEditing ? "完成" : "编辑") {
                    if isEditing {
                        task.updatedAt = Date()
                        do {
                            try modelContext.save()
                        } catch {
                            errorHandler.handle(error, context: "保存任务修改")
                        }
                    }
                    isEditing.toggle()
                }
            }
        }
        .alert("确认删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                deleteTask()
            }
        } message: {
            Text("确定要删除「\(task.title)」吗？此操作无法撤销。")
        }
        .alert("添加子任务", isPresented: $showingAddSubtask) {
            TextField("子任务标题", text: $newSubtaskTitle)
            Button("取消", role: .cancel) {
                newSubtaskTitle = ""
            }
            Button("添加") {
                addSubtask()
            }
            .disabled(newSubtaskTitle.isEmpty)
        } message: {
            Text("请输入子任务标题")
        }
        .alert("编辑子任务", isPresented: Binding(
            get: { editingSubtask != nil },
            set: { if !$0 { editingSubtask = nil } }
        )) {
            TextField("子任务标题", text: $editSubtaskTitle)
            Button("取消", role: .cancel) {
                editingSubtask = nil
            }
            Button("保存") {
                saveEditedSubtask()
            }
            .disabled(editSubtaskTitle.isEmpty)
        } message: {
            Text("请输入子任务标题")
        }
        .alert(item: $errorHandler.currentError) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("确定")) {
                    errorHandler.showError = false
                }
            )
        }
    }
    
    @ViewBuilder
    private func odysseyAttributionRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.5))
        }
        .padding(.vertical, 6)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
    
    private func deleteTask() {
        // 取消关联的通知
        if task.reminderDate != nil {
            NotificationManager.shared.cancelNotification(for: task)
        }
        // 删除前，从奥德赛所有层级中清除该任务的 UUID，避免脏统计
        let deletedID = task.id
        modelContext.delete(task)
        do {
            try modelContext.save()
            // 保存成功后，从 OdysseyStore 所有层级中移除该 ID
            if let store = odysseyStore {
                store.removeTaskIDFromAllLayers(deletedID)
            }
            dismiss()
        } catch {
            errorHandler.handle(error, context: "删除任务")
        }
    }
    
    private func removeTag(_ tag: Tag) {
        if var tags = task.tags {
            tags.removeAll { $0.id == tag.id }
            task.tags = tags
            task.updatedAt = Date()
            do {
                try modelContext.save()
            } catch {
                errorHandler.handle(error, context: "移除标签")
            }
        }
    }
    
    private func toggleTaskCompletion() {
        withAnimation {
            let wasCompleted = task.isCompleted
            task.isCompleted.toggle()
            task.updatedAt = Date()
            
            // 如果任务标记为完成，取消关联的提醒通知
            if !wasCompleted && task.isCompleted {
                if task.reminderDate != nil {
                    NotificationManager.shared.cancelNotification(for: task)
                }
            }
            // 如果任务被取消完成，且有未来的提醒，重新调度通知（带权限检查）
            else if wasCompleted && !task.isCompleted {
                if let reminderDate = task.reminderDate, reminderDate > Date() {
                    NotificationManager.shared.scheduleNotification(for: task) { result in
                        if case .failure = result {
                            // 权限被拒绝，清除 reminderDate
                            task.reminderDate = nil
                            try? modelContext.save()
                            showNotificationPermissionAlert = true
                        }
                    }
                }
            }
            
            do {
                try modelContext.save()
            } catch {
                // 如果保存失败，回滚状态
                task.isCompleted = wasCompleted
                errorHandler.handle(error, context: "更新任务状态")
            }
        }
    }
    
    // MARK: - Subtask Functions
    
    private func addSubtask() {
        guard !newSubtaskTitle.isEmpty else { return }
        
        let subtask = Subtask(title: newSubtaskTitle)
        subtask.parentTask = task
        
        if task.subtasks == nil {
            task.subtasks = []
        }
        task.subtasks?.append(subtask)
        task.updatedAt = Date()
        
        modelContext.insert(subtask)
        
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ 子任务已添加: \(newSubtaskTitle)")
            #endif
        } catch {
            errorHandler.handle(error, context: "添加子任务")
        }
        
        newSubtaskTitle = ""
    }
    
    private func toggleSubtask(_ subtask: Subtask) {
        withAnimation {
            subtask.isCompleted.toggle()
            task.updatedAt = Date()
            
            do {
                try modelContext.save()
            } catch {
                subtask.isCompleted.toggle() // 回滚
                errorHandler.handle(error, context: "更新子任务状态")
            }
        }
    }
    
    private func deleteSubtask(_ subtask: Subtask) {
        task.subtasks?.removeAll { $0.id == subtask.id }
        task.updatedAt = Date()
        modelContext.delete(subtask)
        
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ 子任务已删除")
            #endif
        } catch {
            errorHandler.handle(error, context: "删除子任务")
        }
    }
    
    private func saveEditedSubtask() {
        guard let subtask = editingSubtask, !editSubtaskTitle.isEmpty else {
            editingSubtask = nil
            return
        }
        
        subtask.title = editSubtaskTitle
        task.updatedAt = Date()
        
        do {
            try modelContext.save()
            #if DEBUG
            print("✅ 子任务已编辑")
            #endif
        } catch {
            errorHandler.handle(error, context: "编辑子任务")
        }
        
        editingSubtask = nil
    }
}

// MARK: - Subtask Row View
struct SubtaskRowView: View {
    let subtask: Subtask
    let isEditing: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 完成按钮
            Button(action: onToggle) {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundColor(subtask.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            // 标题
            Text(subtask.title)
                .font(.body)
                .strikethrough(subtask.isCompleted)
                .foregroundColor(subtask.isCompleted ? .secondary : .primary)
            
            Spacer()
            
            // 编辑按钮
            if isEditing {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
