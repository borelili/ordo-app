//
//  CalendarView.swift
//  TodoAPP
//
//  Created on 2026/02/23
//
//  日历 MVP — 规则：
//  displayDate = task.dueDate ?? task.reminderDate
//  无 dueDate 且无 reminderDate 的任务不进入日历
//

import SwiftUI
import SwiftData

// MARK: - CalendarView (主视图)

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var theme: ThemeManager
    @Query private var tasks: [Task]

    @State private var displayMonth: Date = CalendarHelper.startOfMonth(for: Date())
    @State private var selectedDate: Date  = CalendarHelper.startOfDay(for: Date())
    @State private var showCompleted: Bool = false

    private let calendar = CalendarHelper.current
    private let columns  = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    /// 底部日期标题格式：M月d日 EEEE
    private let selectedDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "M月d日 EEEE"
        return fmt
    }()

    // MARK: - Computed

    private var monthTitle: String {
        let fmt = DateFormatter()
        fmt.locale    = Locale(identifier: "zh_CN")
        fmt.dateFormat = "yyyy年M月"
        return fmt.string(from: displayMonth)
    }

    private var leadingEmpties: Int {
        let weekday = calendar.component(.weekday, from: displayMonth)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: displayMonth)?.count ?? 30
    }

    /// 单一网格数组：nil = 空白格，Int = 当月日期数。
    /// 用数组下标作唯一 ID，避免两个 ForEach 整数 ID 冲突导致 SwiftUI 跳过重复格子。
    private var gridCells: [Int?] {
        Array(repeating: nil, count: leadingEmpties) + (1 ... daysInMonth).map { Optional($0) }
    }

    /// 日期 → 是否有任务（含已完成，用于标点）
    private func hasTasks(on date: Date) -> Bool {
        tasks.contains { task in
            guard let d = task.dueDate ?? task.reminderDate else { return false }
            return calendar.isDate(d, inSameDayAs: date)
        }
    }

    /// 当前选中日期的任务列表
    private var tasksOnSelectedDate: [Task] {
        tasks
            .filter { task in
                guard let d = task.dueDate ?? task.reminderDate else { return false }
                guard calendar.isDate(d, inSameDayAs: selectedDate) else { return false }
                return showCompleted ? true : !task.isCompleted
            }
            .sorted { lhs, rhs in
                // 未完成在前，同状态按 displayDate，再按创建时间
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                let ld = lhs.dueDate ?? lhs.reminderDate ?? lhs.createdAt
                let rd = rhs.dueDate ?? rhs.reminderDate ?? rhs.createdAt
                return ld < rd
            }
    }

    /// 从 displayMonth 的第 `day` 天构造 Date（用 dateComponents 直接赋值，避免 bySetting 跨月 bug）
    private func date(forDay day: Int) -> Date {
        var comps = calendar.dateComponents([.year, .month], from: displayMonth)
        comps.day = day
        return calendar.date(from: comps) ?? displayMonth
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthHeader
                    .padding(.horizontal)
                    .padding(.top, 8)

                weekdayHeader
                    .padding(.horizontal, 4)
                    .padding(.top, 4)

                Divider().padding(.top, 4)

                monthGrid
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)

                Divider()

                taskListSection
            }
            .navigationTitle("日历")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.clear)
            .toolbarBackground(.hidden, for: .navigationBar)
            .onAppear {
                #if DEBUG
                let gridFirst = date(forDay: 1)
                let gridLast  = date(forDay: daysInMonth)
                print("[Calendar.onAppear] displayMonth=\(displayMonth)")
                print("                    selectedDate=\(selectedDate)")
                print("                    gridFirst=\(gridFirst)  gridLast=\(gridLast)")
                print("                    leadingEmpties=\(leadingEmpties)  daysInMonth=\(daysInMonth)")
                #endif
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle(isOn: $showCompleted) {
                        Label("已完成", systemImage: "checkmark.circle")
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .tint(.secondary)
                    .font(.caption)
                }
            }
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(theme.current.textPrimary)

            Spacer()

            Text(monthTitle)
                .font(.headline)
                .foregroundColor(theme.current.textPrimary)

            Spacer()

            Button {
                moveMonth(by: +1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundColor(theme.current.textPrimary)
        }
    }

    // MARK: - Weekday Row

    private var weekdayHeader: some View {
        let symbols = orderedWeekdaySymbols()
        return LazyVGrid(columns: columns, spacing: 0) {
            // 必须用 indices 作 ID，避免 "T"/"S" 重复字符串被 SwiftUI 去重跳过
            ForEach(symbols.indices, id: \.self) { i in
                Text(symbols[i])
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Month Grid

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            // 用下标作唯一 ID：空白格 id 0..<leadingEmpties，日期格 id leadingEmpties...
            ForEach(gridCells.indices, id: \.self) { idx in
                if let day = gridCells[idx] {
                    let cellDate   = date(forDay: day)
                    let isToday    = calendar.isDateInToday(cellDate)
                    let isSelected = calendar.isDate(cellDate, inSameDayAs: selectedDate)
                    let hasTask    = hasTasks(on: cellDate)
                    CalendarDayCell(
                        day: day,
                        isToday: isToday,
                        isSelected: isSelected,
                        hasTask: hasTask
                    )
                    .onTapGesture { selectedDate = cellDate }
                } else {
                    Color.clear.frame(height: 44)
                }
            }
        }
    }

    // MARK: - Task List

    private var taskListSection: some View {
        VStack(spacing: 0) {
            // 标题行
            HStack {
                Text(selectedDateFormatter.string(from: selectedDate))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(theme.current.textPrimary)
                Spacer()
                let count = tasksOnSelectedDate.count
                if count > 0 {
                    Text("\(count) 项任务")
                        .font(.caption)
                        .foregroundColor(theme.current.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if tasksOnSelectedDate.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("无任务")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(tasksOnSelectedDate) { task in
                        CalendarTaskRow(task: task)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                // 统一底部避让：直接用 List 上，避免外层 NavigationStack safeAreaInset 传播失效
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: DS.homeBottomInset)
                }
            }
        }
    }

    // MARK: - Helpers

    private func moveMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayMonth) else { return }
        displayMonth = newMonth

        // selectedDate 同步：
        // 1) 若新月份包含今天 → 选今天
        // 2) 若 selectedDate 不在新月份 → 选新月 1 号（newMonth 已是该月 startOfMonth）
        if isInMonth(Date(), month: newMonth) {
            selectedDate = CalendarHelper.startOfDay(for: Date())
        } else if !isInMonth(selectedDate, month: newMonth) {
            selectedDate = newMonth
        }

        #if DEBUG
        let gridFirst = date(forDay: 1)
        let gridLast  = date(forDay: daysInMonth)
        print("[Calendar] displayMonth=\(displayMonth)")
        print("           selectedDate=\(selectedDate)")
        print("           gridFirst=\(gridFirst)  gridLast=\(gridLast)")
        print("           leadingEmpties=\(leadingEmpties)  daysInMonth=\(daysInMonth)")
        #endif
    }

    /// 判断 date 是否与 month 同年同月
    private func isInMonth(_ date: Date, month: Date) -> Bool {
        calendar.isDate(date, equalTo: month, toGranularity: .month)
    }

    /// 按系统 firstWeekday 重排中文星期符号
    /// Calendar.weekday: 1=日, 2=一, ..., 7=六
    private func orderedWeekdaySymbols() -> [String] {
        let symbols = ["日", "一", "二", "三", "四", "五", "六"]  // index 0=Sun
        let first = calendar.firstWeekday - 1                    // 0-based
        return Array(symbols[first...]) + Array(symbols[..<first])
    }
}

// MARK: - CalendarDayCell

private struct CalendarDayCell: View {
    let day: Int
    let isToday: Bool
    let isSelected: Bool
    let hasTask: Bool
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        ZStack {
            // 背景圈
            if isSelected {
                Circle()
                    .fill(theme.current.primaryAccent)
                    .frame(width: 34, height: 34)
            } else if isToday {
                Circle()
                    .strokeBorder(theme.current.primaryAccent, lineWidth: 1.5)
                    .frame(width: 34, height: 34)
            }

            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.system(size: 14, weight: isToday || isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : (isToday ? theme.current.primaryAccent : theme.current.textPrimary))

                // 任务标记点
                Circle()
                    .fill(isSelected ? Color.white.opacity(0.9) : theme.current.primaryAccent)
                    .frame(width: 5, height: 5)
                    .opacity(hasTask ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .contentShape(Rectangle())
    }
}

// MARK: - CalendarTaskRow

private struct CalendarTaskRow: View {
    @Bindable var task: Task
    @EnvironmentObject private var theme: ThemeManager

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // 完成状态图标（只读展示，不可点击修改日历中的状态）
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(task.isCompleted ? theme.current.successColor : theme.current.textSecondary.opacity(0.7))
                .symbolRenderingMode(.hierarchical)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.body.weight(task.isCompleted ? .regular : .medium))
                    .foregroundColor(task.isCompleted ? theme.current.textSecondary : theme.current.textPrimary)
                    .strikethrough(task.isCompleted, color: theme.current.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // 来源：dueDate 或 reminderDate 标注
                    if task.dueDate != nil {
                        Label(timeString(task.dueDate!), systemImage: "calendar")
                            .font(.caption2)
                            .foregroundColor(dueDateColor(task))
                    } else if let r = task.reminderDate {
                        Label(timeString(r), systemImage: "bell")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // 优先级
                    if task.priority != .medium {
                        Text(task.priority.rawValue)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(task.priority.color.opacity(0.85))
                            .clipShape(Capsule())
                    }

                    // 所属列表
                    if let list = task.taskList {
                        Label(list.name, systemImage: list.icon)
                            .font(.caption2)
                            .foregroundColor(list.colorValue)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(theme.current.cardBorderColor, lineWidth: 1)
            }
        )
    }

    private func timeString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "zh_CN")
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: date)
    }

    private func dueDateColor(_ task: Task) -> Color {
        guard let d = task.dueDate else { return .secondary }
        return d < Date() && !task.isCompleted ? .red : .secondary
    }
}

// MARK: - CalendarHelper

enum CalendarHelper {
    static let current = Calendar.current

    static func startOfMonth(for date: Date) -> Date {
        let comps = current.dateComponents([.year, .month], from: date)
        return current.date(from: comps) ?? date
    }

    static func startOfDay(for date: Date) -> Date {
        current.startOfDay(for: date)
    }
}

// MARK: - Preview

#Preview {
    let config     = ModelConfiguration(isStoredInMemoryOnly: true)
    let container  = try! ModelContainer(for: Task.self, TaskList.self, Tag.self, configurations: config)
    let ctx        = container.mainContext

    // 插入示例任务
    let t1 = Task(title: "写周报", dueDate: Date())
    let t2 = Task(title: "买菜", reminderDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()))
    let t3 = Task(title: "无日期任务")   // 不进入日历
    ctx.insert(t1); ctx.insert(t2); ctx.insert(t3)

    return CalendarView()
        .modelContainer(container)
}
