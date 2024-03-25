//
//  AudioLiveProcessContent.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/1/26.
//

import SwiftUI

/// 累计进度
struct AudioLiveProcessContent: View {
    @State var proValue: CGFloat = 0.1
    var body: some View {
        VStack(alignment: .leading, spacing: 16.0) {
            HStack {
                Text("今月のスコア状況")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.87))
                Spacer()
                Button {
                    debugPrint("查看历史记录")
                    self.proValue += 0.1
                } label: {
                    Text("過去のランクを見る")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                    Image("clock")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16.0, height: 16.0)
                }
            }
            Color.white.opacity(0.06).frame(height: 1.0)
            ProcessContent(value: $proValue)
        }
        .padding(.horizontal, 20.0)
        .padding(.vertical, 16.0)
        .background(Color.white.opacity(0.12))
        .clipShape(CornersRounded(cornerRadius: 8.0, corners: .allCorners))
    }
}


struct ProcessContent: View {
    @Binding var value: CGFloat
    var body: some View {
        VStack(spacing: 10.0) {
            HStack {
                Text("今月の獲得スコア 123")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("本次+100分数")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 1, green: 0.85, blue: 0.64))
            }
            ProgressBar(value: $value,
                        bgColor: .white.opacity(0.5),
                        tintColor: Color(red: 1, green: 0.85, blue: 0.64),
                        cornerRadius: 4.0)
            .frame(height: 8.0)
            HStack {
                Text("E")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text("D")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
    }
}

struct ProgressBar: View {
    @Binding var value: CGFloat // 当前进度值，范围从 0.0 到 1.0
    let bgColor: Color // 背景色
    let tintColor: Color
    let cornerRadius: CGFloat
    init(value: Binding<CGFloat> = .constant(0.0),
         bgColor: Color,
         tintColor: Color,
         cornerRadius: CGFloat) {
        self._value = value
        self.bgColor = bgColor
        self.tintColor = tintColor
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle() // 进度条的背景
                    .foregroundColor(bgColor)
                
                Rectangle() // 进度条的前景（填充部分）
                    .frame(width: min(geometry.size.width * value, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(tintColor)
                    .animation(.linear, value: value)
                    .cornerRadius(cornerRadius)
            }
            .cornerRadius(cornerRadius)
        }
    }
}

#Preview {
    AudioLiveProcessContent()
        .background(Color.black)
}
