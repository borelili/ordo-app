//
//  TodoAPPApp.swift
//  TodoAPP
//
//  Created by bore li li on 2025/12/6.
//

import SwiftUI
import SwiftData
import os.signpost

// 性能测量工具
let performanceLog = OSLog(subsystem: "com.todoapp.performance", category: .pointsOfInterest)

@main
struct TodoAPPApp: App {
    // 记录应用启动时间
    private let appStartTime = Date()
    @StateObject private var themeManager = ThemeManager()
    
    var sharedModelContainer: ModelContainer = {
        let dbStartTime = Date()
        os_signpost(.begin, log: performanceLog, name: "Database Initialization")
        
        let schema = Schema([Task.self, TaskList.self, Tag.self])
        
        // 1. 优先尝试持久化（启用 CloudKit 同步）
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
            let container = try ModelContainer(for: schema, configurations: [config])
            
            let dbEndTime = Date()
            let dbInitTime = (dbEndTime.timeIntervalSince(dbStartTime) * 1000)
            
            #if DEBUG
            print("✅ 数据库初始化成功（持久化模式）")
            print("⏱️ 数据库初始化耗时: \(String(format: "%.2f", dbInitTime)) ms")
            #endif
            
            os_signpost(.end, log: performanceLog, name: "Database Initialization", 
                       "Layer 1 Success: %.2f ms", dbInitTime)
            
            return container
        } catch let persistError {
            #if DEBUG
            print("⚠️ 持久化失败: \(persistError.localizedDescription)")
            #endif
            
            // 2. 尝试删除旧数据库重新创建（处理 schema 变更）
            let rebuildStartTime = Date()
            os_signpost(.begin, log: performanceLog, name: "Database Rebuild")
            
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let dbURL = appSupport.appendingPathComponent("default.store")
                if FileManager.default.fileExists(atPath: dbURL.path) {
                    do {
                        try FileManager.default.removeItem(at: dbURL)
                        #if DEBUG
                        print("🔄 已删除旧数据库，尝试重建")
                        #endif
                        
                        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
                        let container = try ModelContainer(for: schema, configurations: [config])
                        
                        let rebuildTime = (Date().timeIntervalSince(rebuildStartTime) * 1000)
                        #if DEBUG
                        print("✅ 数据库重建成功")
                        print("⏱️ 重建耗时: \(String(format: "%.2f", rebuildTime)) ms")
                        #endif
                        
                        os_signpost(.end, log: performanceLog, name: "Database Rebuild",
                                   "Layer 2 Success: %.2f ms", rebuildTime)
                        
                        return container
                    } catch {
                        #if DEBUG
                        print("⚠️ 重建数据库失败: \(error)")
                        #endif
                        os_signpost(.end, log: performanceLog, name: "Database Rebuild", "Layer 2 Failed")
                    }
                }
            }
            
            // 3. 最后降级为内存模式（不崩溃）
            let memoryStartTime = Date()
            os_signpost(.begin, log: performanceLog, name: "In-Memory Fallback")
            
            do {
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: schema, configurations: [inMemoryConfig])
                
                let memoryTime = (Date().timeIntervalSince(memoryStartTime) * 1000)
                #if DEBUG
                print("⚠️ 使用内存模式（数据不会持久化）")
                print("⏱️ 内存模式初始化耗时: \(String(format: "%.2f", memoryTime)) ms")
                #endif
                
                os_signpost(.end, log: performanceLog, name: "In-Memory Fallback",
                           "Layer 3 Success: %.2f ms", memoryTime)
                
                // 在主线程显示警告
                DispatchQueue.main.async {
                    #if os(iOS)
                    // iOS 上显示警告
                    NotificationCenter.default.post(name: .init("ShowDatabaseWarning"), object: nil)
                    #endif
                }
                
                return container
            } catch let memoryError {
                // 4. 最后降级：返回空数据的最简容器（防止崩溃）
                let safeFallbackStartTime = Date()
                os_signpost(.begin, log: performanceLog, name: "Safe Fallback")
                
                #if DEBUG
                print("❌ 内存容器创建失败，使用最小化安全模式")
                print("持久化错误: \(persistError)")
                print("内存模式错误: \(memoryError)")
                #endif
                
                // 使用最简配置再试
                do {
                    let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                    let fallbackContainer = try ModelContainer(for: schema, configurations: [fallbackConfig])
                    
                    let safeFallbackTime = (Date().timeIntervalSince(safeFallbackStartTime) * 1000)
                    #if DEBUG
                    print("⏱️ 安全回退模式初始化耗时: \(String(format: "%.2f", safeFallbackTime)) ms")
                    #endif
                    
                    os_signpost(.end, log: performanceLog, name: "Safe Fallback",
                               "Layer 4 Success: %.2f ms", safeFallbackTime)
                    
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .init("ShowCriticalDatabaseError"),
                            object: """
                            数据库初始化失败，应用运行在安全模式。
                            
                            建议：
                            1. 重启应用
                            2. 检查存储空间
                            3. 重新安装应用
                            """
                        )
                    }
                    
                    return fallbackContainer
                } catch {
                    // 终极降级：返回一个仅包含 schema 的空容器
                    os_signpost(.end, log: performanceLog, name: "Safe Fallback", "Layer 4 Failed - Fatal")
                    
                    #if DEBUG
                    print("⛔️ 所有数据库初始化尝试失败，返回空容器")
                    #endif
                    // 注意：这里不使用 fatalError，而是返回一个最简化的容器
                    // 虽然数据可能无法保存，但至少应用不会崩溃
                    do {
                        // 最后一次尝试：使用最简单的初始化方式
                        return try ModelContainer(for: schema)
                    } catch let finalError {
                        // 如果连这个都失败了，那真的没办法了
                        // 4 层降级全部失败，只能崩溃（但这种情况极其罕见）
                        fatalError("""
                            ❌ 数据库完全无法初始化（所有 4 层降级策略失败）：
                            1. 持久化: \(persistError.localizedDescription)
                            2. 内存模式: \(memoryError.localizedDescription)
                            3. 降级模式: \(error.localizedDescription)
                            4. 最简模式: \(finalError.localizedDescription)
                            
                            请重新安装应用或联系技术支持
                        """)
                    }
                }
            }
        }
    }()
    
    init() {
        // 校验 Apple 登录凭证是否仍有效
        AppleSignInManager.shared.refreshCredentialState()

        // 请求通知权限（首次启动）
        NotificationManager.shared.requestAuthorization { granted, error in
            #if DEBUG
            if granted {
                print("✅ 应用启动：通知权限已授予")
            } else {
                print("⚠️ 应用启动：通知权限未授予")
            }
            #endif
        }
        
        // 记录 init 完成时间
        let initTime = (Date().timeIntervalSince(appStartTime) * 1000)
        #if DEBUG
        print("⏱️ App init 耗时: \(String(format: "%.2f", initTime)) ms")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(themeManager)
                .environmentObject(ErrorHandler.shared)
                .onAppear {
                    // 测量从应用启动到首屏显示的总时间
                    let totalStartupTime = (Date().timeIntervalSince(appStartTime) * 1000)
                    #if DEBUG
                    print("⏱️ 应用完整启动时间: \(String(format: "%.2f", totalStartupTime)) ms")
                    #endif
                    
                    os_signpost(.event, log: performanceLog, name: "App Launch Complete",
                               "Total startup time: %.2f ms", totalStartupTime)
                    
                    // 记录内存使用情况
                    if let memoryUsage = reportMemoryUsage() {
                        #if DEBUG
                        print("📊 当前内存占用: \(String(format: "%.1f", memoryUsage)) MB")
                        #endif
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            // 文件菜单命令
            CommandGroup(after: .newItem) {
                Button("新建任务") {
                    NotificationCenter.default.post(name: .newTask, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("新建列表") {
                    NotificationCenter.default.post(name: .newList, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Divider()
                
                Button("批量操作") {
                    NotificationCenter.default.post(name: .batchOperations, object: nil)
                }
                .keyboardShortcut("b", modifiers: .command)
            }
            
            // 帮助菜单命令
            CommandGroup(after: .help) {
                Button("键盘快捷键") {
                    NotificationCenter.default.post(name: .showKeyboardShortcuts, object: nil)
                }
                .keyboardShortcut("/", modifiers: .command)
            }
        }
        #endif
    }
}

// NotificationCenter 扩展 - 定义通知名称
extension Notification.Name {
    static let newTask = Notification.Name("newTask")
    static let newList = Notification.Name("newList")
    static let batchOperations = Notification.Name("batchOperations")
    static let showKeyboardShortcuts = Notification.Name("showKeyboardShortcuts")
}

// 性能测量辅助函数
import os

/// 获取当前内存使用情况（单位：MB）
func reportMemoryUsage() -> Double? {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_,
                     task_flavor_t(MACH_TASK_BASIC_INFO),
                     $0,
                     &count)
        }
    }
    
    guard kerr == KERN_SUCCESS else {
        return nil
    }
    
    let usedMemoryMB = Double(info.resident_size) / (1024.0 * 1024.0)
    return usedMemoryMB
}
