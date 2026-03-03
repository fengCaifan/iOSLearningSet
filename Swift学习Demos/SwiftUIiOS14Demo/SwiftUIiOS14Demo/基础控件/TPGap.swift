//
//  TPGap.swift
//  SwiftUIiOS14Demo
//
//  Created by fengcaifan on 2025/3/17.
//

import SwiftUI

struct HGap: View {
    let value: CGFloat
    
    init(_ value: CGFloat) {
        self.value = value
    }
    
    var body: some View {
        Spacer()
            .frame(width: value)
    }
}

struct VGap: View {
    let value: CGFloat
    
    init(_ value: CGFloat) {
        self.value = value
    }
    
    var body: some View {
        Spacer()
            .frame(height: value)
    }
}
