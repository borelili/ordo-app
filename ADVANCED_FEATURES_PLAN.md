# 高级功能开发计划 (B阶段)

## 概述
在 v1.0.0 核心功能完成基础上，实现高级功能以提升用户效率和体验。

## 目标功能清单

### 1. 批量操作功能 ⏳
**优先级**: 高  
**预计工时**: 2-3 小时

#### 功能描述
- 批量选择任务
- 批量移动到其他列表
- 批量标记完成/未完成
- 批量删除
- 批量添加/移除标签

#### 实现要点
```swift
// ContentView 中添加
@State private var selectionMode = false
@State private var selectedTasks: Set<Task> = []

// 批量操作工具栏
if selectionMode {
    HStack {
        Button("完成所有") { batchComplete() }
        Button("移动到...") { showMoveSheet = true }
        Button("删除") { batchDelete() }
    }
}
```

#### 涉及文件
- `ContentView.swift` - 添加选择模式和批量操作按钮
- `TaskRowView.swift` - 添加选择框
- 新增 `BatchOperations.swift` - 批量操作逻辑

---

### 2. 拖拽排序任务 ⏳
**优先级**: 高  
**预计工时**: 2-3 小时

#### 功能描述
- 任务在列表内拖拽排序
- 任务拖拽到其他列表
- 列表拖拽排序（已支持）
- 视觉反馈（拖拽高亮）

#### 实现要点
```swift
// Task 添加顺序属性
@Model
class Task {
    var order: Int = 0  // 新增
    // ... 其他属性
}

// ContentView 使用 .onMove
ForEach(filteredTasks.sorted(by: { $0.order < $1.order })) { task in
    TaskRowView(task: task)
}
.onMove { indices, destination in
    moveTask(from: indices, to: destination)
}
.onDrop(of: [.text], delegate: TaskDropDelegate(...))
```

#### 涉及文件
- `Models/Task.swift` - 添加 order 属性
- `ContentView.swift` - 实现 onMove 和 onDrop
- 新增 `TaskDropDelegate.swift` - 拖拽逻辑

---

### 3. 键盘快捷键 ⏳
**优先级**: 中  
**预计工时**: 1-2 小时

#### 功能描述
- `⌘N` - 新建任务
- `⌘⇧N` - 新建列表
- `⌘T` - 新建标签
- `⌘E` - 编辑选中任务
- `⌘⌫` - 删除选中任务
- `⌘/` - 显示快捷键帮助

#### 实现要点
```swift
// ContentView 添加
.keyboardShortcut("n", modifiers: .command)
.keyboardShortcut("n", modifiers: [.command, .shift])

// 快捷键帮助面板
struct KeyboardShortcutsView: View {
    var body: some View {
        VStack(alignment: .leading) {
            ShortcutRow(key: "⌘N", description: "新建任务")
            ShortcutRow(key: "⌘⇧N", description: "新建列表")
            // ...
        }
    }
}
```

#### 涉及文件
- `ContentView.swift` - 添加快捷键绑定
- `AddTaskView.swift` - 支持快捷键
- 新增 `KeyboardShortcutsView.swift` - 快捷键帮助面板

---

### 4. 智能列表定制 ⏳
**优先级**: 中  
**预计工时**: 3-4 小时

#### 功能描述
- "今天" - 今天到期的任务
- "即将到来" - 7天内到期的任务
- "已逾期" - 过期未完成的任务
- "高优先级" - 高/紧急任务
- "无日期" - 没有设置到期日的任务
- "已完成" - 历史完成任务
- 自定义智能列表（按标签、优先级、创建时间等筛选）

#### 实现要点
```swift
// 新增 Models/SmartList.swift
@Model
class SmartList {
    var name: String
    var icon: String
    var filter: SmartListFilter
    var isSystem: Bool = false  // 系统预设
}

enum SmartListFilter: Codable {
    case today
    case upcoming(days: Int)
    case overdue
    case highPriority
    case noDate
    case completed
    case custom(predicates: [FilterPredicate])
}

// ContentView 添加智能列表分组
Section("智能列表") {
    ForEach(smartLists) { smartList in
        NavigationLink(destination: SmartListView(smartList: smartList)) {
            Label(smartList.name, systemImage: smartList.icon)
                .badge(smartList.taskCount)
        }
    }
}
```

#### 涉及文件
- 新增 `Models/SmartList.swift` - 智能列表模型
- `ContentView.swift` - 添加智能列表侧边栏
- 新增 `Views/SmartListView.swift` - 智能列表视图
- 新增 `Views/SmartListEditorView.swift` - 自定义智能列表编辑器

---

## 实现顺序

### 阶段 1: 基础交互增强 (4-6 小时)
1. **批量操作** - 提升管理效率
2. **拖拽排序** - 直观的任务管理

### 阶段 2: 效率工具 (4-6 小时)
3. **键盘快捷键** - 专业用户必备
4. **智能列表** - 智能任务组织

---

## 技术要点

### 批量操作
- 使用 `Set<Task>` 管理选择状态
- 批量操作需要事务处理（全部成功或全部回滚）
- 提供操作确认对话框（删除、移动）

### 拖拽排序
- macOS 使用 `onDrop` + `DropDelegate`
- iOS 使用 `onMove` + `.moveDisabled(!editMode.isEditing)`
- 需要维护 `order` 属性，并在添加新任务时自动分配

### 键盘快捷键
- macOS 专属功能（iOS 外接键盘有限支持）
- 使用 `@FocusState` 管理焦点状态
- 确保不与系统快捷键冲突

### 智能列表
- 使用 `@Query` 的 filter 参数实现动态查询
- 系统预设列表 vs 用户自定义列表
- 实时计数显示（badge）

---

## 测试计划

### 批量操作测试
- [ ] 选择单个/多个任务
- [ ] 批量完成/未完成切换
- [ ] 批量移动到另一个列表
- [ ] 批量删除（带确认）
- [ ] 批量添加/移除标签

### 拖拽测试
- [ ] 同列表内排序
- [ ] 跨列表拖拽
- [ ] 拖拽视觉反馈
- [ ] 拖拽中途取消

### 快捷键测试
- [ ] 所有快捷键响应正常
- [ ] 快捷键帮助面板显示
- [ ] 与系统快捷键不冲突

### 智能列表测试
- [ ] "今天"列表准确显示
- [ ] "逾期"列表正确筛选
- [ ] 自定义筛选条件生效
- [ ] 实时计数更新

---

## 风险与注意事项

### 性能考虑
- 智能列表的实时计数可能影响性能（建议缓存）
- 大量任务的批量操作需要进度指示器
- 拖拽排序需要优化 SwiftData 查询

### 用户体验
- 批量操作需要明确的视觉反馈
- 拖拽操作需要清晰的目标提示
- 快捷键需要在界面上有可见提示（菜单栏）

### 数据迁移
- 添加 `Task.order` 需要迁移策略（默认值 0）
- 智能列表需要初始化系统预设列表

---

## 下一步行动

1. **创建开发分支**
   ```bash
   git checkout -b feature/advanced-operations
   ```

2. **开始第一个功能**
   - 实现批量操作基础框架
   - 添加选择模式切换按钮
   - 实现批量完成功能

3. **迭代开发**
   - 每完成一个功能提交一次
   - 及时测试验证
   - 更新文档

---

## 完成标准

- ✅ 所有功能正常工作
- ✅ 无性能问题
- ✅ 完整的错误处理
- ✅ 通过所有测试用例
- ✅ 代码审查通过
- ✅ 文档更新完整

---

**状态**: 🟡 规划完成，等待实现  
**预计完成时间**: 8-12 小时  
**目标版本**: v1.1.0
