//
//  ViewExtension.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/4/12.
//

import SwiftUI

extension View {
    func font(_ fontSize: CGFloat) -> some View {
        return self.font(.system(size: fontSize))
    }
    
    func mediumFont(_ fontSize: CGFloat) -> some View {
        return self.font(.system(size: fontSize, weight: Font.Weight.medium))
    }
    
    func boldFont(_ fontSize: CGFloat) -> some View {
        return self.font(.system(size: fontSize, weight: Font.Weight.bold))
    }
    
    func foregroundColor(_ color: UIColor) -> some View {
        return foregroundColor(color.color)
    }
    
    func backgroundColor(_ color: UIColor) -> some View {
        return background(color.color)
    }
}
