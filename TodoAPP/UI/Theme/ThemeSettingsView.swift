// ThemeSettingsView.swift
// TickTick — Theme System
// 主题/外观选择器：6 套主题预览卡 + 点击切换

import SwiftUI

// MARK: - ThemeSettingsView

struct ThemeSettingsView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(AppTheme.all) { t in
                        ThemeCard(appTheme: t,
                                  isSelected: theme.current.id == t.id) {
                            theme.select(t)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(
                LinearGradient(
                    colors: theme.current.backgroundColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("主题 / 外观")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(theme.current.primaryAccent)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(theme.current.colorScheme)
    }
}

// MARK: - ThemeCard

private struct ThemeCard: View {
    let appTheme: AppTheme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // 渐变预览区
                LinearGradient(
                    colors: appTheme.backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 90)
                .overlay(
                    // 右上角选中勾
                    Group {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                .padding(8)
                        }
                    },
                    alignment: .topTrailing
                )
                // 颜色点阵
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(appTheme.primaryAccent)
                            .frame(width: 10, height: 10)
                        Circle()
                            .fill(appTheme.secondaryAccent)
                            .frame(width: 10, height: 10)
                        Circle()
                            .fill(appTheme.fabBackground)
                            .frame(width: 10, height: 10)
                    }
                    .padding(8)
                }

                // 主题名称
                Text(appTheme.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(appTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [
                                appTheme.backgroundColors.last ?? .black,
                                appTheme.backgroundColors.last ?? .black
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        isSelected ? appTheme.primaryAccent : appTheme.cardBorderColor,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .shadow(
                color: isSelected ? appTheme.primaryAccent.opacity(0.4) : appTheme.shadowColor,
                radius: isSelected ? 8 : 4,
                x: 0,
                y: isSelected ? 4 : 2
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(appTheme.displayName)\(isSelected ? "，当前选中" : "")")
    }
}

// MARK: - Preview

#Preview("ThemeSettingsView") {
    ThemeSettingsView()
        .environmentObject(ThemeManager())
}
