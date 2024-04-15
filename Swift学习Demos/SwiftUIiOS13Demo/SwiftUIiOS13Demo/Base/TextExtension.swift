//
//  TextExtension.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/4/12.
//

import SwiftUI

extension Text {
    // 这边相较于view重新写这几个font，是为了return Text本身，能用Text + Text的富文本方案
    func font(_ fontSize: CGFloat) -> Text {
        return self.font(.system(size: fontSize))
    }
    
    func mediumFont(_ fontSize: CGFloat) -> Text {
        return self.font(.system(size: fontSize, weight: Font.Weight.medium))
    }
    
    func boldFont(_ fontSize: CGFloat) -> Text {
        return self.font(.system(size: fontSize, weight: Font.Weight.bold))
    }
}

extension Text {
    // return Text，能用Text + Text
    func textForegroundColor(_ color: UIColor?) -> Text {
        return self.foregroundColor(color?.color)
    }
}
