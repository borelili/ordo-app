// DesignSystem.swift
// TickTick — Design System
// 颜色 Token、间距、圆角、阴影策略、通用背景

import SwiftUI

// MARK: - Color Tokens

extension Color {
    enum DS {
        // 背景渐变三段色
        static let backgroundTop    = Color(hex: "7A4DFF")
        static let backgroundMid    = Color(hex: "2B0F4F")
        static let backgroundBottom = Color(hex: "0B0B12")

        // 强调色
        static let accentPurple = Color(hex: "8B5CFF")
        static let accentBlue   = Color(hex: "4D7CFF")

        // 文字
        static let textPrimary   = Color(hex: "F2F3F7")
        static let textSecondary = Color(hex: "B7B9C6")

        // 玻璃描边
        static let glassBorder = Color.white.opacity(0.12)
        // 玻璃高光
        static let glassHighlight = Color.white.opacity(0.06)
    }
}

// MARK: - Spacing & Radius Tokens

enum DS {
    // 圆角
    static let radiusCard: CGFloat  = 20
    static let radiusPill: CGFloat  = 16

    // 内边距
    static let paddingCard: CGFloat   = 16
    static let paddingScreen: CGFloat = 20

    // 间距
    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 12
    static let spacingLG: CGFloat = 20

    // 阴影（克制策略：只在卡片/导航上使用轻微 shadow）
    enum Shadow {
        static let card   = ShadowConfig(color: Color.black.opacity(0.25), radius: 8,  x: 0, y: 4)
        static let pill   = ShadowConfig(color: Color.black.opacity(0.18), radius: 6,  x: 0, y: 2)
        static let subtle = ShadowConfig(color: Color.black.opacity(0.12), radius: 4,  x: 0, y: 1)
    }

    /// 主页面底部避让高度 —— 直接施加到可滚动容器本身，完全绕过 NavigationStack safeAreaInset 传播问题。
    /// 组成：BottomPillNav(≈60) + navBottomPadding(12) + FAB(52) + fabPadding(8) + 视觉缓冲(28) = 160
    static let homeBottomInset: CGFloat = 160
}

struct ShadowConfig {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    func cardShadow(_ s: ShadowConfig = DS.Shadow.card) -> some View {
        self.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }
}

// MARK: - AppBackgroundGradient

/// 线性渐变背景（Top → Mid → Bottom），覆盖整个 ignoresSafeArea
struct AppBackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.DS.backgroundTop,
                Color.DS.backgroundMid,
                Color.DS.backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview("AppBackgroundGradient") {
    ZStack {
        AppBackgroundGradient()
        VStack(spacing: 16) {
            Text("Primary")
                .foregroundStyle(Color.DS.textPrimary)
                .font(.title2.bold())
            Text("Secondary")
                .foregroundStyle(Color.DS.textSecondary)
                .font(.subheadline)
        }
    }
}
