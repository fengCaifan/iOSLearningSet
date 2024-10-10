//
//  TPCpRankingView.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/9/29.
//

import SwiftUI

struct Item: Identifiable {
    var id: Int
    var content: String
}

struct TPCpRankingView: View {
    var items: [Item] = [
            Item(id: 1, content: "第1名xsdad"),
            Item(id: 2, content: "第2名dad"),
            Item(id: 3, content: "第3名dasfvv"),
            Item(id: 4, content: "第4名fafva"),
            Item(id: 5, content: "第5名udoaiuoidujocjvj"),
            Item(id: 6, content: "第6名daijsfjlakjf"),
            Item(id: 7, content: "第7名da"),
            Item(id: 8, content: "第8名")
        ]
    
    ///
    var body: some View {
        GeometryReader { geometry in
//            ZStack {
//                UIColor.g101C.color.edgesIgnoringSafeArea(.all)
                VStack {
                    List {
                        // 显示 TPCpRankTop3ContainerView 仅一次
                        TPCpRankTop3ContainerView()
                            .listRowBackground(UIColor.g101C.color)
                            .listRowInsets(EdgeInsets())
                        
                        ForEach(items) { item in
                            if item.id > 3 {
                                TPCpRankOtherCell(item: item)
                                    .listRowBackground(UIColor.g101C.color)
                                    .listRowInsets(EdgeInsets(top: 0, leading: 16.tp.fitScreen, bottom: 16.tp.fitScreen, trailing: 16.tp.fitScreen))
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    
//                    Spacer()
                    VStack {
//                        TPCpRankOtherCell(item: Item(id: 1, content: "第1名xsdad"))
//                            .frame(height: 82.tp.fitScreen)
//                            .padding(.horizontal, 16.tp.fitScreen)
                        Button {
                            debugPrint("点击了组cp按钮")
                        } label: {
                            Text("グラ友plusを作ろう！")
                                .boldFont(18)
                                .foregroundColor(.g000)
                                .frame(width: geometry.size.width - 48.tp.fitScreen, height: 56.tp.fitScreen)
                                .background(UIColor.y10FED.color)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28.tp.fitScreen)
                                        .inset(by: 0.5)
                                        .stroke(UIColor.y10FED.color)
                                )
                                .cornerRadius(28.tp.fitScreen)
                        }
                        Spacer()
                            .frame(width: geometry.size.width, height: 36.tp.fitScreen)
                    }
                    .background(UIColor.g000.color)
                }
//                .frame(maxWidth: .infinity, maxHeight: .infinity) // 让整个内容视图填充整个窗口
//                        .padding(.bottom, geometry.safeAreaInsets.bottom) // 在底部增加额外的填充以适应安全区域
//            }
        }
        .edgesIgnoringSafeArea(.bottom) // 忽略底部安全区域
    }
}



struct TPCpRankTop3ContainerView: View {
    var body: some View {
        ZStack {
            VStack(spacing: 0.0) {
                Spacer().frame(height: 83.tp.fitScreen)
                Image("cp_ranking_bg")
                    .resizable()
//                    .scaledToFit()
            }
            
            VStack(spacing: 25.tp.fitScreen) {
                TPCpRankTop3Cell(rankNum: 1)
                
                HStack(spacing: 30.tp.fitScreen) {
                    TPCpRankTop3Cell(rankNum: 2)
                    TPCpRankTop3Cell(rankNum: 3)
                }
                .padding(.top, -30.tp.fitScreen)
            }
        }
        .frame(height: 372.tp.fitScreen)
        .padding(.all, 16.tp.fitScreen)
    }
}

struct TPCpRankTop3Cell: View {
    let rankNum: Int
    var body: some View {
        VStack(alignment: .center, spacing: 12.tp.fitScreen) {
            TPCpPairsAvatarView(rankNum: rankNum)
            HStack(spacing: 0.0) {
                Text("親密度：")
                    .font(12)
                    .foregroundColor(.yFEDAA387)
                Text("450,350,323")
                    .boldFont(16)
                    .foregroundColor(.y10FED)
            }
            Spacer()
        }
    }
}

struct TPCpPairsAvatarView: View {
    let rankNum: Int
    var headW: CGFloat {
        return rankNum == 1 ? 90.tp.fitScreen: 70.tp.fitScreen
    }
    var ringW: CGFloat {
        return rankNum == 1 ? 72.tp.fitScreen: 56.tp.fitScreen
        .tp.fitScreen
    }
    var ringH: CGFloat {
        return rankNum == 1 ? 54.tp.fitScreen: 42.tp.fitScreen
    }
    
    var body: some View {
        HStack {
            VStack {
                Image("girlAvtar01")
                    .resizable()
                    .scaledToFit()
                    .frame(width: headW, height: headW)
                Text("むろなみえ")
                    .font(12)
                    .foregroundColor(.g270)
                    .lineLimit(1)
                    .frame(width: headW)
            }
            .padding(.trailing, -20.tp.fitScreen)
            
            
            
            Image("ring01")
                .resizable()
                .scaledToFit()
                .frame(width: ringW, height: ringH)
            
            VStack {
                Image("boyAvatar01")
                    .resizable()
                    .scaledToFit()
                    .frame(width: headW, height: headW)
                Text("体験し名あむろなみえ")
                    .font(12)
                    .foregroundColor(.g270)
                    .lineLimit(1)
                    .frame(width: headW)
            }
            .padding(.leading, -20.tp.fitScreen)
        }
    }
}

struct TPCpRankOtherCell: View {
    let item: Item
    var body: some View {
        HStack(spacing: 8.tp.fitScreen) {
            Text("\(item.id)")
                .boldFont(18)
                .foregroundColor(.yFEDAA3)
            TPCpPairs2AvatarView()
            Text(item.content)
                .font(12)
                .foregroundColor(.g270)
                .lineLimit(2)
            Spacer()
            VStack {
                Text("親密度：")
                    .font(12)
                    .foregroundColor(.yFEDAA387)
                Text("45,350")
                    .boldFont(14)
                    .foregroundColor(.y10FED)
            }
        }
        .frame(height: 82.tp.fitScreen)
        .padding(.horizontal, 16.tp.fitScreen)
        .background(UIColor.g215.color)
        .clipShape(CornersRounded(cornerRadius: 16.tp.fitScreen, corners: .allCorners))
    }
}

struct TPCpPairs2AvatarView: View {
    var body: some View {
        HStack {
            Image("girlAvtar01")
                .resizable()
                .scaledToFit()
                .frame(width: 50.tp.fitScreen, height: 50.tp.fitScreen)
                .padding(.trailing, -20.tp.fitScreen)
            
            Image("ring01")
                .resizable()
                .scaledToFit()
                .frame(width: 40.tp.fitScreen, height: 30.tp.fitScreen)
            
            Image("boyAvatar01")
                .resizable()
                .scaledToFit()
                .frame(width: 50.tp.fitScreen, height: 50.tp.fitScreen)
                .padding(.leading, -20.tp.fitScreen)
        }
    }
}


#Preview {
    TPCpRankingView()
}



