//
//  SmartListFilter.swift
//  TodoAPP
//
//  智能列表筛选规则集中管理
//  方案A：统一的筛选逻辑，避免时区和边界问题
//

import Foundation

struct SmartListFilter {
    
    // MARK: - 日期判定辅助函数
    
    /// 判断日期是否在今天（避免时区问题）
    static func isToday(_ date: Date) -> Bool {
        return Calendar.current.isDateInToday(date)
    }
    
    /// 判断日期是否在过去（不包括今天）
    static func isPast(_ date: Date, now: Date = Date()) -> Bool {
        let startOfToday = Calendar.current.startOfDay(for: now)
        return date < startOfToday
    }
    
    /// 判断日期是否在未来（不包括今天）
    static func isFuture(_ date: Date, now: Date = Date()) -> Bool {
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        return date >= endOfToday
    }
    
    /// 判断日期是否在未来N天内（包括今天未来部分）
    static func isWithinNextDays(_ date: Date, days: Int, now: Date = Date()) -> Bool {
        let startOfToday = Calendar.current.startOfDay(for: now)
        let endOfPeriod = Calendar.current.date(byAdding: .day, value: days, to: startOfToday)!
        // 包含今天：date >= now（今天此刻之后） && date < 未来N天结束
        return date >= now && date < endOfPeriod
    }
    
    // MARK: - 核心筛选规则
    
    /// 1) All（全部）：仅显示未完成任务
    static func filterAll(_ tasks: [Task]) -> [Task] {
        return tasks.filter { !$0.isCompleted }
    }
    
    /// 2) Completed（已完成）：仅显示已完成任务
    static func filterCompleted(_ tasks: [Task]) -> [Task] {
        return tasks.filter { $0.isCompleted }
    }
    
    /// 3) Today（今天）：未完成任务中满足任一条件
    /// - createdAt 在今天
    /// - dueDate 在今天
    /// - reminderDate 在今天
    /// **重要**: Today 不包含 Overdue（dueDate < now 的任务不出现在 Today）
    static func filterToday(_ tasks: [Task], now: Date = Date()) -> [Task] {
        return tasks.filter { task in
            guard !task.isCompleted else { return false }
            
            // 关键规则：如果 dueDate 已逾期（dueDate < now），则属于 Overdue 而不是 Today
            if let dueDate = task.dueDate, dueDate < now {
                return false
            }
            
            // 条件 a: createdAt 在今天
            if isToday(task.createdAt) {
                return true
            }
            
            // 条件 b: dueDate 在今天
            if let dueDate = task.dueDate, isToday(dueDate) {
                return true
            }
            
            // 条件 c: reminderDate 在今天
            if let reminderDate = task.reminderDate, isToday(reminderDate) {
                return true
            }
            
            return false
        }
    }
    
    /// 4) Overdue（已逾期）：未完成 && dueDate != nil && dueDate < now（精确当前时刻）
    /// 规则来源：dueDate 存在 && dueDate < now && isCompleted == false
    /// ⚠️ 不使用 startOfDay，确保今天已过时刻的任务也能正确进入逾期
    static func filterOverdue(_ tasks: [Task], now: Date = Date()) -> [Task] {
        return tasks.filter { task in
            guard !task.isCompleted,
                  let dueDate = task.dueDate else { return false }
            return dueDate < now
        }
    }
    
    /// 5) Upcoming（即将到来）：未完成 && (dueDate 或 reminderDate) 在未来7天窗口内
    /// 包含今天未来时刻的任务
    /// 5) Upcoming（即将到来）
    /// 规则：completed == false
    ///       AND reminderDate != nil
    ///       AND reminderDate > now          （已过期的 reminder 不显示）
    ///       AND reminderDate <= now + 7天
    /// ⚠️ dueDate-only 任务不进入 Upcoming；排序按 reminderDate 升序
    static func filterUpcoming(_ tasks: [Task], now: Date = Date()) -> [Task] {
        let endOfWindow = Calendar.current.date(
            byAdding: .day, value: 7,
            to: Calendar.current.startOfDay(for: now)
        )!

        return tasks
            .filter { task in
                guard !task.isCompleted,
                      let reminder = task.reminderDate
                else { return false }
                // reminder 必须严格在 now 之后，且在 7 天窗口内
                return reminder > now && reminder < endOfWindow
            }
            .sorted { ($0.reminderDate ?? .distantFuture) < ($1.reminderDate ?? .distantFuture) }
    }
    
    /// 6) Scheduled（已计划）：有 dueDate 的未完成任务
    static func filterScheduled(_ tasks: [Task]) -> [Task] {
        return tasks.filter { $0.dueDate != nil && !$0.isCompleted }
    }
    
    /// 7) Flagged（重要）：高优先级的未完成任务
    static func filterFlagged(_ tasks: [Task]) -> [Task] {
        return tasks.filter {
            ($0.priority == .high || $0.priority == .urgent) && !$0.isCompleted
        }
    }
    
    /// 8) NoDate（无日期）：没有截止日期的未完成任务
    static func filterNoDate(_ tasks: [Task]) -> [Task] {
        return tasks.filter { $0.dueDate == nil && !$0.isCompleted }
    }
}

// MARK: - 验收用例（更新版）

/*
 ## 真机验证用例 T1~T6（确保 badge 与页面内容一致）
 
 ### T1: 今天新建，无任何日期
 - 标题: "T1-今天新建无日期"
 - createdAt: 2026-02-22 (今天)
 - dueDate: nil
 - reminderDate: nil
 - completed: false
 
 **预期结果**:
 - ✅ 出现在: All, Today, NoDate
 - ❌ 不出现在: Completed, Overdue, Upcoming, Scheduled
 - **Badge 验证**: All=6, Today=3, NoDate=2
 
 ---
 
 ### T2: 只设置今天的 reminderDate（无 dueDate）
 - 标题: "T2-今天提醒无截止"
 - createdAt: 2026-02-22 (今天)
 - dueDate: nil
 - reminderDate: 2026-02-22 15:00
 - completed: false
 
 **预期结果**:
 - ✅ 出现在: All, Today, NoDate
 - ❌ 不出现在: Completed, Overdue, Upcoming, Scheduled
 - **关键**: 验证 Upcoming 不会错误包含此任务（因为 reminderDate 是今天，不是未来）
 
 ---
 
 ### T3: 只设置明天的 reminderDate（无 dueDate）
 - 标题: "T3-明天提醒无截止"
 - createdAt: 2026-02-22 (今天)
 - dueDate: nil
 - reminderDate: 2026-02-23 10:00 (明天)
 - completed: false
 
 **预期结果**:
 - ✅ 出现在: All, Today (因为 createdAt 今天), Upcoming, NoDate
 - ❌ 不出现在: Completed, Overdue, Scheduled
 - **关键**: 验证只有 reminderDate 的任务也会出现在 Upcoming！
 - **Badge 验证**: Upcoming badge 必须包含此任务
 
 ---
 
 ### T4: 昨天截止（逾期任务）
 - 标题: "T4-昨天就该完成"
 - createdAt: 2026-02-22 (今天)
 - dueDate: 2026-02-21 (昨天)
 - reminderDate: nil 或 2026-02-22 (今天)
 - completed: false
 
 **预期结果**:
 - ✅ 出现在: All, Overdue, Scheduled
 - ❌ 不出现在: Today, Upcoming, Completed
 - **关键**: 即使 createdAt 或 reminderDate 是今天，因为 dueDate 已逾期，不应出现在 Today！
 - **Badge 验证**: Overdue=1, Today 不包含此任务
 
 ---
 
 ### T5: 3天后截止
 - 标题: "T5-3天后截止"
 - createdAt: 2026-02-22 (今天)
 - dueDate: 2026-02-25 (3天后)
 - reminderDate: nil
 - completed: false
 
 **预期结果**:
 - ✅ 出现在: All, Upcoming, Scheduled
 - ❌ 不出现在: Today, Overdue, Completed
 - **Badge 验证**: Upcoming 包含 T3 和 T5
 
 ---
 
 ### T6: 已完成任务
 - 标题: "T6-已完成任务"
 - createdAt: 任意
 - dueDate: 任意
 - completed: true
 
 **预期结果**:
 - ✅ 出现在: Completed
 - ❌ 不出现在: All, Today, Upcoming, Overdue, Scheduled, NoDate, Flagged
 - **Badge 验证**: 完成后，All 的 badge 数量会减1，Completed 的 badge 数量会加1
 
 ---
 
 ## 📊 预期 Badge 数量汇总表
 
 创建 T1~T5 后（T6 未完成时）:
 
 | 智能列表 | Badge 数量 | 包含任务 |
 |---------|-----------|---------|
 | All | 5 | T1, T2, T3, T4, T5 |
 | Today | 3 | T1, T2, T3 |
 | Upcoming | 2 | T3, T5 |
 | Overdue | 1 | T4 |
 | Scheduled | 2 | T4, T5 |
 | NoDate | 3 | T1, T2, T3 |
 | Completed | 0 | - |
 
 完成 T6 后:
 
 | 智能列表 | Badge 数量 | 包含任务 |
 |---------|-----------|---------|
 | All | 5 | T1, T2, T3, T4, T5 |
 | Completed | 1 | T6 |
 
 ---
 
 ## ✅ 验收检查清单
 
 ### 问题1: Overdue Badge 与内容一致性
 - [ ] Overdue badge 显示 1
 - [ ] 点击进入 Overdue 页面，显示 1 个任务（T4）
 - [ ] T4 在 Overdue 页面点击可以正常查看详情
 
 ### 问题2: Upcoming 包含 reminder-only 任务
 - [ ] T3（只设置 reminderDate 明天）出现在 Upcoming
 - [ ] Upcoming badge 显示 2（包含 T3 和 T5）
 - [ ] T2（reminderDate 今天）不应出现在 Upcoming
 
 ### 核心规则验证
 - [ ] Today 不包含 Overdue（T4 不在 Today）
 - [ ] 完成任务后，badge 立即更新
 - [ ] 每个列表的 badge 数量与点击进入后看到的任务数量完全一致
 
 ---
 
 ## 🔧 统一数据源保证
 
 **Badge 计数**: `countForFilter()` → 调用 `SmartListFilter.filterXXX(tasks)`
 **页面展示**: `filteredTasks` → 调用 `SmartListFilter.filterXXX(filtered)`
 
 两者使用相同的筛选函数，确保数据一致性！
 */
