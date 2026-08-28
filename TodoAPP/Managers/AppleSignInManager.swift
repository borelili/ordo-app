//
//  AppleSignInManager.swift
//  TodoAPP
//
//  Sign in with Apple 账号状态管理：仅维护本地登录标识，不涉及任何后端服务
//

import Foundation
import Combine
import AuthenticationServices

@MainActor
final class AppleSignInManager: ObservableObject {
    static let shared = AppleSignInManager()

    @Published private(set) var isSignedIn: Bool
    @Published private(set) var displayName: String?
    private(set) var userIdentifier: String?

    private static let userIdKey = "appleSignIn_userIdentifier"
    private static let displayNameKey = "appleSignIn_displayName"

    private init() {
        let savedId = UserDefaults.standard.string(forKey: Self.userIdKey)
        userIdentifier = savedId
        displayName = UserDefaults.standard.string(forKey: Self.displayNameKey)
        isSignedIn = savedId != nil
    }

    /// SignInWithAppleButton 登录成功回调里调用
    func handleSuccess(_ credential: ASAuthorizationAppleIDCredential) {
        let id = credential.user
        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")

        userIdentifier = id
        if !name.isEmpty { displayName = name }
        isSignedIn = true

        UserDefaults.standard.set(id, forKey: Self.userIdKey)
        if !name.isEmpty { UserDefaults.standard.set(name, forKey: Self.displayNameKey) }
    }

    /// App 启动时校验凭证是否仍然有效（用户可能已在系统设置中撤销授权）
    func refreshCredentialState() {
        guard let id = userIdentifier else { return }
        ASAuthorizationAppleIDProvider().getCredentialState(forUserID: id) { [weak self] state, _ in
            guard state == .revoked || state == .notFound else { return }
            DispatchQueue.main.async { self?.signOut() }
        }
    }

    /// 退出登录：仅清除本地状态，Apple 未提供登出 API
    func signOut() {
        userIdentifier = nil
        displayName = nil
        isSignedIn = false
        UserDefaults.standard.removeObject(forKey: Self.userIdKey)
        UserDefaults.standard.removeObject(forKey: Self.displayNameKey)
    }
}
