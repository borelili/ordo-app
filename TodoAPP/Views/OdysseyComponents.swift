// OdysseyComponents.swift
// TickTick — 奥德赛模块共享 UI 组件
//
// 供 OdysseyPlanView / PathDetailView / GoalDetailView / ProjectDetailView 共享使用

import SwiftUI

// MARK: - OdysseyCardBG

/// 奥德赛各级页面通用卡片背景（ultraThinMaterial + 主题色 + 描边）
struct OdysseyCardBG: View {
    @EnvironmentObject private var theme: ThemeManager
    var accent: Bool = false   // true 时使用强调色填充和描边

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                .fill(
                    accent
                        ? theme.current.primaryAccent.opacity(0.08)
                        : theme.current.cardBackground
                )
            RoundedRectangle(cornerRadius: DS.radiusCard, style: .continuous)
                .strokeBorder(
                    accent
                        ? theme.current.primaryAccent.opacity(0.3)
                        : theme.current.cardBorderColor,
                    lineWidth: 1
                )
        }
    }
}

// MARK: - SectionHeader

/// 节标题：彩色图标 + 灰色标签
struct SectionHeader: View {
    @EnvironmentObject private var theme: ThemeManager
    let title: String
    let icon:  String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.current.primaryAccent)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.current.textSecondary)
        }
    }
}

// MARK: - OdysseyStatPill

/// 统计胶囊 —— 图标 / 数字 / 标签三行排列
struct OdysseyStatPill: View {
    @EnvironmentObject private var theme: ThemeManager
    let value: Int
    let label: String
    let icon:  String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.subheadline).foregroundStyle(color)
            Text("\(value)")
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(theme.current.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(theme.current.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(OdysseyCardBG(accent: false))
    }
}

// MARK: - FloatingPlusButton

/// 标准 FAB —— 52pt 实心圆 + plus 图标
struct FloatingPlusButton: View {
    @EnvironmentObject private var theme: ThemeManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(
                    Circle()
                        .fill(theme.current.primaryAccent)
                        .shadow(color: theme.current.primaryAccent.opacity(0.4), radius: 8, y: 3)
                )
        }
        .padding(.trailing, DS.paddingScreen)
        .padding(.bottom, DS.paddingScreen + 8)
    }
}
