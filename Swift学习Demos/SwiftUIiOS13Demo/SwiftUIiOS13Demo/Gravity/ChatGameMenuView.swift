//
//  ChatGameMenuView.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/3/18.
//

import SwiftUI

struct GameMenuItemModel {
    var name: String
    var iconName: String
    var isNew: Bool
}

struct ChatGameMenuView: View {
    var list = [
        GameMenuItemModel(name: "グラ観覧車", iconName: "摩天轮", isNew: false),
        GameMenuItemModel(name: "赛马游戏", iconName: "赛马", isNew: true),
        GameMenuItemModel(name: "アニマルフィーバー", iconName: "老虎机", isNew: false),
        GameMenuItemModel(name: "抽選機", iconName: "扭蛋机", isNew: false),
        GameMenuItemModel(name: "音乐", iconName: "音乐", isNew: false),
        GameMenuItemModel(name: "しりとり", iconName: "接龙", isNew: false),
        GameMenuItemModel(name: "なぞなぞ", iconName: "猜字", isNew: false)
    ]
    let colums: Int = 3
    var body: some View {
        VStack {
            Text("过期详情")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.white)
            ScrollView {
                VStack(alignment: .leading, spacing: 24.0) {
                    ForEach(0..<list.count, id:\.self) { index in
                        let row = index / colums
                        if index % colums == 0 {
                            HStack(spacing: 22.0) {
                                ForEach(0 ..< colums, id:\.self) { colum in
                                    let currentIndex = row * colums + colum
                                    if currentIndex < list.count {
                                        GameMenuItem(item: list[currentIndex])
                                            .onTapGesture {
    //                                            self.selectedIndex = row * colums + colum
                                            }
                                    }
                                }
                            }
                        }
                    }
                }
//                .padding(10)
            }
//            .frame(maxHeight: 600.0)
        }
        .padding(EdgeInsets(top: 16.0,
                            leading: 24.0,
                            bottom: 24.0,
                            trailing: 24.0))
        .background(Color.black)
        .clipShape(CornersRounded(cornerRadius: 16.0, corners: [.topLeft, .topRight]))
    }
}

struct GameMenuItem: View {
    let item: GameMenuItemModel
    var body: some View {
        VStack(spacing: 8.0) {
            ZStack(alignment: .topTrailing) {
                Image(item.iconName)
                    .resizable()
                    .frame(width: 110.0, height: 110.0)
                    .scaledToFit()
                if item.isNew {
                    Image("new")
                        .resizable()
                        .frame(width: 43.0, height: 20.0)
                        .scaledToFit()
                }
            }
            VStack(spacing: 0.0) {
                Text(item.name)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 14))
                    .foregroundColor(Color.white)
                Spacer()
            }
            .frame(height: 42.0)
        }
    }
}

#Preview {
    ChatGameMenuView()
//        .background(Color.black)
}
