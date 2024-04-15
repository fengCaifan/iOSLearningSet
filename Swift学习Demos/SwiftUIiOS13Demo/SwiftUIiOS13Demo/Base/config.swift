//
//  config.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/4/12.
//

import Foundation
import UIKit

struct DisplayInfo {
    static var referWidth: CGFloat = 414.0
    
    static var widthRatio: CGFloat {
        let width = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        return width / referWidth
    }
}

public struct TPExtension<Base> {
    /// Base object to extend.
    public let base: Base

    /// Creates extensions with base object.
    ///
    /// - parameter base: Base object.
    public init(_ base: Base) {
        self.base = base
    }
}

public protocol TPExtensionCompatible {
    associatedtype TPBase

    static var tp: TPExtension<TPBase>.Type { get set }

    var tp: TPExtension<TPBase> { get set }
}

extension TPExtensionCompatible {
    public static var tp: TPExtension<Self>.Type {
        get { TPExtension<Self>.self }
        set {
            _ = newValue
        }
    }

    public var tp: TPExtension<Self> {
        get { TPExtension(self) }
        set {
            _ = newValue
        }
    }
}

extension NSObject: TPExtensionCompatible {}
extension String: TPExtensionCompatible {}
extension Int: TPExtensionCompatible {}


extension Double: TPExtensionCompatible {}
extension CGFloat: TPExtensionCompatible {}

extension TPExtension where Base == Double {
    var fitScreen: CGFloat {
        return CGFloat(base) * DisplayInfo.widthRatio
    }
    
    // 向上取整
    var fitScreenWithCeil: CGFloat {
        return ceil(fitScreen)
    }
    
    // 向下取整
    var fitScreenWithFloor: CGFloat {
        return floor(fitScreen)
    }
}

extension TPExtension where Base == CGFloat {
    var fitScreen: CGFloat {
        return base * DisplayInfo.widthRatio
    }
}
