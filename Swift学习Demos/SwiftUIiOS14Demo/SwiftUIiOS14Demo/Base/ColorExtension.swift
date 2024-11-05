//
//  Color.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/4/12.
//

import Foundation
import UIKit
import SwiftUI

extension UIColor {
    @objc public convenience init(rgba: String) {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 1.0

        if rgba.hasPrefix("#") {
            var hexStr = (rgba as NSString).substring(from: 1) as NSString
            if hexStr.length == 8 {
                let alphaHexStr = hexStr.substring(from: 6)
                hexStr = hexStr.substring(to: 6) as NSString

                var alphaHexValue: UInt32 = 0
                let alphaScanner = Scanner(string: alphaHexStr)
                if alphaScanner.scanHexInt32(&alphaHexValue) {
                    let alphaHex = Int(alphaHexValue)
                    alpha = CGFloat(alphaHex & 0x000000FF) / 255.0
                }
            }

            let rgbScanner = Scanner(string: hexStr as String)
            var hexValue: UInt32 = 0
            if rgbScanner.scanHexInt32(&hexValue) {
                if hexStr.length == 6 {
                    let hex = Int(hexValue)
                    red = CGFloat((hex & 0xFF0000) >> 16) / 255.0
                    green = CGFloat((hex & 0x00FF00) >> 8) / 255.0
                    blue = CGFloat(hex & 0x0000FF) / 255.0
                }
            }
        }
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    /// 两种颜色前后叠加
    public convenience init(front: UIColor, back: UIColor) {
        var redFront: CGFloat = 0.0, greenFront: CGFloat = 0.0, blueFront: CGFloat = 0.0, alphaFront: CGFloat = 0
        var redBack: CGFloat = 0.0, greenBack: CGFloat = 0.0, blueBack: CGFloat = 0.0, alphaBack: CGFloat = 0

        // 非RGB兼容的UIColor，直接返回默认值
        if front.getRed(&redFront, green: &greenFront, blue: &blueFront, alpha: &alphaFront) &&
            back.getRed(&redBack, green: &greenBack, blue: &blueBack, alpha: &alphaBack) {

            let alpha: CGFloat = 1 - (1 - alphaFront) * (1 - alphaBack)
            let red = (alphaFront * redFront + (1 - alphaFront) * redBack * alphaBack) / alpha
            let green = (alphaFront * greenFront + (1 - alphaFront) * greenBack * alphaBack) / alpha
            let blue = (alphaFront * blueFront + (1 - alphaFront) * blueBack * alphaBack) / alpha
            self.init(red: red, green: green, blue: blue, alpha: alpha)

        } else {
            self.init()
        }
    }

    /// 在原有透明度基础上再加上透明度
    public func withCompositeAlpha(_ alpha: CGFloat) -> UIColor {
        var white: CGFloat = 0, oriAlpha: CGFloat = 0
        self.getWhite(&white, alpha: &oriAlpha)
        return self.withAlphaComponent(oriAlpha * alpha)
    }
}

public extension UIColor {
    convenience init(rgba: UInt, alpha: CGFloat = 1) {
        let red = CGFloat((rgba & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgba & 0xFF00) >> 8) / 255.0
        let blue = CGFloat(rgba & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
    var hexString: String {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        if alpha < 1.0 {
            let rgba = UInt(red * 255) << 24 | UInt(green * 255) << 16 | UInt(blue * 255) << 8 | UInt(alpha * 255)
            return String(format: "#%08x", rgba).uppercased()
        } else {
            let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255) << 0
            return String(format: "#%06x", rgb).uppercased()
        }
    }
}

struct TPColor {
    
}

// MARK: - 暗黑模式之后使用
extension TPColor {
    static let viewBg1C = UIColor(rgba: "#1C1C1C")
    
    static let viewBgF3 = UIColor(rgba: "#F3F3F3")
    static let viewBg01 = UIColor(rgba: "#010101")
    static let viewBg10 = UIColor(rgba: "#101010")
    static let viewBg26 = UIColor(rgba: "#262626")
    
    static let viewBgE3 = UIColor(rgba: "#E3E3E3") // 图片加载态底色 light
    static let viewBg36 = UIColor(rgba: "#363636") // 图片加载态底色 dark
    
    static let golden = UIColor(rgba: "#FEDAA3") // 金色
    
    // 阴影
    static let shadowOne = UIColor(rgba: "#7E96C4")
    
    static let blackColor = UIColor(rgba: "#000000")
    static let black5 = UIColor(rgba: "#000000").withCompositeAlpha(0.05)
    static let black6 = UIColor(rgba: "#000000").withCompositeAlpha(0.06)
    static let black8 = UIColor(rgba: "#000000").withCompositeAlpha(0.08)
    static let black30 = UIColor(rgba: "#000000").withCompositeAlpha(0.3)
    static let black36 = UIColor(rgba: "#000000").withCompositeAlpha(0.36)
    static let black42 = UIColor(rgba: "#000000").withCompositeAlpha(0.42)
    static let black50 = UIColor(rgba: "#000000").withCompositeAlpha(0.5)
    static let black70 = UIColor(rgba: "#000000").withCompositeAlpha(0.7)
    static let black87 = UIColor(rgba: "#000000").withCompositeAlpha(0.87)
    
    static let whiteColor = UIColor(rgba: "#FFFFFF")
    static let white5 = UIColor(rgba: "#FFFFFF").withCompositeAlpha(0.05)
    static let white6 = UIColor(rgba: "#FFFFFF").withCompositeAlpha(0.06)
    static let white8 = UIColor(rgba: "#FFFFFF").withCompositeAlpha(0.08)
    static let white15 = UIColor(rgba: "#FFFFFF").withCompositeAlpha(0.15)
    static let white16 = UIColor(rgba: "#FFFFFF").withCompositeAlpha(0.16)
    static let white30 = UIColor(rgba: "#FFFFFF").withCompositeAlpha(0.3)
    static let white42 = UIColor(rgba: "#FFFFFF").withCompositeAlpha(0.42)
    static let white50 = UIColor(rgba: "#FFFFFF").withCompositeAlpha(0.5)
    static let white70 = UIColor(rgba: "#FFFFFF").withCompositeAlpha(0.7)
    static let white87 = UIColor(rgba: "#FFFFFF").withCompositeAlpha(0.87)
}

extension UIColor {
    func alpha(_ value: CGFloat) -> UIColor {
        return self.withAlphaComponent(value)
    }
}

/// 灰色系: 黑->白
extension UIColor {
    /// 纯黑 #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    static var g000: UIColor = .black
    static var g0000 = g000.withAlphaComponent(0.00)
    static var g003 = g000.withAlphaComponent(0.03)
    static var g005 = g000.withAlphaComponent(0.05)
    static var g006 = g000.withAlphaComponent(0.06)
    static var g007 = g000.withAlphaComponent(0.07)
    static var g008 = g000.withAlphaComponent(0.08)
    static var g010 = g000.withAlphaComponent(0.10)
    static var g012 = g000.withAlphaComponent(0.12)
    static var g015 = g000.withAlphaComponent(0.15)
    static var g016 = g000.withAlphaComponent(0.16)
    static var g020 = g000.withAlphaComponent(0.20)
    static var g024 = g000.withAlphaComponent(0.24)
    static var g025 = g000.withAlphaComponent(0.25)
    static var g030 = g000.withAlphaComponent(0.30)
    static var g035 = g000.withAlphaComponent(0.35)
    static var g040 = g000.withAlphaComponent(0.40)
    static var g042 = g000.withAlphaComponent(0.42)
    static var g045 = g000.withAlphaComponent(0.45)
    static var g050 = g000.withAlphaComponent(0.50)
    static var g060 = g000.withAlphaComponent(0.60)
    static var g070 = g000.withAlphaComponent(0.70)
    static var g080 = g000.withAlphaComponent(0.80)
    static var g085 = g000.withAlphaComponent(0.85)
    static var g087 = g000.withAlphaComponent(0.87)
    static var g090 = g000.withAlphaComponent(0.90)
    static var g095 = g000.withAlphaComponent(0.95)
    /// 自定义黑色
    /// 090909
    static var g1009 = UIColor(rgba: "#090909")
    /// 101010
    static var g1010 = UIColor(rgba: "#101010")
    /// 181818
    static var g1018 = UIColor(rgba: "#181818")
    /// 1C1C1C
    static var g101C = UIColor(rgba: "#1C1C1C")
    /// 1E1E1E
    static var g101E = UIColor(rgba: "#1E1E1E")
    /// 212121
    static var g1021 = UIColor(rgba: "#212121")
    /// 030303
    static var g1003 = UIColor(rgba: "#030303")
    /// 202020
    static var g1020 = UIColor(rgba: "#202020")
    /// 232323
    static var g1023 = UIColor(rgba: "#232323")
    /// 262626
    static var g1026 = UIColor(rgba: "#262626")
    /// 2C2B2B
    static var g102C = UIColor(rgba: "#2C2B2B")
    /// 333333
    static var g1033 = UIColor(rgba: "#333333")
    /// 363636
    static var g1036 = UIColor(rgba: "#363636")
    /// 393939
    static var g1039 = UIColor(rgba: "#393939")
    /// 383838
    static var g1038 = UIColor(rgba: "#383838")
    /// 3E3E3E
    static var g103E = UIColor(rgba: "#3E3E3E")
    /// 484848
    static var g1048 = UIColor(rgba: "#484848")
    /// 5F5F5F
    static var g105F = UIColor(rgba: "#5F5F5F")
    /// 535353
    static var g1053 = UIColor(rgba: "#535353")
    /// 666666
    static var g1066 = UIColor(rgba: "#666666")
    /// 767676
    static var g1076 = UIColor(rgba: "#767676")
    /// 7F7F7F
    static var g107F = UIColor(rgba: "#7F7F7F")
    /// 9F9F9F
    static var g109F = UIColor(rgba: "#9F9F9F")
    /// 979797
    static var g1097 = UIColor(rgba: "#979797")
    /// B8B8B8
    static var g10B8 = UIColor(rgba: "#B8B8B8")
    /// C0C0C0
    static var g10C0 = UIColor(rgba: "#C0C0C0")
    /// CCCCCC
    static var g10CC = UIColor(rgba: "#CCCCCC")
    /// C4C4C4
    static var g10C4 = UIColor(rgba: "#C4C4C4")
    /// C4C4C4 0.3
    static var g13C4 = g10C4.withAlphaComponent(0.3)
    /// D8D8D8
    static var g10D8 = UIColor(rgba: "#D8D8D8")
    /// DCDCDC
    static var g10DC = UIColor(rgba: "#DCDCDC")
    /// DFDFDF
    static var g10DF = UIColor(rgba: "#DFDFDF")
    /// E1E1E1
    static var g10E1 = UIColor(rgba: "#E1E1E1")
    /// E2E2E2
    static var g10E2 = UIColor(rgba: "#E2E2E2")
    /// E3E3E3
    static var g10E3 = UIColor(rgba: "#E3E3E3")
    /// E4E4E4
    static var g10E4 = UIColor(rgba: "#E4E4E4")
    /// E6E6E6
    static var g10E6 = UIColor(rgba: "#E6E6E6")
    // E8E8E8
    static var g10E8 = UIColor(rgba: "#E8E8E8")
    /// EDEDED
    static var g10ED = UIColor(rgba: "#EDEDED")
    /// F0F0F0
    static var g10F0 = UIColor(rgba: "#F0F0F0")
    /// F1F1F1
    static var g10F1 = UIColor(rgba: "#F1F1F1")
    /// F2F2F2
    static var g10F2 = UIColor(rgba: "#F2F2F2")
    /// F3F3F3
    static var g10F3F3 = UIColor(rgba: "#F3F3F3")
    /// F3F6F8
    static var g10F3 = UIColor(rgba: "#F3F6F8")
    /// F4F4F4
    static var g10F4 = UIColor(rgba: "#F4F4F4")
    /// F5F5F5
    static var g10F5 = UIColor(rgba: "#F5F5F5")
    /// F6F6F6
    static var g10F6 = UIColor(rgba: "#F6F6F6")
    /// F7F7F7
    static var g10F7 = UIColor(rgba: "#F7F7F7")
    /// FBFBFB
    static var g10FB = UIColor(rgba: "#FBFBFB")
    /// FFF8FB
    static var g10FF = UIColor(rgba: "#FFF8FB")
    /// 7E96C4
    static var g10E9 = UIColor(rgba: "#7E96C4").withAlphaComponent(0.2)
    /// 949494
    static var g1094 = UIColor(rgba: "#949494")
    /// E7E7E7
    static var g10E7 = UIColor(rgba: "#E7E7E7")
    /// EFEFEF
    static var g10EF = UIColor(rgba: "#EFEFEF")
    /// 494949
    static var g1049 = UIColor(rgba: "#494949")
    /// C7C7C7
    static var g10c7 = UIColor(rgba: "#C7C7C7")
    /// B2B2B2
    static var g10B2 = UIColor(rgba: "#B2B2B2")
    /// F4F5F6
    static var gF4F5F6 = UIColor(rgba: "#F4F5F6")
    /// 2A2A2A
    static var g2A2A2A = UIColor(rgba: "#2A2A2A")
    /// D9D9D9
    static var g10D9 = UIColor(rgba: "#D9D9D9")
    /// 363636
    static var g363636 = UIColor(rgba: "#363636")
    /// FFFCF5
    static var g10FFFC = UIColor(rgba: "#FFFCF5")
    /// 2F2F2F
    static var g2f2f2f = UIColor(rgba: "#2F2F2F")
    /// FFA23F
    static var gFFA23F = UIColor(rgba: "#FFA23F")
    /// 1B1B1B
    static var g1B1B1B = UIColor(rgba: "#1B1B1B")
    
    /// 纯白
    static var g200: UIColor = .white
    static var g203 = g200.withAlphaComponent(0.03)
    static var g205 = g200.withAlphaComponent(0.05)
    static var g206 = g200.withAlphaComponent(0.06)
    static var g207 = g200.withAlphaComponent(0.07)
    static var g208 = g200.withAlphaComponent(0.08)
    static var g210 = g200.withAlphaComponent(0.10)
    static var g212 = g200.withAlphaComponent(0.12)
    static var g215 = g200.withAlphaComponent(0.15)
    static var g216 = g200.withAlphaComponent(0.16)
    static var g220 = g200.withAlphaComponent(0.20)
    static var g224 = g200.withAlphaComponent(0.24)
    static var g225 = g200.withAlphaComponent(0.25)
    static var g230 = g200.withAlphaComponent(0.30)
    static var g235 = g200.withAlphaComponent(0.35)
    static var g240 = g200.withAlphaComponent(0.40)
    static var g242 = g200.withAlphaComponent(0.42)
    static var g245 = g200.withAlphaComponent(0.45)
    static var g250 = g200.withAlphaComponent(0.50)
    static var g260 = g200.withAlphaComponent(0.60)
    static var g270 = g200.withAlphaComponent(0.70)
    static var g280 = g200.withAlphaComponent(0.80)
    static var g287 = g200.withAlphaComponent(0.87)
    static var g290 = g200.withAlphaComponent(0.90)
    static var g295 = g200.withAlphaComponent(0.95)
    
    /// 自定义白色
    /// F3F3F3
    static var g20F3 = UIColor(rgba: "#F3F3F3")
    /// 66A462
    static var g66A462 = UIColor(rgba: "#66A462")
}

/// 红色系
extension UIColor {
    /// 纯红
    static var r000: UIColor = .red
    static var r005 = r000.withAlphaComponent(0.05)
    static var r006 = r000.withAlphaComponent(0.05)
    static var r007 = r000.withAlphaComponent(0.07)
    static var r008 = r000.withAlphaComponent(0.08)
    static var r010 = r000.withAlphaComponent(0.10)
    static var r015 = r000.withAlphaComponent(0.15)
    static var r016 = r000.withAlphaComponent(0.16)
    static var r020 = r000.withAlphaComponent(0.20)
    static var r025 = r000.withAlphaComponent(0.25)
    static var r030 = r000.withAlphaComponent(0.30)
    static var r035 = r000.withAlphaComponent(0.35)
    static var r040 = r000.withAlphaComponent(0.40)
    static var r045 = r000.withAlphaComponent(0.45)
    static var r050 = r000.withAlphaComponent(0.50)
    static var r070 = r000.withAlphaComponent(0.70)
    static var r080 = r000.withAlphaComponent(0.80)
    static var r087 = r000.withAlphaComponent(0.87)
    static var r090 = r000.withAlphaComponent(0.90)
    static var r095 = r000.withAlphaComponent(0.95)
    
    /// 自定义红色
    /// F24343
    static var r10F2: UIColor = UIColor(rgba: "#F24343")
    /// F5AAB3
    static var r10F5: UIColor = UIColor(rgba: "#F5AAB3")
    /// FA6262
    static var r10FA: UIColor = UIColor(rgba: "#FA6262")
    /// FF3B30
    static var r10FF: UIColor = UIColor(rgba: "#FF3B30")
    /// FFCBE1
    static var r10FFC: UIColor = UIColor(rgba: "#FFCBE1")
    /// FF478E
    static var r10FF47: UIColor = UIColor(rgba: "#FF478E")
    /// FF4848
    static var r10FF48: UIColor = UIColor(rgba: "#FF4848")
    /// FF8A80
    static var r10FF8A: UIColor = UIColor(rgba: "#FF8A80")
    /// A66B27
    static var rA66B27: UIColor = UIColor(rgba: "#A66B27")
    /// FFDC6E
    static var rFFDC6E: UIColor = UIColor(rgba: "#FFDC6E")
    /// FF930F
    static var rFF930F: UIColor = UIColor(rgba: "#FF930F")
    /// F95774
    static var rF95774: UIColor = UIColor(rgba: "#F95774")
    /// FD5659
    static var rFD5659: UIColor = UIColor(rgba: "#FD5659")
    /// EFDDD6
    static var rEFDDD6: UIColor = UIColor(rgba: "#EFDDD6")
    /// F8DABE
    static var rF8DABE: UIColor = UIColor(rgba: "#F8DABE")
    /// FF7E76
    static var rFF7E76: UIColor = UIColor(rgba: "#FF7E76")
    /// FF4954
    static var rFF4954: UIColor = UIColor(rgba: "#FF4954")
    /// FF38C7
    static var rFF38C7: UIColor = UIColor(rgba: "#FF38C7")
    /// FF4954 0.5
    static var rFF495450: UIColor = UIColor(rgba: "#FF4954").withAlphaComponent(0.5)
    /// FF38C7 0.5
    static var rFF38C750: UIColor = UIColor(rgba: "#FF38C7").withAlphaComponent(0.5)
    /// EE4EAC
    static var rEE4EAC: UIColor = UIColor(rgba: "#EE4EAC")
    /// FF5ABD
    static var rFF5ABD: UIColor = UIColor(rgba: "#FF5ABD")
    /// FF5050
    static var rFF5050: UIColor = UIColor(rgba: "#FF5050")
    /// FF6666
    static var rFF6666: UIColor = UIColor(rgba: "#FF6666")
    /// FF1F00
    static var rFF1F00: UIColor = UIColor(rgba: "#FF1F00")
    /// FF574D
    static var rFF574D: UIColor = UIColor(rgba: "#FF574D")
}

/// 黄色系
extension UIColor {
    /// 纯黄
    static var y000: UIColor = .yellow
    
    /// 自定义黄色
    /// AD751A
    static var y10AD7: UIColor = UIColor(rgba: "#AD751A")
    /// D2A868
    static var y10D2A: UIColor = UIColor(rgba: "#D2A868")
    /// D2B589
    static var y10D2B: UIColor = UIColor(rgba: "#D2B589")
    /// F4C173
    static var y10F4: UIColor = UIColor(rgba: "#F4C173")
    /// FEDAA3
    static var y10FED: UIColor = UIColor(rgba: "#FEDAA3")
    /// FEDAA3
    static var y10FED10: UIColor = UIColor(rgba: "#FEDAA3").withAlphaComponent(0.10)
    /// FFD400
    static var y10FFD4: UIColor = UIColor(rgba: "#FFD400")
    /// FEDAA3
    static var y10FEDA: UIColor = UIColor(rgba: "#FEDAA3")
    /// FFE30D
    static var y10FFE3: UIColor = UIColor(rgba: "#FFE30D")
    /// FFEACB
    static var y10FFEA: UIColor = UIColor(rgba: "#FFEACB")
    /// FFBE5C
    static var y10FFBE: UIColor = UIColor(rgba: "#FFBE5C")
    /// FFF9F0
    static var y10FFF9: UIColor = UIColor(rgba: "#FFF9F0")
    /// C7AF94
    static var yC7AF94: UIColor = UIColor(rgba: "#C7AF94")
    /// 6C6052
    static var y6C6052: UIColor = UIColor(rgba: "#6C6052")
    /// 38342E
    static var y38342E: UIColor = UIColor(rgba: "#38342E")
    /// E7BD7F
    static var yE7BD7F: UIColor = UIColor(rgba: "#E7BD7F")
    /// FEDAA3
    static var yFEDAA3: UIColor = UIColor(rgba: "#FEDAA3")
    /// ECA21E
    static var yECA21E: UIColor = UIColor(rgba: "#ECA21E")
    /// yFEDAA350
    static var yFEDAA350: UIColor = UIColor(rgba: "#FEDAA3").withAlphaComponent(0.50)
    /// yFEDAA320
    static var yFEDAA320: UIColor = UIColor(rgba: "#FEDAA3").withAlphaComponent(0.20)
    /// yFEDAA327
    static var yFEDAA327: UIColor = UIColor(rgba: "#FEDAA3").withAlphaComponent(0.27)
    /// yFEDAA330
    static var yFEDAA330: UIColor = UIColor(rgba: "#FEDAA3").withAlphaComponent(0.30)
    /// yFEDAA330
    static var yFEDAA310: UIColor = UIColor(rgba: "#FEDAA3").withAlphaComponent(0.10)
    /// yFEDAA306
    static var yFEDAA306: UIColor = UIColor(rgba: "#FEDAA3").withAlphaComponent(0.06)
    /// yFEDAA387
    static var yFEDAA387: UIColor = UIColor(rgba: "#FEDAA3").withAlphaComponent(0.87)
    /// FFE600
    static var yFFE600: UIColor = UIColor(rgba: "#FFE600")
    /// FFECD1
    static var yFFECD1: UIColor = UIColor(rgba: "#FFECD1")
    /// FFE500
    static var yFFE500: UIColor = UIColor(rgba: "#FFE500")
    /// 816030
    static var y816030: UIColor = UIColor(rgba: "#816030")
    /// #D89933
    static var yD89933: UIColor = UIColor(rgba: "#D89933")
    /// D99632
    static var yD99632: UIColor = UIColor(rgba: "#D99632")
    /// FFDA94
    static var yFFDA94: UIColor = UIColor(rgba: "#FFDA94")
    /// FEDAA3_034
    static var y10FED034: UIColor = UIColor(rgba: "#FEDAA3").withAlphaComponent(0.34)
    /// FEDAA3_012
    static var y10FED012: UIColor = UIColor(rgba: "#FEDAA3").withAlphaComponent(0.12)
    
    /// B14746
    static var yB14746: UIColor = UIColor(rgba: "#B14746")
    /// C8A99C
    static var yC8A99C: UIColor = UIColor(rgba: "#C8A99C")
    /// E4C5AB
    static var yE4C5AB: UIColor = UIColor(rgba: "#E4C5AB")
    /// FFF5E5
    static var yFF5E5: UIColor = UIColor(rgba: "#FFF5E5")
    /// F0DDC1
    static var yF0DD: UIColor = UIColor(rgba: "#F0DDC1")
    /// C59956
    static var yC599: UIColor = UIColor(rgba: "#C59956")
    /// B85A15
    static var yB85A: UIColor = UIColor(rgba: "#B85A15")
    /// FFDFB0
    static var yFFDFB0: UIColor = UIColor(rgba: "#FFDFB0")
    /// C68818
    static var yC688: UIColor = UIColor(rgba: "#C68818")
    /// E29829
    static var yE29829: UIColor = UIColor(rgba: "#E29829")
    /// C68A18
    static var yC68A18: UIColor = UIColor(rgba: "#C68A18")
    /// FFD9A3
    static var yFFD9A3: UIColor = UIColor(rgba: "#FFD9A3")
    /// 9B6449
    static var y9B6449: UIColor = UIColor(rgba: "#9B6449")
    /// F4ECDD
    static var yF4ECDD: UIColor = UIColor(rgba: "#F4ECDD")
    /// 7A5C54
    static var y7A5C54: UIColor = UIColor(rgba: "#7A5C54")
    /// FFF1DC
    static var yFFF1DC: UIColor = UIColor(rgba: "#FFF1DC")
    /// F2A93C
    static var yF2A93C: UIColor = UIColor(rgba: "#F2A93C")
    /// FFF9E7
    static var yFFF9E7: UIColor = UIColor(rgba: "#FFF9E7")
    /// 826A66
    static var y826A66: UIColor = UIColor(rgba: "#826A66")
    /// 826A6620
    static var y826A6620: UIColor = y826A66.withAlphaComponent(0.2)
    /// 826A6660
    static var y826A6660: UIColor = y826A66.withAlphaComponent(0.6)
    /// 826A6670
    static var y826A6670: UIColor = y826A66.withAlphaComponent(0.7)
    /// 826A6680
    static var y826A6680: UIColor = y826A66.withAlphaComponent(0.8)
    /// F4E6CB
    static var yF4E6CB: UIColor = UIColor(rgba: "#F4E6CB")
    /// FFFCF7
    static var yFFFCF7: UIColor = UIColor(rgba: "#FFFCF7")
    /// EED3C4
    static var yEED3C4: UIColor = UIColor(rgba: "#EED3C4")
    /// F0C49B
    static var yF0C49B: UIColor = UIColor(rgba: "#F0C49B")
    /// F0C49B22
    static var yF0C49B22: UIColor = yF0C49B.withAlphaComponent(0.22)
}

/// 紫色系
extension UIColor {
    /// 纯紫
    static var p000: UIColor = .purple
    
    /// 自定义紫色
    /// 8F6BB3
    static var p101: UIColor = UIColor(rgba: "#8F6BB3")
    /// 9AB5E2
    static var p130: UIColor = UIColor(rgba: "#9AB5E2")
    /// 9BB1FE
    static var p135: UIColor = UIColor(rgba: "#9BB1FE")
    /// B9D3FF
    static var p150: UIColor = UIColor(rgba: "#B9D3FF")
    /// FFEDAC
    static var pFFEDAC: UIColor = UIColor(rgba: "#FFEDAC")
    /// F094EC
    static var pF094EC: UIColor = UIColor(rgba: "#F094EC")
    /// 9D8EF5
    static var p9D8EF5: UIColor = UIColor(rgba: "#9D8EF5")
    /// 75E5EB
    static var p75E5EB: UIColor = UIColor(rgba: "#75E5EB")
    /// AA70CE
    static var pAA70CE: UIColor = UIColor(rgba: "#AA70CE")
    /// 8971EB
    static var p8971EB: UIColor = UIColor(rgba: "#8971EB")
    /// 8971EB 10
    static var p8971EB10: UIColor = UIColor(rgba: "#8971EB").alpha(0.1)
    /// EBE0FF
    static var pEBE0FF: UIColor = UIColor(rgba: "#EBE0FF")
}

/// 蓝色系
extension UIColor {
    /// 纯蓝色
    static var b000: UIColor = .blue
    
    /// 自定义蓝色
    /// BAE6F7
    static var b10BA: UIColor = UIColor(rgba: "#BAE6F7")
    /// 467AC8
    static var b1046: UIColor = UIColor(rgba: "#467AC8")
    /// 470D63
    static var b470D63: UIColor = UIColor(rgba: "#470D63")
    /// 514EFF
    static var b514EFF: UIColor = UIColor(rgba: "#514EFF")
    /// BEECE6
    static var b10BE: UIColor = UIColor(rgba: "#BEECE6")
    /// 7DD7FC
    static var b107D: UIColor = UIColor(rgba: "#7DD7FC")
    /// 6183CC
    static var b6183CC: UIColor = UIColor(rgba: "#6183CC")
    /// 214BA5
    static var b214BA5: UIColor = UIColor(rgba: "#214BA5")
    /// 80D1C4
    static var b80D1C4: UIColor = UIColor(rgba: "#80D1C4")
    /// 076458
    static var b076458: UIColor = UIColor(rgba: "#076458")
    /// BEECE6
    static var bBEECE6: UIColor = UIColor(rgba: "#BEECE6")
    /// 8CF8FF
    static var b8CF8FF: UIColor = UIColor(rgba: "#8CF8FF")
    /// 143BA1
    static var b143BA1: UIColor = UIColor(rgba: "#143BA1")
    /// 1A4DD1
    static var b1A4DD1: UIColor = UIColor(rgba: "#1A4DD1")
    /// 9FDDFF
    static var b9FDDFF: UIColor = UIColor(rgba: "#9FDDFF")
    /// 3A8CFF
    static var b3A8CFF: UIColor = UIColor(rgba: "#3A8CFF")
    /// 56E4F0
    static var b56E4F0: UIColor = UIColor(rgba: "#56E4F0")
    /// 2894D8
    static var b2894D8: UIColor = UIColor(rgba: "#2894D8")
    /// 467AC8
    static var b467AC8: UIColor = UIColor(rgba: "#467AC8")
}

/// 绿色系
extension UIColor {
    /// 纯绿
    static var gr000: UIColor = .green
    /// 自定义
    static var gr1ED760: UIColor = UIColor(rgba: "#1ED760")
}

extension UIColor {
    var color: Color {
        return Color(self)
    }
}


// 生成随机颜色扩展
extension Color {
    static func random() -> Color {
        return Color(
            red: .random(in: 0...1),
            green: .random(in: 0...1),
            blue: .random(in: 0...1)
        )
    }
}
