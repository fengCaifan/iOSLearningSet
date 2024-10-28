//
//  ProgressViewTest.swift
//  SwiftUIiOS14Demo
//
//  Created by fengcaifan on 2024/10/28.
//

import SwiftUI

struct ProgressViewTest: View {
    @State private var progress = 0.0
    var body: some View {
        LazyVStack(spacing: 10.0) {
//            ProgressView() // 1、单纯菊花
//            
//            ProgressView()
//                .progressViewStyle(CircularProgressViewStyle()) // 3、单纯显示菊花
//            ProgressView()
//                .progressViewStyle(CircularProgressViewStyle(tint: .red)) // 3、修改菊花颜色
            
            
            ProgressView("2.1:Loading...") // 2、菊花+文字
            ProgressView("2.1:Loading...")
                .foregroundColor(.red)
            ProgressView("2:Loading...")
                .progressViewStyle(CircularProgressViewStyle(tint: .red))
            ProgressView("2:Loading...")
                .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                .foregroundColor(.yellow)

            
            ProgressView(value: 10, total: 100) // 1、单纯进度条
            
            ProgressView("3:Loading...", value: 10, total: 100) // 2、文字+进度条
            ProgressView("3.1:Loading...", value: 10, total: 100) // 3、文字+进度条
                .foregroundColor(.purple) // 文字颜色
                .progressViewStyle(LinearProgressViewStyle(tint: .red)) // 进度条颜色
            
            
            // 5、文字+进度条，默认情况下progressViewStyle就是LinearProgressViewStyle。与4没什么分别
//            ProgressView("3.2:Loading...", value: 10, total: 100)
//                .progressViewStyle(LinearProgressViewStyle())
//            
//            ProgressView("3.3:Loading...", value: 10, total: 100)
//                
            
            Button("Start 6 Loading") {
                            startLoading()
                        }
            
            ProgressView(value: progress, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: .red)) // 设置进度条颜色
                .frame(height: 20) // 设置高度
                .background(Color.orange.opacity(0.3)) // 设置背景颜色 （没有效果）
                .cornerRadius(10) // 圆角
            
            
            ProgressView(value: progress, total: 100)
                .progressViewStyle(TPLinearProgressViewStyle(progressColor: .purple, trackColor: .red, cornerRadius: 10.0))
                .frame(height: 20.0)

            Spacer()
            ProgressView(value: progress, total: 100)
                .progressViewStyle(TPCircularProgressViewStyle(lineWidth: 20, foregroundColor: .purple, backgroundColor: .gray))
                .frame(width: 100, height: 100) // 设置圆环的大小
            
        }
        .padding()
    }
    
    func startLoading() {
        // 重置进度
        progress = 0
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if progress < 100 {
                progress += 1
            } else {
                timer.invalidate()
            }
        }
    }
}

// 自定义ProgressView进度条样式
struct TPLinearProgressViewStyle: ProgressViewStyle {
    let progressColor: Color
    let trackColor: Color
    var cornerRadius: CGFloat?
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                trackColor
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .cornerRadius( cornerRadius ?? geometry.size.height * 0.5)
                
                progressColor
                    .frame(width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0), height: geometry.size.height)
                    .cornerRadius(cornerRadius ?? geometry.size.height * 0.5)
            }
        }
    }
}

// 自定义环形ProgressView进度条样式
struct TPCircularProgressViewStyle: ProgressViewStyle {
    var lineWidth: CGFloat = 10 // 线宽
    var foregroundColor: Color = .blue // 进度颜色
    var backgroundColor: Color = .gray // 背景颜色

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            // 背景圆环
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            // 进度圆环
            Circle()
                .trim(from: 0, to: CGFloat(configuration.fractionCompleted ?? 0)) // 根据进度裁剪
                .stroke(foregroundColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90)) // 从顶部开始绘制
                .animation(.linear(duration: 0.2), value: configuration.fractionCompleted) // 动画效果
        }
    }
}

#Preview {
    ProgressViewTest()
}
