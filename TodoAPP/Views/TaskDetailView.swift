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
                                    if task.reminderDate != nil {
                                        task.reminderDate = nil
                                        NotificationManager.shared.cancelNotification(for: task)
                                    }
                                } else if task.reminderDate == nil {
                                    task.reminderDate = Date()
                                }
                            }
                        
                        if hasReminder {
                            DatePicker("", selection: Binding(
                                get: { task.reminderDate ?? Date() },
                                set: { newDate in
                                    let oldDate = task.reminderDate
                                    task.reminderDate = newDate
                                    // 更新通知
                                    if oldDate != nil {
                                        NotificationManager.shared.updateNotification(for: task, at: newDate)
                                    } else {
                                        NotificationManager.shared.scheduleNotification(for: task, at: newDate)
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
                
                Spacer(minLength: 40)
            }
            .padding(.top)
        }
        .navigationTitle("任务详情")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
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
        modelContext.delete(task)
        do {
            try modelContext.save()
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
            // 如果任务被取消完成，且有未来的提醒，重新调度通知
            else if wasCompleted && !task.isCompleted {
                if let reminderDate = task.reminderDate, reminderDate > Date() {
                    NotificationManager.shared.scheduleNotification(for: task, at: reminderDate)
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
}
