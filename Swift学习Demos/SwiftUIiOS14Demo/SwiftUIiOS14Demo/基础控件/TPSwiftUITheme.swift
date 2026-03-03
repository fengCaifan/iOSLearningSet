//
//  TPSwiftUITheme.swift
//  SwiftUIiOS14Demo
//
//  Created by fengcaifan on 2025/3/17.
//

import SwiftUI

enum TPThemeMode {
    case auto
    case light
    case dark
}

/// 假的暗黑模式适配
class TPSwiftUITheme: ObservableObject {
    @Published var isLight: Bool = false
    
    init(mode: TPThemeMode = .auto) {
        switch mode {
        case .auto:
            self.isLight = true
        case .light:
            self.isLight = true
        case .dark:
            self.isLight = false
        }
    }
}

class SwiftUITheme: ObservableObject {
    @Published var isDark: Bool = false
    
    init(isDark: Bool = false) {
        self.isDark = isDark
    }
}
