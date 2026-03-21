// AppTheme.swift
// TickTick — Theme System
// 应用主题数据结构 + 6 套内置主题

import SwiftUI

// MARK: - AppTheme

struct AppTheme: Identifiable, Equatable {
    let id: String
    let displayName: String
    let isDark: Bool

    // ── 背景 ──────────────────────────────────────────────────────
    /// 全屏渐变（3 个锚点，从顶到底）
    let backgroundColors: [Color]

    // ── 卡片面 ────────────────────────────────────────────────────
    /// 卡片填充色（暗色主题用半透明白；亮色主题用固体白）
    let cardBackground: Color
    /// 卡片描边色
    let cardBorderColor: Color
    /// 次级卡片 / 分组容器背景（用于 SidebarHomeView 的 CardContainer）
    let cardSecondaryBackground: Color

    // ── 导航 ──────────────────────────────────────────────────────
    /// BottomPillNav 胶囊背景（除 Material 之外的色调叠加）
    let tabBarBackground: Color
    /// FAB 按钮背景色
    let fabBackground: Color

    // ── 强调色 ────────────────────────────────────────────────────
    let primaryAccent: Color
    let secondaryAccent: Color
    /// 强调色上的文字颜色（通常为白色）
    let accentTextColor: Color

    // ── 文字 ──────────────────────────────────────────────────────
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color

    // ── 分割线 / 阴影 ─────────────────────────────────────────────
    let divider: Color
    let shadowColor: Color

    // ── 语义色 ────────────────────────────────────────────────────
    let successColor: Color
    let warningColor: Color
    let dangerColor: Color

    // ── 派生属性 ──────────────────────────────────────────────────
    var colorScheme: ColorScheme { isDark ? .dark : .light }
}

// MARK: - Built-in Themes

extension AppTheme {

    // ── 1. 经典紫（默认，暗色）────────────────────────────────────
    static let classicPurple = AppTheme(
        id: "ClassicPurple",
        displayName: "经典紫",
        isDark: true,
        backgroundColors: [
            Color(hex: "7A4DFF"),
            Color(hex: "2B0F4F"),
            Color(hex: "0B0B12")
        ],
        cardBackground: Color.white.opacity(0.08),
        cardBorderColor: Color.white.opacity(0.12),
        cardSecondaryBackground: Color.white.opacity(0.06),
        tabBarBackground: Color.black.opacity(0.35),
        fabBackground: Color(hex: "8B5CFF"),
        primaryAccent: Color(hex: "8B5CFF"),
        secondaryAccent: Color(hex: "4D7CFF"),
        accentTextColor: .white,
        textPrimary: Color(hex: "F2F3F7"),
        textSecondary: Color(hex: "B7B9C6"),
        textMuted: Color(hex: "6B6D7C"),
        divider: Color.white.opacity(0.10),
        shadowColor: Color.black.opacity(0.30),
        successColor: Color(hex: "34C759"),
        warningColor: Color(hex: "FF9F0A"),
        dangerColor: Color(hex: "FF453A")
    )

    // ── 2. 极夜蓝（暗色）────────────────────────────────────────
    static let midnightBlue = AppTheme(
        id: "MidnightBlue",
        displayName: "极夜蓝",
        isDark: true,
        backgroundColors: [
            Color(hex: "0D1B42"),
            Color(hex: "061028"),
            Color(hex: "03080F")
        ],
        cardBackground: Color.white.opacity(0.08),
        cardBorderColor: Color.white.opacity(0.12),
        cardSecondaryBackground: Color.white.opacity(0.06),
        tabBarBackground: Color.black.opacity(0.35),
        fabBackground: Color(hex: "4A90FF"),
        primaryAccent: Color(hex: "4A90FF"),
        secondaryAccent: Color(hex: "00C8FF"),
        accentTextColor: .white,
        textPrimary: Color(hex: "E8F0FF"),
        textSecondary: Color(hex: "8AAFD4"),
        textMuted: Color(hex: "506A8A"),
        divider: Color.white.opacity(0.10),
        shadowColor: Color.black.opacity(0.30),
        successColor: Color(hex: "34C759"),
        warningColor: Color(hex: "FF9F0A"),
        dangerColor: Color(hex: "FF453A")
    )

    // ── 3. 森林绿（暗色）────────────────────────────────────────
    static let forestGreen = AppTheme(
        id: "ForestGreen",
        displayName: "森林绿",
        isDark: true,
        backgroundColors: [
            Color(hex: "1A3D2B"),
            Color(hex: "0F2518"),
            Color(hex: "071210")
        ],
        cardBackground: Color.white.opacity(0.08),
        cardBorderColor: Color.white.opacity(0.12),
        cardSecondaryBackground: Color.white.opacity(0.06),
        tabBarBackground: Color.black.opacity(0.35),
        fabBackground: Color(hex: "2ECC71"),
        primaryAccent: Color(hex: "2ECC71"),
        secondaryAccent: Color(hex: "1ABC9C"),
        accentTextColor: .white,
        textPrimary: Color(hex: "E8F5E9"),
        textSecondary: Color(hex: "A0C4AC"),
        textMuted: Color(hex: "5A7D65"),
        divider: Color.white.opacity(0.10),
        shadowColor: Color.black.opacity(0.30),
        successColor: Color(hex: "2ECC71"),
        warningColor: Color(hex: "FF9F0A"),
        dangerColor: Color(hex: "FF453A")
    )

    // ── 4. 落日橙（暗色）────────────────────────────────────────
    static let sunsetOrange = AppTheme(
        id: "SunsetOrange",
        displayName: "落日橙",
        isDark: true,
        backgroundColors: [
            Color(hex: "4A2800"),
            Color(hex: "2A1400"),
            Color(hex: "0F0600")
        ],
        cardBackground: Color.white.opacity(0.08),
        cardBorderColor: Color.white.opacity(0.12),
        cardSecondaryBackground: Color.white.opacity(0.06),
        tabBarBackground: Color.black.opacity(0.35),
        fabBackground: Color(hex: "FF7043"),
        primaryAccent: Color(hex: "FF7043"),
        secondaryAccent: Color(hex: "FFA000"),
        accentTextColor: .white,
        textPrimary: Color(hex: "FFF5F0"),
        textSecondary: Color(hex: "D4A090"),
        textMuted: Color(hex: "9A6050"),
        divider: Color.white.opacity(0.10),
        shadowColor: Color.black.opacity(0.30),
        successColor: Color(hex: "34C759"),
        warningColor: Color(hex: "FFA000"),
        dangerColor: Color(hex: "FF453A")
    )

    // ── 5. 樱花粉（亮色）────────────────────────────────────────
    static let sakuraPink = AppTheme(
        id: "SakuraPink",
        displayName: "樱花粉",
        isDark: false,
        backgroundColors: [
            Color(hex: "FFF0F5"),
            Color(hex: "FFE4EF"),
            Color(hex: "FCD6E4")
        ],
        cardBackground: Color.white.opacity(0.90),
        cardBorderColor: Color.black.opacity(0.06),
        cardSecondaryBackground: Color.white.opacity(0.80),
        tabBarBackground: Color.white.opacity(0.85),
        fabBackground: Color(hex: "E91E8C"),
        primaryAccent: Color(hex: "E91E8C"),
        secondaryAccent: Color(hex: "FF4DB8"),
        accentTextColor: .white,
        textPrimary: Color(hex: "2D1020"),
        textSecondary: Color(hex: "7A4060"),
        textMuted: Color(hex: "C490A8"),
        divider: Color.black.opacity(0.08),
        shadowColor: Color.black.opacity(0.10),
        successColor: Color(hex: "34C759"),
        warningColor: Color(hex: "FF9F0A"),
        dangerColor: Color(hex: "E53935")
    )

    // ── 6. 纯净白（亮色）────────────────────────────────────────
    static let pureLight = AppTheme(
        id: "PureLight",
        displayName: "纯净白",
        isDark: false,
        backgroundColors: [
            Color(hex: "FFFFFF"),
            Color(hex: "F5F5FA"),
            Color(hex: "EBEBF0")
        ],
        cardBackground: Color.white,
        cardBorderColor: Color.black.opacity(0.08),
        cardSecondaryBackground: Color(hex: "F2F2F7"),
        tabBarBackground: Color.white.opacity(0.90),
        fabBackground: Color(hex: "007AFF"),
        primaryAccent: Color(hex: "007AFF"),
        secondaryAccent: Color(hex: "5856D6"),
        accentTextColor: .white,
        textPrimary: Color(hex: "1C1C1E"),
        textSecondary: Color(hex: "48484A"),
        textMuted: Color(hex: "8E8E93"),
        divider: Color.black.opacity(0.10),
        shadowColor: Color.black.opacity(0.08),
        successColor: Color(hex: "34C759"),
        warningColor: Color(hex: "FF9F0A"),
        dangerColor: Color(hex: "FF3B30")
    )

    // ── 所有主题的有序列表 ───────────────────────────────────────
    static let all: [AppTheme] = [
        .classicPurple,
        .midnightBlue,
        .forestGreen,
        .sunsetOrange,
        .sakuraPink,
        .pureLight
    ]
}
