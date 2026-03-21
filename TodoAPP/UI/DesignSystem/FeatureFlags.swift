// FeatureFlags.swift
// TickTick — Feature Flags
// 用于控制新旧 UI 的切换，方便快速回滚

import Foundation

enum FeatureFlags {
    /// 控制首页（"今天" Tab）UI
    /// - true  → 使用新版 TodayDashboardView（暗紫渐变 + 玻璃拟态）
    /// - false → 回滚到经典 ListDashboardView
    static let useTodayDashboard: Bool = true

    /// 任务完成时的萤火闪光动效 + 触感反馈
    /// - true  → 启用 FireflyCompleteEffect 动画与 Haptics
    /// - false → 无动效，仅切换图标（线上回滚用）
    static let enableFireflyEffects: Bool = true
}
