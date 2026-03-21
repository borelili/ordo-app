// FireflyCompleteEffect.swift
// TickTick — UI/Components
//
// 任务完成时的轻量萤火闪光动效。
// ─────────────────────────────────────────────────
// 使用方式：
//   ZStack {
//       completionButton
//       FireflyCompleteEffect(visible: $sparkleActive)
//   }
//
// 动效策略：
//   · 普通模式：8 粒子径向散射 + 中心亮光 + sparkle 符号旋转淡出
//   · Reduce Motion：仅做一次快速 opacity 闪光，无位移/旋转
//   · phase 到达 1.0 后所有层完全透明（opacity = 0），不持续占用渲染
//   · allowsHitTesting(false) 确保不拦截手势
//
// FeatureFlag：由调用方（TaskRowView）判断 FeatureFlags.enableFireflyEffects
// ─────────────────────────────────────────────────

import SwiftUI

// MARK: - FireflyCompleteEffect

struct FireflyCompleteEffect: View {

    /// 外部通过 Binding 传入，值变为 true 触发动画；
    /// 动画结束后会自动重置为 false。
    @Binding var visible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: CGFloat = 0          // 0 → 1，驱动全部动效
    @State private var sparkleRotation: Double = 0
    @State private var flashOpacity: Double = 0    // Reduce Motion 专用

    // ── 静态数据（避免 body 内重建）
    private let particleAngles: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]
    private let particleColors: [Color] = [
        .yellow,
        Color(red: 1.0, green: 0.85, blue: 0.2),
        .orange,
        Color(red: 1.0, green: 0.95, blue: 0.5),
        .white,
        Color(red: 1.0, green: 0.90, blue: 0.3),
        .orange,
        .yellow
    ]

    var body: some View {
        ZStack {
            if reduceMotion {
                // ── Reduce Motion：纯淡入淡出闪光
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.yellow.opacity(0.9), Color.yellow.opacity(0)],
                            center: .center,
                            startRadius: 0,
                            endRadius: 18
                        )
                    )
                    .frame(width: 36, height: 36)
                    .opacity(flashOpacity)
            } else {
                // ── 普通模式：粒子散射 + sparkle 旋转淡出
                let p = phase

                // 8 粒子
                ForEach(0..<8, id: \.self) { i in
                    let rad = CGFloat(particleAngles[i] * .pi / 180.0)
                    Circle()
                        .fill(particleColors[i])
                        .frame(
                            width:  max(0, 7.0 - p * 4.0),
                            height: max(0, 7.0 - p * 4.0)
                        )
                        .shadow(
                            color: particleColors[i].opacity(Double(max(0, 0.9 - p * 0.9))),
                            radius: max(0, 4.0 - p * 4.0)
                        )
                        .opacity(Double(max(0, 1.0 - p * 1.4)))
                        .offset(
                            x: cos(rad) * 36.0 * p,
                            y: sin(rad) * 36.0 * p
                        )
                }

                // 中心柔光晕
                Circle()
                    .fill(Color.yellow.opacity(Double(max(0, 0.8 - p * 0.8))))
                    .frame(
                        width:  14.0 + p * 10.0,
                        height: 14.0 + p * 10.0
                    )
                    .blur(radius: 3.0 + p * 5.0)

                // sparkle 符号（旋转淡出）
                Image(systemName: "sparkle")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Color.yellow.opacity(Double(max(0, 1.0 - p * 1.5))))
                    .rotationEffect(.degrees(sparkleRotation))
                    .scaleEffect(0.7 + p * 0.5)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)          // 纯装饰，VoiceOver 跳过
        // ── 触发入口
        .onChange(of: visible) { newValue in
            guard newValue else { return }
            if reduceMotion {
                playReducedMotion()
            } else {
                playFullAnimation()
            }
        }
    }

    // MARK: - Play Full Animation

    private func playFullAnimation() {
        phase = 0
        sparkleRotation = 0

        withAnimation(.easeOut(duration: 0.45)) {
            phase = 1
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            sparkleRotation = 120
        }
        // 动画结束后重置 visible（让外部状态归零，GC 视图资源）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            visible = false
            phase = 0
            sparkleRotation = 0
        }
    }

    // MARK: - Play Reduced Motion Animation

    private func playReducedMotion() {
        flashOpacity = 0
        withAnimation(.easeIn(duration: 0.12)) {
            flashOpacity = 0.85
        }
        withAnimation(.easeOut(duration: 0.25).delay(0.12)) {
            flashOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            visible = false
        }
    }
}

// MARK: - Previews

#Preview("FireflyCompleteEffect — Normal") {
    ZStack {
        Color.black.ignoresSafeArea()
        FireflyCompleteEffectPreviewHelper()
    }
}

// 注：accessibilityReduceMotion 为只读环境值，
// 无法在 Preview 中通过 .environment 强制设置；
// 在设备上请前往「设置 → 辅助功能 → 减少动态效果」手动验证。
#Preview("FireflyCompleteEffect — Dark") {
    ZStack {
        Color.black.ignoresSafeArea()
        FireflyCompleteEffectPreviewHelper()
    }
    .preferredColorScheme(.dark)
}

/// 预览辅助：提供触发按钮
private struct FireflyCompleteEffectPreviewHelper: View {
    @State private var sparkle = false
    var body: some View {
        ZStack {
            Button("触发动效") { sparkle = true }
                .foregroundStyle(.white)
            FireflyCompleteEffect(visible: $sparkle)
        }
    }
}
