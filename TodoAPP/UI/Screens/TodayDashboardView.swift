// TodayDashboardView.swift
// TickTick — UI/Screens
//
// 今日仪表盘：暗紫渐变背景 + 玻璃卡片 + 周历条 + 进度环 + 胶囊筛选
// ─────────────────────────────────────────────────────────────
// 架构约定
//   · 数据层零改动：SmartListFilter、Task 模型保持原样
//   · 重计算隔离：TodayStats 在 private var 中计算，不在 body 内直接调用
//   · 列表性能：ScrollView + LazyVStack，避免 List 内嵌 LazyVStack
//   · 任务行：复用 ContentView.swift 中已有的 TaskRowView
//
// 性能测试清单（注释形式）：
//   [ ] 创建 100 条任务，快速滚动，不掉帧
//   [ ] 完成 50 条，进度环与计数 realtime 更新
//   [ ] 切换深色模式：布局正常
//   [ ] 最大字号 (accessibilityExtraExtraExtraLarge)：行高自适应，无截断
//   [ ] Reduce Motion 开启：动画降级（SwiftUI 自动处理 withAnimation）
//
// 回滚方式：将 FeatureFlags.useTodayDashboard 改为 false
// ─────────────────────────────────────────────────────────────

import SwiftUI
import SwiftData

// MARK: - Filter Pill Enum

enum TodayFilterPill: String, CaseIterable {
    case all        = "全部"
    case inProgress = "进行中"
    case overdue    = "逾期"
    case noDate     = "无日期"

    var icon: String {
        switch self {
        case .all:        return "tray.fill"
        case .inProgress: return "clock"
        case .overdue:    return "exclamationmark.triangle"
        case .noDate:     return "calendar.badge.minus"
        }
    }

    func accessibilityHint(_ count: Int) -> String {
        "\(rawValue)，共 \(count) 项"
    }
}

// MARK: - Stats Model（在 body 外计算，避免重算）

struct TodayStats {
    let todayPending: Int     // 今日待完成任务数
    let completedToday: Int   // 今日已完成数
    let overdueCount: Int     // 逾期任务数
    let reminderCount: Int    // 有今日提醒的任务数
    let progressTotal: Int    // 进度环：分母
    let progress: Double      // 0...1

    init(tasks: [Task], now: Date = Date()) {
        let cal = Calendar.current
        let todayTasks = SmartListFilter.filterToday(tasks, now: now)
        let overdueTasks = SmartListFilter.filterOverdue(tasks, now: now)

        let completed = tasks.filter { task in
            guard task.isCompleted else { return false }
            if cal.isDateInToday(task.updatedAt) { return true }
            if let d = task.dueDate, cal.isDateInToday(d) { return true }
            if cal.isDateInToday(task.createdAt) { return true }
            return false
        }

        let withReminder = tasks.filter { task in
            guard let r = task.reminderDate else { return false }
            return cal.isDateInToday(r) && !task.isCompleted
        }

        self.todayPending   = todayTasks.count
        self.completedToday = completed.count
        self.overdueCount   = overdueTasks.count
        self.reminderCount  = withReminder.count
        self.progressTotal  = todayTasks.count + completed.count

        let denom = Double(todayTasks.count + completed.count)
        self.progress = denom > 0 ? Double(completed.count) / denom : 0
    }
}

// MARK: - TodayDashboardView

struct TodayDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Task.order) private var allTasks: [Task]
    @StateObject private var dateRefresher = DateRefresher()
    @EnvironmentObject private var theme: ThemeManager

    @State private var selectedDate: Date = Date()
    @State private var selectedPill: TodayFilterPill = .all
    @State private var showingAddTask = false
    @State private var showingProfileSettings = false
    @State private var taskToEdit: Task? = nil

    private var now: Date { dateRefresher.currentDate }

    // 今日统计（按日期隔离，不放入 body）
    private var stats: TodayStats {
        TodayStats(tasks: allTasks, now: now)
    }

    // 列表显示的任务（按选中日期 + 胶囊筛选）
    private var displayedTasks: [Task] {
        let cal = Calendar.current
        let isToday = cal.isDateInToday(selectedDate)

        // 基础集合
        let base: [Task]
        if isToday {
            switch selectedPill {
            case .all:
                // 今天：今日任务 + 逾期任务
                let today   = SmartListFilter.filterToday(allTasks, now: now)
                let overdue = SmartListFilter.filterOverdue(allTasks, now: now)
                let ids = Set(overdue.map(\.id))
                base = today + overdue.filter { !ids.contains($0.id) || !today.contains($0) }
            case .inProgress:
                base = SmartListFilter.filterToday(allTasks, now: now)
            case .overdue:
                base = SmartListFilter.filterOverdue(allTasks, now: now)
            case .noDate:
                base = SmartListFilter.filterNoDate(allTasks)
            }
        } else {
            // 非今天：只看 dueDate 匹配的任务
            base = allTasks.filter { task in
                guard !task.isCompleted, let due = task.dueDate else { return false }
                return cal.isDate(due, inSameDayAs: selectedDate)
            }
        }

        // 按 order 排序
        return base.sorted {
            if $0.order == $1.order { return $0.createdAt > $1.createdAt }
            return $0.order < $1.order
        }
    }

    // 各胶囊对应任务数（用于 badge，避免重复计算）
    private var pillCounts: [TodayFilterPill: Int] {
        let today   = SmartListFilter.filterToday(allTasks, now: now)
        let overdue = SmartListFilter.filterOverdue(allTasks, now: now)
        let noDate  = SmartListFilter.filterNoDate(allTasks)
        return [
            .all:        today.count + overdue.count,
            .inProgress: today.count,
            .overdue:    overdue.count,
            .noDate:     noDate.count
        ]
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                Color.clear

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: DS.spacingLG, pinnedViews: []) {
                        // ① 顶部栏
                        topBar
                            .padding(.horizontal, DS.paddingScreen)
                            .padding(.top, DS.spacingSM)

                        // ② 周历条
                        WeekStrip(selectedDate: $selectedDate)

                        // ③ 摘要卡片（stats + 进度环）
                        summaryCard
                            .padding(.horizontal, DS.paddingScreen)

                        // ④ 胶囊筛选行
                        filterPillsRow
                            .padding(.horizontal, DS.paddingScreen)

                        // ⑤ 任务列表
                        taskListSection
                            .padding(.horizontal, DS.paddingScreen)
                    }
                    .padding(.bottom, DS.spacingMD)
                }
                // 统一底部避让：直接施加到层动容器上，不依赖外层 NavigationStack 传播
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: DS.homeBottomInset)
                }
            }
            .navigationBarHidden(true)
            // 任务详情导航
            .navigationDestination(for: Task.self) { task in
                TaskDetailView(task: task)
            }
            // 新增任务 sheet
            .sheet(isPresented: $showingAddTask) {
                AddTaskView()
                    .environmentObject(ErrorHandler.shared)
            }
            // 我的（账户/外观/通知/关于）sheet
            .sheet(isPresented: $showingProfileSettings) {
                ProfileSettingsView()
                    .environmentObject(theme)
            }
        }
        // 刷新时间（回到前台）
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            dateRefresher.refresh()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(todayDateString)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.current.textSecondary)
                Text("今天")
                    .font(.title.bold())
                    .foregroundStyle(theme.current.textPrimary)
            }
            Spacer()
            Button {
                showingProfileSettings = true
            } label: {
                Image(systemName: "person.circle")
                    .font(.title3)
                    .foregroundStyle(theme.current.textSecondary)
                    .accessibilityLabel("我的")
            }
        }
    }

    private var todayDateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: now)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        let s = stats   // 复用同一次计算
        return GlassCard(radius: DS.radiusCard, padding: DS.paddingCard) {
            HStack(alignment: .center, spacing: DS.spacingLG) {
                // 左侧：4 个小指标
                VStack(alignment: .leading, spacing: DS.spacingMD) {
                    StatBadge(label: "今日任务", value: s.todayPending,
                              icon: "sun.max", color: theme.current.secondaryAccent)
                    StatBadge(label: "已完成",   value: s.completedToday,
                              icon: "checkmark.circle", color: theme.current.successColor)
                    StatBadge(label: "逾期",     value: s.overdueCount,
                              icon: "exclamationmark.triangle", color: theme.current.warningColor)
                    StatBadge(label: "有提醒",   value: s.reminderCount,
                              icon: "bell", color: theme.current.primaryAccent)
                }
                Spacer()
                // 右侧：进度环
                ProgressRing(
                    progress: s.progress,
                    completed: s.completedToday,
                    total: s.progressTotal,
                    lineWidth: 10,
                    ringColor: theme.current.primaryAccent,
                    textColor: theme.current.textPrimary,
                    subTextColor: theme.current.textSecondary,
                    size: 100
                )
            }
        }
    }

    // MARK: - Filter Pills Row

    private var filterPillsRow: some View {
        let counts = pillCounts  // 单次计算
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.spacingMD) {
                ForEach(TodayFilterPill.allCases, id: \.self) { pill in
                    PillButton(
                        title: pill.rawValue,
                        icon: pill.icon,
                        isSelected: selectedPill == pill
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedPill = pill
                        }
                    }
                    .accessibilityHint(pill.accessibilityHint(counts[pill] ?? 0))
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Task List Section

    private var taskListSection: some View {
        let tasks = displayedTasks
        return Group {
            if tasks.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: DS.spacingMD) {
                    ForEach(tasks) { task in
                        NavigationLink(value: task) {
                            TaskRowView(task: task)
                                .glassTaskRow()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(theme.current.primaryAccent.opacity(0.6))
            Text("暂无任务")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.current.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.spacingLG * 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("暂无任务")
    }
}

// MARK: - Stat Badge（摘要卡片内的单条指标）

private struct StatBadge: View {
    @EnvironmentObject private var theme: ThemeManager
    let label: String
    let value: Int
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: DS.spacingXS + 2) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(theme.current.textSecondary)
            Spacer()
            Text("\(value)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label)：\(value)")
    }
}

// MARK: - GlassTaskRow Modifier（任务行的玻璃背景）

private struct GlassTaskRowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.04) : Color.clear)
                    RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                        .strokeBorder(
                            colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08),
                            lineWidth: 1
                        )
                }
            )
            .cardShadow(DS.Shadow.subtle)
    }
}

private extension View {
    func glassTaskRow() -> some View {
        modifier(GlassTaskRowModifier())
    }
}

// MARK: - Previews

#Preview("TodayDashboardView") {
    TodayDashboardView()
        .preferredColorScheme(.dark)
}

#Preview("TodayDashboardView — Large Text") {
    TodayDashboardView()
        .preferredColorScheme(.dark)
        .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
