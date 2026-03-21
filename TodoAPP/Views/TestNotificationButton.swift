//
//  TestNotificationButton.swift
//  TodoAPP
//
//  Created for debugging notification system
//

import SwiftUI
import UserNotifications

#if DEBUG
struct TestNotificationButton: View {
    @State private var countdown: Int = 0
    @State private var isScheduled = false
    
    var body: some View {
        VStack(spacing: 12) {
            if isScheduled && countdown > 0 {
                VStack(spacing: 8) {
                    Text("测试通知将在 \(countdown) 秒后触发")
                        .font(.headline)
                        .foregroundColor(.orange)
                    
                    ProgressView(value: Double(10 - countdown), total: 10)
                        .progressViewStyle(.linear)
                        .tint(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
            
            Button(action: scheduleTestNotification) {
                Label(isScheduled ? "测试通知已调度" : "Test Notification in 10s", systemImage: "bell.badge")
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(isScheduled)
        }
    }
    
    private func scheduleTestNotification() {
        let center = UNUserNotificationCenter.current()
        
        // 1. 检查并打印授权状态
        center.getNotificationSettings { settings in
            print("🔍 [Debug Test] 当前授权状态: \(settings.authorizationStatus.rawValue)")
            print("   - .notDetermined = 0, .denied = 1, .authorized = 2, .provisional = 3, .ephemeral = 4")
            
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                print("❌ [Debug Test] 权限未授予，无法调度测试通知")
                return
            }
            
            // 2. 设置固定 identifier
            let identifier = "debug-test"
            print("📌 [Debug Test] Identifier: \(identifier)")
            
            // 3. 创建通知内容
            let content = UNMutableNotificationContent()
            content.title = "🧪 Debug 测试通知"
            content.body = "这是一条测试通知，用于验证通知系统是否正常工作"
            content.sound = .default
            
            // 4. 使用 UNTimeIntervalNotificationTrigger（10秒后）
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
            print("⏰ [Debug Test] Trigger: 10 秒后触发")
            
            // 5. 创建请求
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            // 6. 添加通知
            center.add(request) { error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ [Debug Test] 添加通知失败: \(error.localizedDescription)")
                    } else {
                        print("✅ [Debug Test] 通知已成功调度")
                        
                        // 7. 查询并打印 pending 通知数量
                        center.getPendingNotificationRequests { requests in
                            print("📊 [Debug Test] 当前 Pending 通知数量: \(requests.count)")
                            print("   - Pending 列表:")
                            for req in requests {
                                print("     • \(req.identifier)")
                            }
                        }
                        
                        // 启动倒计时
                        isScheduled = true
                        countdown = 10
                        startCountdown()
                    }
                }
            }
        }
    }
    
    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
                // 延迟 2 秒后重置状态
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isScheduled = false
                    print("🔄 [Debug Test] 倒计时结束，可以再次测试")
                }
            }
        }
    }
}

#Preview {
    TestNotificationButton()
}
#endif
