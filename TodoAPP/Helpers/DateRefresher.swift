//
//  DateRefresher.swift
//  TodoAPP
//
//  Created on 2026/02/23
//
//  将 Combine Timer 隔离到独立文件，避免在 ContentView.swift 中
//  导入 Combine 导致复杂 SwiftUI view body 类型推断超时。
//

import Foundation
import Combine

/// 每 60 秒发布一次当前时间的 ObservableObject。
/// ContentView 通过 @StateObject 持有，无需在 ContentView 中 import Combine。
final class DateRefresher: ObservableObject {
    @Published private(set) var currentDate: Date = Date()

    private var cancellable: AnyCancellable?

    init() {
        cancellable = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.currentDate = date
            }
    }

    /// 立即刷新（app 回到前台时调用）
    func refresh() {
        currentDate = Date()
    }
}
