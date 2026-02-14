//
//  ContentView.swift
//  TodoAPP
//
//  Created on 2025/12/06
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var errorHandler = ErrorHandler.shared
    @Query private var tasks: [Task]
    @Query private var taskLists: [TaskList]
    
    @State private var showingAddTask = false
    @State private var searchText = ""
    @State private var selectedFilter: TaskFilter = .all
    @State private var selectedList: TaskList?
    @State private var showingAddList = false
    @State private var newListName = ""
    @State private var showingRenameList = false
    @State private var renamingList: TaskList?
    @State private var renameText = ""
    @State private var showingEditList = false
    @State private var editingList: TaskList?
    @State private var editName = ""
    @State private var editIcon = ""
    @State private var editColor = "blue"
    @AppStorage("listDeleteBehavior") private var listDeleteBehavior: String = "unlink" // "unlink" or "cascade"
    @State private var showingSettings = false
    @State private var showingTagManagement = false
    private let availableIcons = ["list.bullet","tray","bookmark","star","flag"]
    private let availableColors = ["blue","green","orange","red","purple","pink","gray"]
    
    enum TaskFilter: String, CaseIterable {
        case all = "全部"
        case today = "今天"
        case scheduled = "已计划"
        case flagged = "重要"
        case completed = "已完成"
    }
    
    var filteredTasks: [Task] {
        var filtered = tasks
        
        // 搜索过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { task in
                task.title.localizedCaseInsensitiveContains(searchText) ||
                task.taskDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 列表过滤
        if let selectedList = selectedList {
            filtered = filtered.filter { $0.taskList?.id == selectedList.id }
        }
        
        // 状态过滤
        switch selectedFilter {
        case .all:
            filtered = filtered.filter { !$0.isCompleted }
        case .today:
            filtered = filtered.filter { task in
                if task.isCompleted { return false }
                // 今天创建的任务
                if Calendar.current.isDateInToday(task.createdAt) {
                    return true
                }
                // 截止日期是今天或之前的任务（包括过期）
                if let dueDate = task.dueDate {
                    return dueDate <= Calendar.current.startOfDay(for: Date().addingTimeInterval(24*60*60))
                }
                return false
            }
        case .scheduled:
            filtered = filtered.filter { $0.dueDate != nil && !$0.isCompleted }
        case .flagged:
            filtered = filtered.filter { 
                ($0.priority == .high || $0.priority == .urgent) && !$0.isCompleted 
            }
        case .completed:
            filtered = filtered.filter { $0.isCompleted }
        }
        
        return filtered.sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationSplitView {
            // 侧边栏
            List(selection: $selectedList) {
                Section("智能列表") {
                    ForEach(TaskFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                            selectedList = nil
                        }) {
                            HStack {
                                Image(systemName: iconForFilter(filter))
                                    .foregroundColor(colorForFilter(filter))
                                Text(filter.rawValue)
                                Spacer()
                                Text("\(countForFilter(filter))")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .listRowBackground(selectedFilter == filter && selectedList == nil ? Color.blue.opacity(0.1) : Color.clear)
                    }
                }
                
                Section("我的列表") {
                    ForEach(taskLists.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { list in
                        Button(action: {
                            selectedList = list
                            selectedFilter = .all
                        }) {
                            HStack {
                                Image(systemName: list.icon)
                                    .foregroundColor(list.colorValue)
                                Text(list.name)
                                Spacer()
                                Text("\(list.tasks?.filter { !$0.isCompleted }.count ?? 0)")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(selectedList?.id == list.id ? Color.blue.opacity(0.1) : Color.clear)
                        .contextMenu {
                            Button {
                                editingList = list
                                editName = list.name
                                editIcon = list.icon
                                editColor = list.color
                                showingEditList = true
                            } label: {
                                Label("编辑", systemImage: "slider.horizontal.3")
                            }

                            Button {
                                renamingList = list
                                renameText = list.name
                                showingRenameList = true
                            } label: {
                                Label("重命名", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                deleteSpecificList(list)
                            } label: {
                                Label("删除列表", systemImage: "trash")
                            }
                        }
                    }
                    .onMove(perform: moveList)
                    .onDelete(perform: deleteList)
                    
                    Button(action: addNewList) {
                        Label("新建列表", systemImage: "plus.circle")
                    }
                    Button(action: { showingTagManagement = true }) {
                        Label("标签管理", systemImage: "tag")
                    }
                    Button(action: { showingSettings = true }) {
                        Label("列表设置", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("待办事项")
#if os(iOS)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
#endif
            .alert("新建列表", isPresented: $showingAddList) {
                TextField("列表名称", text: $newListName)
                Button("取消", role: .cancel) {
                    newListName = ""
                }
                Button("创建") {
                    createNewList()
                }
            } message: {
                Text("请输入列表名称")
            }

            .alert("重命名列表", isPresented: $showingRenameList) {
                TextField("新名称", text: $renameText)
                Button("取消", role: .cancel) {
                    renamingList = nil
                    renameText = ""
                }
                Button("确认") {
                    doRenameList()
                }
            } message: {
                Text("输入新的列表名称")
            }

            .sheet(isPresented: $showingSettings) {
                NavigationStack {
                    Form {
                        Section("删除列表时") {
                            Picker("操作", selection: $listDeleteBehavior) {
                                Text("解除关联（保留任务）").tag("unlink")
                                Text("级联删除任务").tag("cascade")
                            }
                            .pickerStyle(.inline)
                            Text("解除关联会把任务的所属列表设为空；级联删除会同时删除该列表下所有任务。推荐使用解除关联以免误删任务。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .navigationTitle("列表设置")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("关闭") { showingSettings = false }
                        }
                    }
                }
                .environment(\.modelContext, modelContext)
            }

            .sheet(isPresented: $showingTagManagement) {
                TagManagementView()
                    .environment(\.modelContext, modelContext)
            }

            .sheet(isPresented: $showingEditList) {
                NavigationStack {
                    Form {
                        Section("基本信息") {
                            TextField("名称", text: $editName)
                            Picker("图标", selection: $editIcon) {
                                ForEach(availableIcons, id: \.self) { ic in
                                    HStack {
                                        Image(systemName: ic)
                                        Text(ic)
                                    }
                                    .tag(ic)
                                }
                            }
                            Picker("颜色", selection: $editColor) {
                                ForEach(availableColors, id: \.self) { c in
                                    HStack {
                                        Circle().fill(TaskList(name: "", color: c).colorValue).frame(width: 12, height: 12)
                                        Text(c)
                                    }
                                    .tag(c)
                                }
                            }
                        }
                    }
                    .navigationTitle("编辑列表")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                doEditList()
                                showingEditList = false
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                showingEditList = false
                            }
                        }
                    }
                }
                .environment(\.modelContext, modelContext)
            }
        } detail: {
            // 主视图
            VStack(spacing: 0) {
                // 搜索栏
                SearchBar(text: $searchText)
                    .padding()
                
                // 任务列表
                if filteredTasks.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(filteredTasks) { task in
                            NavigationLink(destination: TaskDetailView(task: task)) {
                                TaskRowView(task: task)
                            }
                        }
                        .onDelete(perform: deleteTasks)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(selectedList?.name ?? selectedFilter.rawValue)
#if os(iOS)
            .navigationBarTitleDisplayMode(.large)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
#else
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingAddTask = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
#endif
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(selectedList: selectedList)
                    .environment(\.modelContext, modelContext)
                    .environmentObject(errorHandler)
            }
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
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("暂无任务")
                .font(.title2)
                .foregroundColor(.secondary)
            Text("点击 + 创建新任务")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func iconForFilter(_ filter: TaskFilter) -> String {
        switch filter {
        case .all: return "tray"
        case .today: return "calendar"
        case .scheduled: return "calendar.badge.clock"
        case .flagged: return "flag.fill"
        case .completed: return "checkmark.circle"
        }
    }
    
    private func colorForFilter(_ filter: TaskFilter) -> Color {
        switch filter {
        case .all: return .blue
        case .today: return .green
        case .scheduled: return .orange
        case .flagged: return .red
        case .completed: return .gray
        }
    }
    
    private func countForFilter(_ filter: TaskFilter) -> Int {
        switch filter {
        case .all:
            return tasks.filter { !$0.isCompleted }.count
        case .today:
            return tasks.filter { task in
                if task.isCompleted { return false }
                // 今天创建的任务
                if Calendar.current.isDateInToday(task.createdAt) {
                    return true
                }
                // 截止日期是今天或之前的任务
                if let dueDate = task.dueDate {
                    return dueDate <= Calendar.current.startOfDay(for: Date().addingTimeInterval(24*60*60))
                }
                return false
            }.count
        case .scheduled:
            return tasks.filter { $0.dueDate != nil && !$0.isCompleted }.count
        case .flagged:
            return tasks.filter { 
                ($0.priority == .high || $0.priority == .urgent) && !$0.isCompleted 
            }.count
        case .completed:
            return tasks.filter { $0.isCompleted }.count
        }
    }
    
    private func addNewList() {
        showingAddList = true
    }
    
    private func createNewList() {
        guard !newListName.isEmpty else { return }
        let newList = TaskList(name: newListName)
        modelContext.insert(newList)
        do {
            try modelContext.save()
            print("✅ 创建列表: \(newListName)")
        } catch {
            errorHandler.handle(error, context: "创建列表")
        }
        newListName = ""
    }

    private func doRenameList() {
        guard let list = renamingList, !renameText.isEmpty else { return }
        list.name = renameText
        do {
            try modelContext.save()
        } catch {
            errorHandler.handle(error, context: "重命名列表")
        }
        renamingList = nil
        renameText = ""
    }

    private func doEditList() {
        guard let list = editingList else { return }
        list.name = editName
        list.icon = editIcon
        list.color = editColor
        do {
            try modelContext.save()
        } catch {
            errorHandler.handle(error, context: "编辑列表")
        }
        editingList = nil
    }

    private func moveList(from source: IndexSet, to destination: Int) {
        var sorted = taskLists.sorted { $0.sortOrder < $1.sortOrder }
        sorted.move(fromOffsets: source, toOffset: destination)
        for (index, list) in sorted.enumerated() {
            list.sortOrder = index
        }
        do {
            try modelContext.save()
        } catch {
            errorHandler.handle(error, context: "移动列表")
        }
    }
    
    private func deleteList(offsets: IndexSet) {
        // 使用对象引用避免越界，并保持与 deleteSpecificList 一致
        let sorted = taskLists.sorted { $0.sortOrder < $1.sortOrder }
        let listsToDelete = offsets.map { sorted[$0] }
        
        for list in listsToDelete {
            deleteSpecificList(list)
        }
    }
    
    private func deleteSpecificList(_ list: TaskList) {
        // 先获取任务的不可变副本
        let tasksInList = Array(list.tasks ?? [])
        
        if listDeleteBehavior == "cascade" {
            // 级联删除：先删除所有任务
            for task in tasksInList {
                // 取消关联的通知
                if task.reminderDate != nil {
                    NotificationManager.shared.cancelNotification(for: task)
                }
                modelContext.delete(task)
            }
        } else {
            // 解除关联（默认）
            for task in tasksInList {
                task.taskList = nil
            }
        }
        
        // 删除列表
        modelContext.delete(list)
        
        // 清除当前选择
        if selectedList?.id == list.id {
            selectedList = nil
        }
        
        // 保存
        do {
            try modelContext.save()
        } catch {
            errorHandler.handle(error, context: "删除列表")
        }
    }
    
    private func deleteTasks(offsets: IndexSet) {
        // 先获取要删除的任务对象引用，避免数组越界
        let tasksToDelete = offsets.map { filteredTasks[$0] }
        
        // 安全删除
        for task in tasksToDelete {
            modelContext.delete(task)
        }
        
        // 先保存，成功后再取消通知（避免保存失败时通知已消失）
        do {
            try modelContext.save()
            // 保存成功后取消通知
            for task in tasksToDelete {
                if task.reminderDate != nil {
                    NotificationManager.shared.cancelNotification(for: task)
                }
            }
        } catch {
            errorHandler.handle(error, context: "删除任务")
        }
    }
}

// SearchBar 组件
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("搜索任务", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
#if os(iOS)
        .background(Color(.systemGray6))
#else
        .background(Color(NSColor.controlBackgroundColor))
#endif
        .cornerRadius(10)
    }
}

// TaskRowView 组件
struct TaskRowView: View {
    @Bindable var task: Task
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 完成按钮
            Button(action: {
                withAnimation {
                    task.isCompleted.toggle()
                    task.updatedAt = Date()
                }
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 6) {
                // 标题
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                
                // 描述
                if !task.taskDescription.isEmpty {
                    Text(task.taskDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // 标签和信息行
                HStack(spacing: 8) {
                    // 优先级
                    if task.priority != .medium {
                        Label(task.priority.rawValue, systemImage: "flag.fill")
                            .font(.caption)
                            .foregroundColor(task.priority.color)
                    }
                    
                    // 截止日期
                    if let dueDate = task.dueDate {
                        Label(formatDate(dueDate), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(isOverdue(dueDate) ? .red : .secondary)
                    }
                    
                    // 颜色标签
                    if let tags = task.tags, !tags.isEmpty {
                        ForEach(tags.prefix(3), id: \.id) { tag in
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(tag.colorValue)
                                    .frame(width: 6, height: 6)
                                Text(tag.name)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(tag.colorValue.opacity(0.15))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天"
        } else if calendar.isDateInTomorrow(date) {
            return "明天"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM月dd日"
            return formatter.string(from: date)
        }
    }
    
    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && !task.isCompleted
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Task.self, TaskList.self, Tag.self], inMemory: true)
}
