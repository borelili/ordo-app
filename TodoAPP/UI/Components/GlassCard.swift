// GlassCard.swift
// TickTick — Design System
// 玻璃拟态卡片容器

import SwiftUI

// MARK: - GlassCard

/// 玻璃拟态卡片：ultraThinMaterial + 描边 + 可选圆角
struct GlassCard<Content: View>: View {
    var radius: CGFloat = DS.radiusCard
    var padding: CGFloat = DS.paddingCard
    var isInteractive: Bool = false            // true 时加 button accessibility trait
    let content: () -> Content

    @Environment(\..colorScheme) private var colorScheme

    private var borderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }
    private var highlightColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.clear
    }

    var body: some View {
        content()
            .padding(padding)
            .background(
                ZStack {
                    // 玻璃质感底层
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    // 内高光
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(highlightColor)
                    // 描边
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
            )
            .cardShadow(DS.Shadow.card)
            // VoiceOver：容器本身不是按钮时不设 button trait
            .accessibilityElement(children: .contain)
    }
}

// MARK: - View Modifier 便捷 API

extension View {
    /// 快速应用 GlassCard 样式（适合批量包裹）
    func glassCard(
        radius: CGFloat = DS.radiusCard,
        padding: CGFloat = DS.paddingCard,
        isInteractive: Bool = false
    ) -> some View {
        GlassCard(radius: radius, padding: padding, isInteractive: isInteractive) {
            self
        }
    }
}

// MARK: - Previews

#Preview("GlassCard — Light") {
    ZStack {
        AppBackgroundGradient()
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("学习 SwiftUI")
                    .font(.headline)
                    .foregroundStyle(Color.DS.textPrimary)
                Text("今天完成 3 / 5 项")
                    .font(.subheadline)
                    .foregroundStyle(Color.DS.textSecondary)
            }
        }
        .frame(width: 280)
    }
}

#Preview("GlassCard — Dark") {
    ZStack {
        AppBackgroundGradient()
        GlassCard {
            Label("已完成任务", systemImage: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(Color.DS.textPrimary)
        }
        .frame(width: 280)
    }
    .preferredColorScheme(.dark)
}

#Preview("GlassCard — Large Text") {
    ZStack {
        AppBackgroundGradient()
        GlassCard {
            Text("动态字体测试")
                .font(.body)
                .foregroundStyle(Color.DS.textPrimary)
        }
        .frame(width: 320)
    }
    .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
}
