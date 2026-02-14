//
//  ErrorHandler.swift
//  TodoAPP
//
//  Created on 2026/02/14
//

import SwiftUI
import Combine

class ErrorHandler: ObservableObject {
    @Published var currentError: AppError?
    @Published var showError = false
    
    static let shared = ErrorHandler()
    
    private init() {}
    
    func handle(_ error: Error, context: String = "") {
        DispatchQueue.main.async {
            self.currentError = AppError(
                title: "操作失败",
                message: context.isEmpty ? error.localizedDescription : "\(context): \(error.localizedDescription)",
                originalError: error
            )
            self.showError = true
            print("❌ \(context): \(error)")
        }
    }
}

struct AppError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let originalError: Error
}
