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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var errorHandler = ErrorHandler.shared
    @Query private var tasks: [Task]
    @Query private var taskLists: [TaskList]
    @Query private var tags: [Tag]
    
    /// 当前时间快照：每 60 秒通过 DateRefresher 自动刷新；回到前台时也立即刷新
    @StateObject private var dateRefresher = DateRefresher()

    private var currentDate: Date { dateRefresher.currentDate }
    
    @State private var showingAddTask = false
    @State private var searchText = ""
    @State private var selectedFilter: TaskFilter = .all
    @State private var selectedList: TaskList?
    @State private var selectedTag: Tag?
    @State private var showingAddList = false
    @State private var showingRenameList = false
    @State private var renamingList: TaskList?
    @State private var renameText = ""
    @State private var editingList: TaskList?
    @AppStorage("listDeleteBehavior") private var listDeleteBehavior: String = "cascade" // 已固定为 cascade
    @State private var showingSettings = false
    @State private var showingTagManagement = false
    
    // 批量操作相关状态
    @State private var selectionMode = false
    @State private var selectedTasks: Set<Task> = []
    @State private var showingBatchMoveSheet = false
    @State private var showingBatchDeleteConfirm = false
    @State private var showingKeyboardShortcuts = false  // 快捷键帮助
    
    // iPhone push 导航路径
    @State private var iphonePath: [SmartListDestination] = []
    
    // 导航目标枚举（用于 iPhone NavigationStack）
    enum SmartListDestination: Hashable {
        case filter(TaskFilter)
        case customList(TaskList)
        case tag(Tag)
        
        func hash(into hasher: inout Hasher) {
            switch self {
            case .filter(let filter):
                hasher.combine("filter")
                hasher.combine(filter)
            case .customList(let list):
                hasher.combine("list")
                hasher.combine(list.id)
            case .tag(let tag):
                hasher.combine("tag")
                hasher.combine(tag.id)
            }
        }
        
        static func == (lhs: SmartListDestination, rhs: SmartListDestination) -> Bool {
            switch (lhs, rhs) {
            case (.filter(let lf), .filter(let rf)):
                return lf == rf
            case (.customList(let ll), .customList(let rl)):
                return ll.id == rl.id
            case (.tag(let lt), .tag(let rt)):
                return lt.id == rt.id
            default:
                return false
            }
        }
    }
    
    enum TaskFilter: String, CaseIterable {
        case all = "全部"
        case today = "今天"
        case upcoming = "即将到来"
        case overdue = "已逾期"
        case scheduled = "已计划"
        case flagged = "重要"
        case noDate = "无日期"
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
        
        // 标签过滤（优先于状态过滤）
        if let selectedTag = selectedTag {
            filtered = filtered.filter { task in
                task.tags?.contains(where: { $0.id == selectedTag.id }) == true && !task.isCompleted
            }
            return filtered.sorted {
                if $0.order == $1.order { return $0.createdAt > $1.createdAt }
                return $0.order < $1.order
            }
        }
        
        // 状态过滤（使用 SmartListFilter 集中管理）
        switch selectedFilter {
        case .all:
            filtered = SmartListFilter.filterAll(filtered)
        case .today:
            filtered = SmartListFilter.filterToday(filtered, now: currentDate)
        case .upcoming:
            filtered = SmartListFilter.filterUpcoming(filtered, now: currentDate)
        case .overdue:
            filtered = SmartListFilter.filterOverdue(filtered, now: currentDate)
        case .scheduled:
            filtered = SmartListFilter.filterScheduled(filtered)
        case .flagged:
            filtered = SmartListFilter.filterFlagged(filtered)
        case .noDate:
            filtered = SmartListFilter.filterNoDate(filtered)
        case .completed:
            filtered = SmartListFilter.filterCompleted(filtered)
        }
        
        // Upcoming 已经在 SmartListFilter 中排序，其他列表按 order 排序
        if selectedFilter == .upcoming {
            return filtered
        }
        
        // 按 order 排序，如果 order 相同则按创建时间降序
        return filtered.sorted { 
            if $0.order == $1.order {
                return $0.createdAt > $1.createdAt
            }
            return $0.order < $1.order
        }
    }
    
    var body: some View {
        // iPhone（compact）使用 NavigationStack，iPad/macOS 使用 NavigationSplitView
        Group {
            if horizontalSizeClass == .compact {
                iphoneNavigationView
            } else {
                ipadMacNavigationView
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                dateRefresher.refresh()
            }
        }
    }
    
    // MARK: - iPhone Navigation View
    
    private var iphoneNavigationView: some View {
        NavigationStack(path: $iphonePath) {
            SidebarHomeView(
                selectedFilter: $selectedFilter,
                selectedList: $selectedList,
                selectedTag: $selectedTag,
                editingList: $editingList,
                showingAddList: $showingAddList,
                showingTagManagement: $showingTagManagement,
                showingSettings: $showingSettings,
                renamingList: $renamingList,
                renameText: $renameText,
                showingRenameList: $showingRenameList,
                currentDate: currentDate,
                onDeleteList: deleteSpecificList,
                onNavigate: { dest in iphonePath.append(dest) }
            )
            .navigationTitle("待办事项")
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: SmartListDestination.self) { destination in
                switch destination {
                case .filter(let filter):
                    taskListContentView(filter: filter, list: nil, tag: nil)
                case .customList(let list):
                    taskListContentView(filter: .all, list: list, tag: nil)
                case .tag(let tag):
                    taskListContentView(filter: .all, list: nil, tag: tag)
                }
            }
            .sheet(isPresented: $showingAddList) {
                EditListView(list: nil)
                    .environment(\.modelContext, modelContext)
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
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text("同时删除该列表下所有任务")
                            }
                            Text("删除列表时会级联删除其中所有任务，并自动取消相关提醒通知。此操作不可撤销。")
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
            .sheet(item: $editingList) { list in
                EditListView(list: list)
                    .environment(\.modelContext, modelContext)
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
    }
    
    // MARK: - iPad Tag Row Helper
    
    @ViewBuilder
    private func ipadTagRow(tag: Tag) -> some View {
        let badge = ListBadgeService.count(for: tag)
        Button(action: {
            selectedTag    = tag
            selectedList   = nil
            selectedFilter = .all
        }) {
            HStack(spacing: 12) {
                Image(systemName: "tag.fill")
                    .font(.body.weight(.medium))
                    .foregroundColor(tag.colorValue)
                    .frame(width: 24)
                Text(tag.name)
                    .font(.body)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(tag.colorValue.opacity(0.8)))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(
            selectedTag?.id == tag.id
                ? tag.colorValue.opacity(0.15)
                : Color.clear
        )
    }
    
    // MARK: - List Sections
    
    private var smartListSection: some View {
        Section {
            ForEach(TaskFilter.allCases, id: \.self) { filter in
                NavigationLink(value: SmartListDestination.filter(filter)) {
                    smartListRow(filter: filter)
                }
                .contentShape(Rectangle())
            }
        } header: {
            Text("智能列表")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var customListSection: some View {
        Section {
            ForEach(taskLists.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { list in
                NavigationLink(value: SmartListDestination.customList(list)) {
                    customListRow(list: list)
                }
                .contentShape(Rectangle())
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteSpecificList(list)
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    Button {
                        editingList = list
                    } label: {
                        Label("编辑", systemImage: "slider.horizontal.3")
                    }
                    .tint(.blue)
                }
                .contextMenu {
                    Button {
                        editingList = list
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
        } header: {
            Text("我的列表")
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }

        Section {
            Button(action: addNewList) {
                Label("新建列表", systemImage: "plus.circle.fill")
                    .font(.body.weight(.medium))
            }
            .foregroundColor(.blue)
            .contentShape(Rectangle())

            Button(action: { showingTagManagement = true }) {
                Label("标签管理", systemImage: "tag.fill")
                    .font(.body.weight(.medium))
            }
            .foregroundColor(.orange)
            .contentShape(Rectangle())

            Button(action: { showingSettings = true }) {
                Label("列表设置", systemImage: "gearshape.fill")
                    .font(.body.weight(.medium))
            }
            .foregroundColor(.gray)
            .contentShape(Rectangle())
        }
    }
    
    // MARK: - iPad/macOS Navigation View
    
    @ViewBuilder
    private var ipadMacNavigationView: some View {
        NavigationSplitView {
            // 侧边栏
            List(selection: $selectedList) {
                Section {
                    ForEach(TaskFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                            selectedList = nil
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: iconForFilter(filter))
                                    .font(.body.weight(.medium))
                                    .foregroundColor(colorForFilter(filter))
                                    .frame(width: 24)
                                
                                Text(filter.rawValue)
                                    .font(.body)
                                
                                Spacer()
                                
                                // 任务数量徽章
                                let count = countForFilter(filter)
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(colorForFilter(filter).opacity(0.8))
                                        )
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFilter = filter
                            selectedList = nil
                        }
                        .listRowBackground(
                            selectedFilter == filter && selectedList == nil 
                                ? colorForFilter(filter).opacity(0.15)
                                : Color.clear
                        )
                    }
                } header: {
                    Text("智能列表")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                
                Section {
                    ForEach(taskLists.sorted { $0.sortOrder < $1.sortOrder }, id: \.id) { list in
                        Button(action: {
                            selectedList = list
                            selectedFilter = .all
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: list.icon)
                                    .font(.body.weight(.medium))
                                    .foregroundColor(list.colorValue)
                                    .frame(width: 24)
                                
                                Text(list.name)
                                    .font(.body)
                                
                                Spacer()
                                
                                // 未完成任务数量
                                let count = list.tasks?.filter { !$0.isCompleted }.count ?? 0
                                if count > 0 {
                                    Text("\(count)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            Capsule()
                                                .fill(list.colorValue.opacity(0.8))
                                        )
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowBackground(
                            selectedList?.id == list.id 
                                ? list.colorValue.opacity(0.15)
                                : Color.clear
                        )
                        .contextMenu {
                            Button {
                                editingList = list
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
                    #if os(macOS)
                    // macOS 上通过 contextMenu 提供额外的操作选项
                    #endif
                } header: {
                    Text("我的列表")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                Section {
                    ForEach(tags, id: \.id) { tag in
                        ipadTagRow(tag: tag)
                    }
                } header: {
                    Text("我的标签")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }

                Section {
                    Button(action: addNewList) {
                        Label("新建列表", systemImage: "plus.circle.fill")
                            .font(.body.weight(.medium))
                    }
                    .foregroundColor(.blue)

                    Button(action: { showingTagManagement = true }) {
                        Label("标签管理", systemImage: "tag.fill")
                            .font(.body.weight(.medium))
                    }
                    .foregroundColor(.orange)

                    Button(action: { showingSettings = true }) {
                        Label("列表设置", systemImage: "gearshape.fill")
                            .font(.body.weight(.medium))
                    }
                    .foregroundColor(.gray)
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
            .sheet(isPresented: $showingAddList) {
                EditListView(list: nil)
                    .environment(\.modelContext, modelContext)
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
                            HStack(spacing: 8) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text("同时删除该列表下所有任务")
                            }
                            Text("删除列表时会级联删除其中所有任务，并自动取消相关提醒通知。此操作不可撤销。")
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

            .sheet(item: $editingList) { list in
                EditListView(list: list)
                    .environment(\.modelContext, modelContext)
            }
        } detail: {
            // 主视图 - 使用可复用的任务列表内容视图
            taskListContentView(filter: selectedFilter, list: selectedList, tag: selectedTag)
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
        #if os(macOS)
        .sheet(isPresented: $showingKeyboardShortcuts) {
            KeyboardShortcutsView()
        }
        .onAppear {
            setupKeyboardShortcutListeners()
        }
        #endif
    }
    
    // MARK: - Task List Content View (可复用)
    
    @ViewBuilder
    private func taskListContentView(filter: TaskFilter, list: TaskList?, tag: Tag? = nil) -> some View {
        // 更新 selectedFilter / selectedList / selectedTag 以便 filteredTasks 正确筛选
        let _ = {
            self.selectedFilter = filter
            self.selectedList   = list
            self.selectedTag    = tag
        }()
        
        VStack(spacing: 0) {
            // 搜索栏
            SearchBar(text: $searchText)
                .padding()
            
            // 批量操作工具栏
            if selectionMode && !selectedTasks.isEmpty {
                batchOperationToolbar
            }
            
            // 任务列表
            if filteredTasks.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredTasks) { task in
                        if selectionMode {
                            TaskRowView(
                                task: task,
                                selectionMode: selectionMode,
                                isSelected: selectedTasks.contains(task),
                                onSelectionToggle: { toggleTaskSelection(task) }
                            )
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                        } else {
                            NavigationLink(destination: TaskDetailView(task: task)) {
                                TaskRowView(task: task)
                            }
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                        }
                    }
                    .onMove(perform: moveTasks)
                    .onDelete(perform: deleteTasks)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                // 统一底部避让：直接施加到任务 List
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: DS.homeBottomInset)
                }
            }
        }
        .navigationTitle(tag.map { "# \($0.name)" } ?? list?.name ?? filter.rawValue)
#if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        .background(Color.clear)
        .toolbarBackground(.hidden, for: .navigationBar)
#endif
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                if selectionMode {
                    Button("取消") {
                        exitSelectionMode()
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if selectionMode {
                    Button(selectedTasks.count == filteredTasks.count ? "取消全选" : "全选") {
                        toggleSelectAll()
                    }
                } else {
                    Menu {
                        Button(action: { showingAddTask = true }) {
                            Label("新建任务", systemImage: "plus.circle")
                        }
                        Button(action: { enterSelectionMode() }) {
                            Label("批量操作", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
#else
            ToolbarItem(placement: .automatic) {
                if selectionMode {
                    Button("取消") {
                        exitSelectionMode()
                    }
                }
            }
            
            ToolbarItem(placement: .automatic) {
                if selectionMode {
                    Button(selectedTasks.count == filteredTasks.count ? "取消全选" : "全选") {
                        toggleSelectAll()
                    }
                } else {
                    Menu {
                        Button(action: { showingAddTask = true }) {
                            Label("新建任务", systemImage: "plus.circle")
                        }
                        Button(action: { enterSelectionMode() }) {
                            Label("批量操作", systemImage: "checkmark.circle")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
#endif
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(selectedList: list)
                .environment(\.modelContext, modelContext)
                .environmentObject(errorHandler)
        }
    }
    
    // MARK: - Batch Operation Toolbar
    
    // 批量操作工具栏
    private var batchOperationToolbar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 16) {
                // 已选择数量
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    Text("已选择 \(selectedTasks.count) 项")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // 批量完成/未完成
                Button(action: batchToggleCompletion) {
                    Label(allSelectedCompleted ? "标记未完成" : "标记完成", 
                          systemImage: allSelectedCompleted ? "circle" : "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                
                // 批量移动
                Button(action: { showingBatchMoveSheet = true }) {
                    Label("移动", systemImage: "folder.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                
                // 批量删除
                Button(role: .destructive, action: { showingBatchDeleteConfirm = true }) {
                    Label("删除", systemImage: "trash.fill")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            Divider()
        }
#if os(macOS)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.8))
#else
        .background(Color(.systemBackground).opacity(0.95))
#endif
        .sheet(isPresented: $showingBatchMoveSheet) {
            batchMoveListPicker
        }
        .alert("确认删除", isPresented: $showingBatchDeleteConfirm) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                batchDelete()
            }
        } message: {
            Text("确定要删除选中的 \(selectedTasks.count) 个任务吗？此操作无法撤销。")
        }
    }
    
    // 批量移动列表选择器
    private var batchMoveListPicker: some View {
        NavigationView {
            List {
                ForEach(taskLists.sorted { $0.sortOrder < $1.sortOrder }) { list in
                    Button(action: {
                        batchMoveTo(list: list)
                        showingBatchMoveSheet = false
                    }) {
                        HStack {
                            Image(systemName: list.icon)
                                .foregroundColor(list.colorValue)
                            Text(list.name)
                            Spacer()
                            if selectedList?.id == list.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("移动到列表")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingBatchMoveSheet = false
                    }
                }
            }
        }
    }
    
    private var allSelectedCompleted: Bool {
        !selectedTasks.isEmpty && selectedTasks.allSatisfy { $0.isCompleted }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            VStack(spacing: 8) {
                Text("暂无任务")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("点击右上角 ＋ 创建新任务")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.02),
                    Color.cyan.opacity(0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
    
    private func iconForFilter(_ filter: TaskFilter) -> String {
        switch filter {
        case .all: return "tray"
        case .today: return "calendar"
        case .upcoming: return "calendar.badge.clock"
        case .overdue: return "exclamationmark.triangle"
        case .scheduled: return "calendar.circle"
        case .flagged: return "flag.fill"
        case .noDate: return "calendar.badge.minus"
        case .completed: return "checkmark.circle"
        }
    }
    
    private func colorForFilter(_ filter: TaskFilter) -> Color {
        switch filter {
        case .all: return .blue
        case .today: return .green
        case .upcoming: return .orange
        case .overdue: return .red
        case .scheduled: return .purple
        case .flagged: return .pink
        case .noDate: return .gray
        case .completed: return .secondary
        }
    }
    
    private func countForFilter(_ filter: TaskFilter) -> Int {
        // 统一使用 SmartListFilter，确保 badge 数量与页面展示一致
        switch filter {
        case .all:
            return SmartListFilter.filterAll(tasks).count
        case .today:
            return SmartListFilter.filterToday(tasks, now: currentDate).count
        case .upcoming:
            return SmartListFilter.filterUpcoming(tasks, now: currentDate).count
        case .overdue:
            return SmartListFilter.filterOverdue(tasks, now: currentDate).count
        case .scheduled:
            return SmartListFilter.filterScheduled(tasks).count
        case .flagged:
            return SmartListFilter.filterFlagged(tasks).count
        case .noDate:
            return SmartListFilter.filterNoDate(tasks).count
        case .completed:
            return SmartListFilter.filterCompleted(tasks).count
        }
    }
    
    // MARK: - Helper Views
    
    private func smartListRow(filter: TaskFilter) -> some View {
        smartListRowContent(filter: filter)
    }
    
    private func smartListRowContent(filter: TaskFilter) -> some View {
        let count = countForFilter(filter)
        let color = colorForFilter(filter)
        let icon = iconForFilter(filter)
        
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(filter.rawValue)
                .font(.body)
            
            Spacer()
            
            if count > 0 {
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(color.opacity(0.8)))
            }
        }
    }
    
    private func customListRow(list: TaskList) -> some View {
        customListRowContent(list: list)
    }
    
    private func customListRowContent(list: TaskList) -> some View {
        let count = list.tasks?.filter { !$0.isCompleted }.count ?? 0
        let color = list.colorValue
        
        return HStack(spacing: 12) {
            Image(systemName: list.icon)
                .font(.body.weight(.medium))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(list.name)
                .font(.body)
            
            Spacer()
            
            if count > 0 {
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(color.opacity(0.8)))
            }
        }
    }
    
    private func addNewList() {
        showingAddList = true
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
        let tasksInList = Array(list.tasks ?? [])

        // ① 删除前捕获通知 identifier（对象删除后 .id 可能失效）
        let notificationIds = tasksInList.compactMap { task -> String? in
            task.reminderDate != nil ? task.id.uuidString : nil
        }

        #if DEBUG
        print("🗑️ [DeleteList] 列表: '\(list.name)'  任务数: \(tasksInList.count)  有通知任务: \(notificationIds.count)")
        #endif

        // ② 取消所有通知（在 delete 之前）
        NotificationManager.shared.cancelNotifications(withIdentifiers: notificationIds,
                                                       label: "list:\(list.name)")

        // ③ deleteRule = .cascade：删除 list 时 SwiftData 自动级联删除所有任务
        modelContext.delete(list)

        // ④ 清除选中状态
        if selectedList?.id == list.id {
            selectedList = nil
        }

        // ⑤ 持久化
        do {
            try modelContext.save()
            #if DEBUG
            // 验证残留——SwiftData @Query 会自动更新，此处做额外日志确认
            print("   ✅ 保存成功，@Query tasks 会在下帧自动刷新")
            #endif
        } catch {
            errorHandler.handle(error, context: "删除列表")
        }
    }
    
    private func deleteTasks(offsets: IndexSet) {
        // ① 先用对象引用捕获要删除的任务（避免 index 越界）
        let tasksToDelete = offsets.map { filteredTasks[$0] }

        // ② 删除前捕获通知 identifier（SwiftData delete 后对象可能失效导致读取 .id 不可靠）
        let notificationIds = tasksToDelete.compactMap { task -> String? in
            task.reminderDate != nil ? task.id.uuidString : nil
        }

        #if DEBUG
        print("🗑️ [DeleteTask] 删除任务数: \(tasksToDelete.count)  有通知: \(notificationIds.count)")
        #endif

        // ③ 取消通知（在 delete 之前，identifier 仍然有效）
        NotificationManager.shared.cancelNotifications(withIdentifiers: notificationIds)

        // ④ 删除对象
        for task in tasksToDelete {
            modelContext.delete(task)
        }

        // ⑤ 持久化
        do {
            try modelContext.save()
        } catch {
            errorHandler.handle(error, context: "删除任务")
        }
    }
    
    // MARK: - 批量操作方法
    
    private func enterSelectionMode() {
        selectionMode = true
        selectedTasks.removeAll()
    }
    
    private func exitSelectionMode() {
        selectionMode = false
        selectedTasks.removeAll()
    }
    
    private func toggleTaskSelection(_ task: Task) {
        if selectedTasks.contains(task) {
            selectedTasks.remove(task)
        } else {
            selectedTasks.insert(task)
        }
    }
    
    private func toggleSelectAll() {
        if selectedTasks.count == filteredTasks.count {
            selectedTasks.removeAll()
        } else {
            selectedTasks = Set(filteredTasks)
        }
    }
    
    private func batchToggleCompletion() {
        guard !selectedTasks.isEmpty else { return }
        
        let shouldComplete = !allSelectedCompleted
        
        for task in selectedTasks {
            let wasCompleted = task.isCompleted
            task.isCompleted = shouldComplete
            task.updatedAt = Date()
            
            // 处理通知
            if !wasCompleted && task.isCompleted {
                // 任务完成，取消通知
                if task.reminderDate != nil {
                    NotificationManager.shared.cancelNotification(for: task)
                }
            } else if wasCompleted && !task.isCompleted {
                // 任务取消完成，恢复未来的通知（静默处理权限）
                if let reminderDate = task.reminderDate, reminderDate > Date() {
                    NotificationManager.shared.scheduleNotification(for: task) { result in
                        if case .failure = result {
                            // 权限被拒绝，静默清除 reminderDate
                            task.reminderDate = nil
                            #if DEBUG
                            print("⚠️ 通知权限不足，已清除任务 \(task.title) 的提醒时间")
                            #endif
                        }
                    }
                }
            }
        }
        
        do {
            try modelContext.save()
            #if DEBUG
            let debugNow = Date()
            print("[BatchToggle] shouldComplete=\(shouldComplete) count=\(selectedTasks.count)")
            for task in selectedTasks {
                let isOverdueResult = task.dueDate.map { $0 < debugNow } ?? false
                let toList: String = {
                    if task.isCompleted { return "已完成" }
                    if isOverdueResult { return "已逾期" }
                    if task.dueDate == nil { return "全部/无日期" }
                    return "全部/已计划/即将到来"
                }()
                print("  id=\(task.id.uuidString.prefix(8)) isCompleted=\(task.isCompleted) dueDate=\(task.dueDate.map { String(describing: $0) } ?? "nil") isOverdue=\(isOverdueResult) → \(toList)")
            }
            #endif
            exitSelectionMode()
        } catch {
            errorHandler.handle(error, context: "批量\(shouldComplete ? "完成" : "取消完成")任务")
        }
    }
    
    private func batchMoveTo(list: TaskList) {
        guard !selectedTasks.isEmpty else { return }
        
        for task in selectedTasks {
            task.taskList = list
            task.updatedAt = Date()
        }
        
        do {
            try modelContext.save()
            exitSelectionMode()
        } catch {
            errorHandler.handle(error, context: "批量移动任务")
        }
    }
    
    private func batchDelete() {
        guard !selectedTasks.isEmpty else { return }
        
        let tasksToDelete = Array(selectedTasks)

        // ① 删除前捕获通知 identifier
        let notificationIds = tasksToDelete.compactMap { task -> String? in
            task.reminderDate != nil ? task.id.uuidString : nil
        }

        #if DEBUG
        print("🗑️ [BatchDelete] 任务数: \(tasksToDelete.count)  有通知: \(notificationIds.count)")
        #endif

        // ② 先取消通知（identifier 在删除前仍有效）
        NotificationManager.shared.cancelNotifications(withIdentifiers: notificationIds)

        // ③ 删除对象
        for task in tasksToDelete {
            modelContext.delete(task)
        }

        // ④ 持久化
        do {
            try modelContext.save()
            exitSelectionMode()
        } catch {
            errorHandler.handle(error, context: "批量删除任务")
        }
    }
    
    // MARK: - 拖拽排序方法
    
    private func moveTasks(from source: IndexSet, to destination: Int) {
        // 获取当前筛选后的任务列表的可变副本
        var tasks = filteredTasks
        
        // 移动任务
        tasks.move(fromOffsets: source, toOffset: destination)
        
        // 更新所有任务的 order 值
        for (index, task) in tasks.enumerated() {
            task.order = index
            task.updatedAt = Date()
        }
        
        // 保存
        do {
            try modelContext.save()
        } catch {
            errorHandler.handle(error, context: "移动任务")
        }
    }
    
    // MARK: - 键盘快捷键处理
    
    #if os(macOS)
    private func setupKeyboardShortcutListeners() {
        // 新建任务
        NotificationCenter.default.addObserver(
            forName: .newTask,
            object: nil,
            queue: .main
        ) { [self] _ in
            showingAddTask = true
        }
        
        // 新建列表
        NotificationCenter.default.addObserver(
            forName: .newList,
            object: nil,
            queue: .main
        ) { [self] _ in
            showingAddList = true
        }
        
        // 批量操作
        NotificationCenter.default.addObserver(
            forName: .batchOperations,
            object: nil,
            queue: .main
        ) { [self] _ in
            if selectionMode {
                exitSelectionMode()
            } else {
                enterSelectionMode()
            }
        }
        
        // 显示快捷键帮助
        NotificationCenter.default.addObserver(
            forName: .showKeyboardShortcuts,
            object: nil,
            queue: .main
        ) { [self] _ in
            showingKeyboardShortcuts = true
        }
    }
    #endif
}

// SearchBar 组件
struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? .blue : .gray)
                .font(.body)
                .animation(.easeInOut(duration: 0.2), value: isFocused)
            
            TextField("搜索任务", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
                .focused($isFocused)
            
            if !text.isEmpty {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        text = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.body)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
#if os(iOS)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isFocused ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
        )
#else
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isFocused ? Color.blue.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: 2)
        )
#endif
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// TaskRowView 组件
struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: Task

    // 批量操作相关参数
    var selectionMode: Bool = false
    var isSelected: Bool = false
    var onSelectionToggle: (() -> Void)? = nil

    // 完成动画状态
    @State private var sparkleActive = false
    @State private var previewCompleted = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // 选择模式下的选择框
            if selectionMode {
                Button(action: {
                    onSelectionToggle?()
                }) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .gray.opacity(0.5))
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // 正常模式下的完成按钮
                ZStack {
                    Button(action: {
                        handleCompletionTap()
                    }) {
                        Image(systemName: (task.isCompleted || previewCompleted) ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundColor((task.isCompleted || previewCompleted) ? .green : .gray.opacity(0.5))
                            .symbolRenderingMode(.hierarchical)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: task.isCompleted || previewCompleted)
                    // VoiceOver：动态描述当前状态
                    .accessibilityLabel(task.isCompleted ? "标记为未完成" : "标记为完成")
                    .accessibilityHint(task.title)

                    // Firefly 萤火闪光（可通过 FeatureFlags.enableFireflyEffects 关闭）
                    if FeatureFlags.enableFireflyEffects {
                        FireflyCompleteEffect(visible: $sparkleActive)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // 标题
                Text(task.title)
                    .font(.body.weight(task.isCompleted ? .regular : .medium))
                    .strikethrough(task.isCompleted, color: .secondary)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)
                
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
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.caption2)
                            Text(task.priority.rawValue)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            task.priority.color
                                .opacity(task.isCompleted ? 0.5 : 1.0)
                        )
                        .clipShape(Capsule())
                    }
                    
                    // 截止日期
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: isOverdue(dueDate) ? "exclamationmark.triangle.fill" : "calendar")
                                .font(.caption2)
                            Text(formatDate(dueDate))
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundColor(isOverdue(dueDate) ? .white : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            isOverdue(dueDate) 
                                ? Color.red.opacity(task.isCompleted ? 0.5 : 1.0)
                                : Color.secondary.opacity(0.15)
                        )
                        .clipShape(Capsule())
                    }
                    
                    // 颜色标签
                    if let tags = task.tags, !tags.isEmpty {
                        ForEach(tags.prefix(2), id: \.id) { tag in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(tag.colorValue)
                                    .frame(width: 8, height: 8)
                                Text(tag.name)
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(tag.colorValue)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(tag.colorValue.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        
                        if tags.count > 2 {
                            Text("+\(tags.count - 2)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(task.isCompleted ? Color.secondary.opacity(0.05) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    task.isCompleted ? Color.clear : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
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
    
    private func handleCompletionTap() {
        if !task.isCompleted {
            // 即将标记为完成：触感 + 动画（FeatureFlag 控制），0.5s 后写入
            Haptics.shared.taskCompleted()
            if FeatureFlags.enableFireflyEffects {
                previewCompleted = true
                sparkleActive = true
                // FireflyCompleteEffect 会在 ~0.5s 后自动将 sparkleActive → false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    previewCompleted = false
                    toggleTaskCompletion()
                }
            } else {
                toggleTaskCompletion()
            }
        } else {
            // 取消完成：轻触感 + 直接写入，无动画
            Haptics.shared.taskUncompleted()
            toggleTaskCompletion()
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
            // 如果任务被取消完成，且有未来的提醒，重新调度通知（静默处理权限）
            else if wasCompleted && !task.isCompleted {
                if let reminderDate = task.reminderDate, reminderDate > Date() {
                    NotificationManager.shared.scheduleNotification(for: task) { result in
                        if case .failure = result {
                            // 权限被拒绝，静默清除 reminderDate（列表视图不显示弹窗）
                            task.reminderDate = nil
                            try? modelContext.save()
                            #if DEBUG
                            print("⚠️ 通知权限不足，已清除提醒时间")
                            #endif
                        }
                    }
                }
            }
            
            // 保存更改
            do {
                try modelContext.save()
                #if DEBUG
                let debugNow = Date()
                let isOverdueResult = task.dueDate.map { $0 < debugNow } ?? false
                let fromList = wasCompleted ? "已完成" : (
                    task.dueDate.map { $0 < debugNow } ?? false ? "已逾期" : "全部/其他"
                )
                let toList: String = {
                    if task.isCompleted { return "已完成" }
                    if isOverdueResult { return "已逾期" }
                    if task.dueDate == nil { return "全部/无日期" }
                    return "全部/已计划/即将到来"
                }()
                print("[Toggle] id=\(task.id.uuidString.prefix(8)) isCompleted=\(task.isCompleted) dueDate=\(task.dueDate.map { String(describing: $0) } ?? "nil") now=\(debugNow) isOverdue=\(isOverdueResult)")
                print("  从 \(fromList) 移除 → 加入 \(toList)")
                #endif
            } catch {
                // 如果保存失败，回滚状态
                task.isCompleted = wasCompleted
                #if DEBUG
                print("❌ 保存任务状态失败: \(error)")
                #endif
            }
        }
    }
}

// 键盘快捷键帮助面板
#if os(macOS)
struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    
    struct ShortcutItem {
        let key: String
        let description: String
    }
    
    let shortcuts: [ShortcutItem] = [
        ShortcutItem(key: "⌘N", description: "新建任务"),
        ShortcutItem(key: "⌘⇧N", description: "新建列表"),
        ShortcutItem(key: "⌘B", description: "批量操作模式"),
        ShortcutItem(key: "⌘/", description: "显示快捷键帮助"),
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("键盘快捷键")
                    .font(.headline)
                    .padding()
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                .padding()
            }
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 快捷键列表
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(shortcuts, id: \.key) { shortcut in
                        HStack {
                            Text(shortcut.key)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            
                            Text(shortcut.description)
                                .font(.body)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // 系统快捷键
                    VStack(alignment: .leading, spacing: 12) {
                        Text("系统快捷键")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        HStack {
                            Text("⌘W")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            Text("关闭窗口")
                        }
                        .padding(.horizontal)
                        
                        HStack {
                            Text("⌘Q")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            Text("退出应用")
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .frame(width: 400, height: 500)
    }
}
#endif

#Preview {
    ContentView()
        .modelContainer(for: [Task.self, TaskList.self, Tag.self], inMemory: true)
}
