//
//  AddTaskView.swift
//  TodoAPP
//
//  Created on 2025/12/06
//

import SwiftUI
import SwiftData

struct AddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var errorHandler: ErrorHandler
    @Query private var allTags: [Tag]
    
    @State private var title = ""
    @State private var taskDescription = ""
    @State private var priority: Task.Priority = .medium
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var hasReminder = false
    @State private var reminderDate = Date()
    @State private var selectedTags: Set<Tag> = []
    @State private var showingTagPicker = false
    @State private var isSaving = false
    
    var selectedList: TaskList?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("任务标题", text: $title)
                    TextField("描述（可选）", text: $taskDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("优先级") {
                    Picker("优先级", selection: $priority) {
                        ForEach(Task.Priority.allCases, id: \.self) { p in
                            Label {
                                Text(p.rawValue)
                            } icon: {
                                Image(systemName: "flag.fill")
                                    .foregroundColor(p.color)
                            }
                            .tag(p)
                        }
                    }
                    #if os(iOS)
                    .pickerStyle(.menu)
                    #endif
                    
                    // 当前选择的优先级显示
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundColor(priority.color)
                        Text(priority.rawValue)
                            .foregroundColor(.primary)
                    }
                }
                
                Section("截止日期") {
                    Toggle("设置截止日期", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("日期", selection: $dueDate)
                    }
                }
                
                Section("提醒时间") {
                    Toggle("设置提醒", isOn: $hasReminder)
                    
                    if hasReminder {
                        DatePicker("提醒时间", selection: $reminderDate)
                    }
                }
                
                Section("标签") {
                    HStack {
                        Image(systemName: "tag")
                        if selectedTags.isEmpty {
                            Text("添加标签")
                        } else {
                            Text("已选择 \(selectedTags.count) 个标签")
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingTagPicker = true
                    }
                    
                    // 显示已选标签
                    if !selectedTags.isEmpty {
                        ForEach(Array(selectedTags), id: \.id) { tag in
                            HStack {
                                Circle()
                                    .fill(tag.colorValue)
                                    .frame(width: 12, height: 12)
                                Text(tag.name)
                                Spacer()
                                Button(action: {
                                    selectedTags.remove(tag)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("新建任务")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingTagPicker) {
                TagPickerView(selectedTags: $selectedTags)
                    .environment(\.modelContext, modelContext)
                    .environmentObject(errorHandler)
            }
        }
    }
    
    private func saveTask() {
        // 防止重复提交
        guard !isSaving else { return }
        isSaving = true
        
        let newTask = Task(
            title: title,
            taskDescription: taskDescription,
            priority: priority,
            dueDate: hasDueDate ? dueDate : nil,
            taskList: selectedList
        )
        
        // 设置提醒日期
        if hasReminder {
            newTask.reminderDate = reminderDate
        }
        
        // 添加标签
        newTask.tags = Array(selectedTags)
        
        modelContext.insert(newTask)
        
        // 保存并处理错误
        do {
            try modelContext.save()
            
            // 如果有提醒，调度通知
            if hasReminder {
                NotificationManager.shared.scheduleNotification(for: newTask, at: reminderDate)
            }
            
            print("✅ 任务已保存: \(title)")
            dismiss()
        } catch {
            isSaving = false
            errorHandler.handle(error, context: "保存任务")
        }
    }
}

// MARK: - 标签芯片组件
struct TagChip: View {
    let tag: Tag
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(tag.color))
                .frame(width: 8, height: 8)
            Text(tag.name)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(tag.color).opacity(0.2))
        .cornerRadius(12)
    }
}

// MARK: - 标签选择器
struct TagPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var errorHandler: ErrorHandler
    @Query private var allTags: [Tag]
    @Binding var selectedTags: Set<Tag>
    var onComplete: (() -> Void)? = nil
    
    @State private var newTagName = ""
    @State private var showingAddTag = false
    @State private var showingDeleteConfirm = false
    @State private var tagToDelete: Tag?
    @State private var showingEditTag = false
    @State private var editingTag: Tag?
    @State private var editTagName = ""
    @State private var editTagColor = "gray"
    
    let availableColors = ["red", "orange", "yellow", "green", "blue", "purple", "pink", "gray"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if allTags.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tag")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("暂无标签")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("点击下方按钮创建第一个标签")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("选择标签") {
                            ForEach(allTags, id: \.id) { tag in
                                Button(action: {
                                    if selectedTags.contains(tag) {
                                        selectedTags.remove(tag)
                                    } else {
                                        selectedTags.insert(tag)
                                    }
                                }) {
                                    HStack {
                                        Circle()
                                            .fill(tag.colorValue)
                                            .frame(width: 12, height: 12)
                                        Text(tag.name)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if selectedTags.contains(tag) {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        editingTag = tag
                                        editTagName = tag.name
                                        editTagColor = tag.color
                                        showingEditTag = true
                                    } label: {
                                        Label("编辑", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                    
                                    Button(role: .destructive) {
                                        requestDeleteTag(tag)
                                    } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        editingTag = tag
                                        editTagName = tag.name
                                        editTagColor = tag.color
                                        showingEditTag = true
                                    } label: {
                                        Label("编辑标签", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive) {
                                        requestDeleteTag(tag)
                                    } label: {
                                        Label("删除标签", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("标签")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("创建标签") {
                        showingAddTag = true
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        onComplete?()
                        dismiss()
                    }
                }
            }
            .alert("创建新标签", isPresented: $showingAddTag) {
                TextField("标签名称", text: $newTagName)
                Button("取消", role: .cancel) {
                    newTagName = ""
                }
                Button("保存") {
                    if !newTagName.isEmpty {
                        createTag()
                    }
                }
            } message: {
                Text("请输入标签名称（颜色将随机分配）")
            }
            .alert("确认删除标签", isPresented: $showingDeleteConfirm, presenting: tagToDelete) { tag in
                Button("取消", role: .cancel) {
                    tagToDelete = nil
                }
                Button("删除", role: .destructive) {
                    performDeleteTag(tag)
                }
            } message: { tag in
                let usageCount = tag.tasks?.count ?? 0
                if usageCount > 0 {
                    Text("标签「\(tag.name)」当前正被 \(usageCount) 个任务使用。删除后，这些任务将自动取消关联此标签。")
                } else {
                    Text("确定要删除标签「\(tag.name)」吗？")
                }
            }
            .sheet(isPresented: $showingEditTag) {
                NavigationStack {
                    Form {
                        Section("标签信息") {
                            TextField("标签名称", text: $editTagName)
                            
                            Picker("颜色", selection: $editTagColor) {
                                ForEach(availableColors, id: \.self) { color in
                                    HStack {
                                        Circle()
                                            .fill(Tag(name: "", color: color).colorValue)
                                            .frame(width: 20, height: 20)
                                        Text(color)
                                    }
                                    .tag(color)
                                }
                            }
                            #if os(iOS)
                            .pickerStyle(.menu)
                            #endif
                            
                            // 当前颜色预览
                            HStack {
                                Text("预览")
                                Spacer()
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Tag(name: "", color: editTagColor).colorValue)
                                        .frame(width: 16, height: 16)
                                    Text(editTagName.isEmpty ? "标签名称" : editTagName)
                                        .font(.callout)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Tag(name: "", color: editTagColor).colorValue.opacity(0.2))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .navigationTitle("编辑标签")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                showingEditTag = false
                                editingTag = nil
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                saveEditedTag()
                            }
                            .disabled(editTagName.isEmpty)
                        }
                    }
                }
            }
        }
    }
    
    private func createTag() {
        guard !newTagName.isEmpty else { 
            print("❌ 标签名称为空")
            return 
        }
        // 随机选择颜色
        let randomColor = availableColors.randomElement() ?? "blue"
        let newTag = Tag(name: newTagName, color: randomColor)
        modelContext.insert(newTag)
        do {
            try modelContext.save()
            selectedTags.insert(newTag)
            print("✅ 创建标签成功: \(newTagName)")
        } catch {
            errorHandler.handle(error, context: "创建标签")
        }
        newTagName = ""
    }
    
    private func requestDeleteTag(_ tag: Tag) {
        tagToDelete = tag
        showingDeleteConfirm = true
    }
    
    private func performDeleteTag(_ tag: Tag) {
        print("🗑️ 删除标签: \(tag.name)")
        // 从选中的标签中移除
        selectedTags.remove(tag)
        // 从数据库删除（由于 deleteRule 为 .nullify，关联的任务会自动解除关联）
        modelContext.delete(tag)
        do {
            try modelContext.save()
            print("✅ 删除标签成功")
        } catch {
            errorHandler.handle(error, context: "删除标签")
        }
        tagToDelete = nil
    }
    
    private func saveEditedTag() {
        guard let tag = editingTag, !editTagName.isEmpty else {
            showingEditTag = false
            return
        }
        
        print("✏️ 编辑标签: \(tag.name) -> \(editTagName), 颜色: \(editTagColor)")
        
        tag.name = editTagName
        tag.color = editTagColor
        
        do {
            try modelContext.save()
            print("✅ 编辑标签成功")
        } catch {
            errorHandler.handle(error, context: "编辑标签")
        }
        
        showingEditTag = false
        editingTag = nil
    }
}

// MARK: - 创建标签视图
struct CreateTagView: View {
    @Binding var newTagName: String
    @Binding var newTagColor: String
    let availableColors: [String]
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 标签名称输入
                VStack(alignment: .leading, spacing: 8) {
                    Text("标签名称")
                        .font(.headline)
                    TextField("输入标签名称", text: $newTagName)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                        .focused($isTextFieldFocused)
                }
                .padding(.horizontal)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isTextFieldFocused = true
                    }
                }
                
                // 颜色选择
                VStack(alignment: .leading, spacing: 12) {
                    Text("选择颜色")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                        ForEach(availableColors, id: \.self) { color in
                            Button(action: {
                                newTagColor = color
                            }) {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(Tag(name: "", color: color).colorValue)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .strokeBorder(Color.primary, lineWidth: newTagColor == color ? 3 : 0)
                                        )
                                    Text(colorName(color))
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("创建标签")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave()
                    }
                    .disabled(newTagName.isEmpty)
                }
            }
        }
    }
    
    private func colorName(_ color: String) -> String {
        switch color {
        case "red": return "红色"
        case "orange": return "橙色"
        case "yellow": return "黄色"
        case "green": return "绿色"
        case "blue": return "蓝色"
        case "purple": return "紫色"
        case "pink": return "粉色"
        case "gray": return "灰色"
        default: return color
        }
    }
}

// MARK: - FlowLayout 自动换行布局
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            guard index < result.frames.count else { continue }
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
