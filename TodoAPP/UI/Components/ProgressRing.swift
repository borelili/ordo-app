// ProgressRing.swift
// TickTick — Design System
// 今日进度环形图表

import SwiftUI

// MARK: - ProgressRing

struct ProgressRing: View {
    /// 进度 0...1
    var progress: Double
    /// 已完成数量
    var completed: Int
    /// 总数量
    var total: Int
    /// 圆环线宽
    var lineWidth: CGFloat = 10
    /// 主题色（默认 AccentPurple）
    var ringColor: Color = Color.DS.accentPurple
    /// 内部主数字颜色
    var textColor: Color = Color.DS.textPrimary
    /// 内部副数字颜色
    var subTextColor: Color = Color.DS.textSecondary
    /// 尺寸（直径）
    var size: CGFloat = 120

    // 用于驱动动画的内部进度值
    @State private var animatedProgress: Double = 0

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            // 背景环
            Circle()
                .stroke(ringColor.opacity(0.18), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // 进度环
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    AngularGradient(
                        colors: [ringColor.opacity(0.6), ringColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // 内部文字
            VStack(spacing: 2) {
                Text("\(completed)")
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(textColor)
                Text("/ \(total)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(subTextColor)
            }
        }
        // 进度变化时触发动画
        .onChange(of: clampedProgress) { newValue in
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedProgress = newValue
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedProgress = clampedProgress
            }
        }
        // VoiceOver
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("今日进度")
        .accessibilityValue({
            let percent = Int(clampedProgress * 100)
            return "完成 \(completed) / \(total)，百分之 \(percent)"
        }())
    }
}

// MARK: - Previews

#Preview("ProgressRing — 60%") {
    ZStack {
        AppBackgroundGradient()
        ProgressRing(progress: 0.6, completed: 3, total: 5)
    }
}

#Preview("ProgressRing — 100%") {
    ZStack {
        AppBackgroundGradient()
        ProgressRing(progress: 1.0, completed: 5, total: 5, ringColor: .green)
    }
}

#Preview("ProgressRing — 0% Dark") {
    ZStack {
        AppBackgroundGradient()
        ProgressRing(progress: 0.0, completed: 0, total: 8, lineWidth: 14, size: 150)
    }
    .preferredColorScheme(.dark)
}

#Preview("ProgressRing Large Text") {
    ZStack {
        AppBackgroundGradient()
        ProgressRing(progress: 0.4, completed: 2, total: 5)
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
