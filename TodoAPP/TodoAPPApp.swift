//
//  TodoAPPApp.swift
//  TodoAPP
//
//  Created by bore li li on 2025/12/6.
//

import SwiftUI
import SwiftData

@main
struct TodoAPPApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Task.self, TaskList.self, Tag.self])
        
        // 1. 优先尝试持久化
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [config])
            print("✅ 数据库初始化成功（持久化模式）")
            return container
        } catch let persistError {
            print("⚠️ 持久化失败: \(persistError.localizedDescription)")
            
            // 2. 尝试删除旧数据库重新创建（处理 schema 变更）
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let dbURL = appSupport.appendingPathComponent("default.store")
                if FileManager.default.fileExists(atPath: dbURL.path) {
                    do {
                        try FileManager.default.removeItem(at: dbURL)
                        print("🔄 已删除旧数据库，尝试重建")
                        
                        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                        let container = try ModelContainer(for: schema, configurations: [config])
                        print("✅ 数据库重建成功")
                        return container
                    } catch {
                        print("⚠️ 重建数据库失败: \(error)")
                    }
                }
            }
            
            // 3. 最后降级为内存模式（不崩溃）
            do {
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let container = try ModelContainer(for: schema, configurations: [inMemoryConfig])
                print("⚠️ 使用内存模式（数据不会持久化）")
                
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
                print("❌ 内存容器创建失败，使用最小化安全模式")
                print("持久化错误: \(persistError)")
                print("内存模式错误: \(memoryError)")
                
                // 使用最简配置再试
                do {
                    let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                    let fallbackContainer = try ModelContainer(for: schema, configurations: [fallbackConfig])
                    
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
                    print("⛔️ 所有数据库初始化尝试失败，返回空容器")
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
        // 请求通知权限
        NotificationManager.shared.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
