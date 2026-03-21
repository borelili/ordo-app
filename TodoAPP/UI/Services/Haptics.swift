// Haptics.swift
// TickTick — UI/Services
//
// 触感反馈服务。
//   · iOS 17+ 可直接用 .sensoryFeedback modifier；此处封装为命令式调用，
//     以便在非 SwiftUI 层（状态机、业务回调）中也能使用。
//   · 触感必须由明确用户操作触发，不在动画回调或计时器中调用。
//   · Reduce Motion 开启时不额外震动（系统本身会降级，无需手动判断）。

import UIKit

final class Haptics {

    // MARK: - Shared instance

    static let shared = Haptics()
    private init() {}

    // MARK: - Generators（惰性创建，避免主线程卡顿）

    private lazy var completionGenerator: UINotificationFeedbackGenerator = {
        let g = UINotificationFeedbackGenerator()
        g.prepare()
        return g
    }()

    private lazy var lightImpact: UIImpactFeedbackGenerator = {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare()
        return g
    }()

    // MARK: - Public API

    /// 任务标记为完成：使用 .success 通知震动（清脆满足感）
    func taskCompleted() {
        completionGenerator.notificationOccurred(.success)
        completionGenerator.prepare()   // 为下一次提前暖机
    }

    /// 取消完成：轻撞击（存在感更低；如需完全静默可改为 noop）
    func taskUncompleted() {
        lightImpact.impactOccurred(intensity: 0.5)
        lightImpact.prepare()
    }
}
