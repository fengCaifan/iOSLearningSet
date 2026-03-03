//
//  TPNewPushAlertView.swift
//  SwiftUIiOS14Demo
//
//  Created by fengcaifan on 2025/3/17.
//

import SwiftUI

struct TPNewPushAlertView: View {
    @EnvironmentObject var theme: SwiftUITheme
    var body: some View {
        LazyVStack(spacing: 0.0) {
            Image("push_notif")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
            LazyVStack {
                desc()
                VGap(30.tp.fitScreen)
                bottomView {
                    debugPrint("点击了之后设置按钮")
                } clickedSure: {
                    debugPrint("点击了去接受按钮")
                }
            }
            .padding(24.tp.fitScreen)
            .backgroundColor(.white)
        }
        .cornerRadius(16.tp.fitScreen)
    }
    
    func desc() -> some View {
        LazyVStack(spacing: 0.0) {
            Text("打开系统通知")
                .mediumFont(20)
                .foregroundColor(.g000)
            VGap(24.tp.fitScreen)
            Text("可在站内设置中仅接收来自好友的消息！")
                .font(16)
                .foregroundColor(.g085)
                .multilineTextAlignment(.center)
            
            Text("設定方法：【マイページ】の右上→【設定】→【通知】")
                .font(16)
                .foregroundColor(.g085)
                .multilineTextAlignment(.center)
        }
        .backgroundColor(.red)
    }
    
    private func bottomView(clickedCancel: @escaping (() -> Void),
                            clickedSure: @escaping (() -> Void)) -> some View {
        LazyHStack(spacing: 10.tp.fitScreen) {
            Button {
                clickedCancel()
            } label: {
                Text("之后设置")
                    .boldFont(18)
                    .foregroundColor(.g030)
                    .frame(width: 182.tp.fitScreen, height: 48.tp.fitScreen)
                    .background(UIColor.g006.color)
                    .cornerRadius(24.tp.fitScreen)
            }
            Button {
                clickedSure()
            } label: {
                Text("去接收")
                    .boldFont(18)
                    .foregroundColor(.y10FED)
                    .frame(width: 182.tp.fitScreen, height: 48.tp.fitScreen)
                    .background(UIColor.g000.color)
                    .cornerRadius(24.tp.fitScreen)
            }
        }
    }
}

#Preview {
    TPNewPushAlertView()
        .background(Color.black.opacity(0.50))
}
