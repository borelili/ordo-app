//
//  ListBadgeService.swift
//  TodoAPP
//
//  Created on 2026/02/23
//
//  集中管理徽标数量计算，UI 层直接调用，避免重复写过滤逻辑。
//  所有计数只统计 isCompleted == false 的任务。
//

import Foundation

enum ListBadgeService {

    // MARK: - 智能列表 badge

    /// 智能列表某 filter 的未完成任务数
    static func count(
        for filter: ContentView.TaskFilter,
        tasks: [Task],
        now: Date = Date()
    ) -> Int {
        switch filter {
        case .all:       return SmartListFilter.filterAll(tasks).count
        case .today:     return SmartListFilter.filterToday(tasks, now: now).count
        case .upcoming:  return SmartListFilter.filterUpcoming(tasks, now: now).count
        case .overdue:   return SmartListFilter.filterOverdue(tasks, now: now).count
        case .scheduled: return SmartListFilter.filterScheduled(tasks).count
        case .flagged:   return SmartListFilter.filterFlagged(tasks).count
        case .noDate:    return SmartListFilter.filterNoDate(tasks).count
        case .completed: return SmartListFilter.filterCompleted(tasks).count
        }
    }

    // MARK: - 自定义列表 badge

    /// 自定义列表的未完成任务数
    static func count(for list: TaskList) -> Int {
        list.tasks?.filter { !$0.isCompleted }.count ?? 0
    }

    // MARK: - 标签 badge

    /// 标签下的未完成任务数
    static func count(for tag: Tag) -> Int {
        tag.tasks?.filter { !$0.isCompleted }.count ?? 0
    }
}
