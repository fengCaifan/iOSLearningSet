//
//  CornersRounded.swift
//  SwiftUIiOS14Demo
//
//  Created by fengcaifan on 2024/11/18.
//

import SwiftUI

// 指定圆角的Shape
struct CornersRounded: Shape {
    var cornerRadius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
        return Path(path.cgPath)
    }
}
