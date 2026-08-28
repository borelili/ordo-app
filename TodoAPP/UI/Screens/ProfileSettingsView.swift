//
//  ProfileSettingsView.swift
//  TodoAPP
//
//  统一设置/我的页面：账户、外观、通知、关于
//

import SwiftUI
import AuthenticationServices
import UserNotifications

struct ProfileSettingsView: View {
    @EnvironmentObject private var theme: ThemeManager
    @StateObject private var errorHandler = ErrorHandler.shared
    @StateObject private var authManager = AppleSignInManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var showingThemeSettings = false
    @State private var showingPrivacyPolicy = false

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                appearanceSection
                notificationSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: theme.current.backgroundColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(theme.current.primaryAccent)
                }
            }
            .sheet(isPresented: $showingThemeSettings) {
                ThemeSettingsView()
                    .environmentObject(theme)
            }
            .sheet(isPresented: $showingPrivacyPolicy) {
                PrivacyPolicyView()
                    .environmentObject(theme)
            }
            .onAppear(perform: refreshNotificationStatus)
        }
        .preferredColorScheme(theme.current.colorScheme)
    }

    // MARK: - 账户

    private var accountSection: some View {
        Section("账户") {
            if authManager.isSignedIn {
                HStack(spacing: DS.spacingMD) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle(theme.current.primaryAccent)
                    Text(authManager.displayName?.isEmpty == false ? authManager.displayName! : "Apple 账户已登录")
                        .foregroundStyle(theme.current.textPrimary)
                }
                Button("退出登录", role: .destructive) {
                    authManager.signOut()
                }
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                            authManager.handleSuccess(credential)
                        }
                    case .failure(let error):
                        errorHandler.handle(error, context: "登录失败")
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 44)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
    }

    // MARK: - 外观

    private var appearanceSection: some View {
        Section("外观") {
            Button {
                showingThemeSettings = true
            } label: {
                HStack {
                    Label("主题 / 外观", systemImage: "paintpalette")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(theme.current.textMuted)
                }
            }
            .foregroundStyle(theme.current.textPrimary)
        }
    }

    // MARK: - 通知

    private var notificationSection: some View {
        Section("通知") {
            HStack {
                Label("任务提醒", systemImage: "bell")
                Spacer()
                Text(notificationStatusText)
                    .font(.subheadline)
                    .foregroundStyle(theme.current.textSecondary)
            }
            if notificationStatus == .denied {
                Button("前往系统设置开启通知") {
                    openSystemSettings()
                }
            } else if notificationStatus == .notDetermined {
                Button("开启通知权限") {
                    NotificationManager.shared.requestAuthorization { _, _ in
                        refreshNotificationStatus()
                    }
                }
            }
        }
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return "已开启"
        case .denied: return "已关闭"
        default: return "未设置"
        }
    }

    private func refreshNotificationStatus() {
        NotificationManager.shared.checkAuthorizationStatus { status in
            notificationStatus = status
        }
    }

    private func openSystemSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    // MARK: - 关于

    private var aboutSection: some View {
        Section("关于") {
            HStack {
                Text("版本")
                Spacer()
                Text(appVersionString)
                    .foregroundStyle(theme.current.textSecondary)
            }
            Button {
                showingPrivacyPolicy = true
            } label: {
                HStack {
                    Text("隐私说明")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(theme.current.textMuted)
                }
            }
            .foregroundStyle(theme.current.textPrimary)
        }
    }

    private var appVersionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }
}

#Preview {
    ProfileSettingsView()
        .environmentObject(ThemeManager())
}
