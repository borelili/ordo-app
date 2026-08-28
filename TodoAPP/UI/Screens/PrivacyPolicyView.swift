//
//  PrivacyPolicyView.swift
//  TodoAPP
//
//  应用内隐私说明（纯文字，不依赖外部网址）
//

import SwiftUI

struct PrivacyPolicyView: View {
    @EnvironmentObject private var theme: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.spacingLG) {
                    section(title: "数据存储", body: """
                    Ordo 的任务、清单、标签等数据默认保存在你的设备本地。如果你登录了 Apple 账户，数据会通过 iCloud 私有数据库在你本人的设备之间同步，这些数据仅归属于你的 Apple 账户，开发者无法访问。
                    """)
                    section(title: "账户信息", body: """
                    登录使用 Sign in with Apple，我们只保存 Apple 提供的账户标识和你选择公开的姓名，不会获取你的 Apple ID 密码，也不会将账户信息发送给第三方。
                    """)
                    section(title: "通知权限", body: """
                    任务提醒通知完全在本机生成和触发，不经过任何服务器。
                    """)
                    section(title: "第三方共享", body: """
                    Ordo 不与任何第三方共享、出售你的个人数据。
                    """)
                }
                .padding(DS.paddingScreen)
            }
            .background(
                LinearGradient(
                    colors: theme.current.backgroundColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("隐私说明")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(theme.current.primaryAccent)
                }
            }
        }
        .preferredColorScheme(theme.current.colorScheme)
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: DS.spacingXS + 2) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.current.textPrimary)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(theme.current.textSecondary)
        }
    }
}

#Preview {
    PrivacyPolicyView()
        .environmentObject(ThemeManager())
}
