//
//  TPChangeVoiceView.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/9/10.
//

import SwiftUI

struct TPChangeVoiceItemModel {
    var id: Int
    var name: String
    var iconName: String
    var using: Bool // 使用中
}

struct TPChangeVoiceView: View {
    @State var selectedIndex: Int = 0
    var list = [
        TPChangeVoiceItemModel(id: 0, name: "原生", iconName: "默认声音", using: false),
        TPChangeVoiceItemModel(id: 1, name: "小男孩", iconName: "小孩声", using: true),
        TPChangeVoiceItemModel(id: 2, name: "匿名男", iconName: "匿名男", using: false),
        TPChangeVoiceItemModel(id: 3, name: "匿名女", iconName: "匿名女", using: false),
        TPChangeVoiceItemModel(id: 4, name: "小女孩", iconName: "小女孩", using: false),
        TPChangeVoiceItemModel(id: 5, name: "原生", iconName: "默认声音", using: false),
        TPChangeVoiceItemModel(id: 6, name: "小男孩", iconName: "小孩声", using: true),
        TPChangeVoiceItemModel(id: 7, name: "匿名男", iconName: "匿名男", using: false),
        TPChangeVoiceItemModel(id: 8, name: "匿名女", iconName: "匿名女", using: false),
        TPChangeVoiceItemModel(id: 9, name: "小女孩", iconName: "小女孩", using: false)
    ]
    
    var selectedModel: TPChangeVoiceItemModel {
        return list.first { $0.id == selectedIndex } ?? TPChangeVoiceItemModel(id: 3, name: "匿名女", iconName: "匿名女", using: false)
    }
    
    var body: some View {
        VStack(alignment: .leading,
               spacing: 20.tp.fitScreen) {
            VStack(alignment: .leading, spacing: 5.tp.fitScreen) {
                Text("ボイスチェンジを試聴")
                    .boldFont(16)
                    .foregroundColor(.g287)
                if selectedModel.id == 0 {
                    Text("\(selectedModel.name)....... 試してみよう！")
                        .font(12)
                        .foregroundColor(.g250)
                } else {
                    Text("\(selectedModel.name)....... 試してみよう！試してみよう！試してみよう！試してみよう！試してみよう！")
                        .font(12)
                        .foregroundColor(.g250)
                }
            }
            .frame(width: .infinity)
            
            UIColor.g216.color
                .frame(height: 1.0)
            
            TPChangeVoiceContainerView(selectedIndex: $selectedIndex, datas: list)
                .frame(maxHeight: 270.tp.fitScreen)
            
            HStack {
                Spacer()
                Button {
                    print("按钮被点击")
                } label: {
                    Text("使う")
                        .frame(width: 78.tp.fitScreen, height: 28.tp.fitScreen)
                        .boldFont(12)
                        .foregroundColor(.g000)
                        .background(UIColor.y10FED.color)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14.tp.fitScreen)
                                .inset(by: 0.5)
                                .stroke(UIColor.y10FED.color)
                        )
                        .cornerRadius(14.tp.fitScreen)
                }
            }
        }
        .padding(EdgeInsets(top: 20.tp.fitScreen,
                            leading: 20.tp.fitScreen,
                            bottom: 20.tp.fitScreen,
                            trailing: 20.tp.fitScreen))
        .background(UIColor.g101C.color)
        .clipShape(CornersRounded(cornerRadius: 16.tp.fitScreen, corners: [.topLeft, .topRight]))
    }
}

struct TPChangeVoiceContainerView: View {
    @Binding var selectedIndex: Int
    let datas: [TPChangeVoiceItemModel]
    let colums: Int = 4
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading,
                   spacing: 10.tp.fitScreen) {
                ForEach(0..<datas.count, id:\.self) { index in
                    let row = index / colums
                    if index % colums == 0 {
                        HStack(spacing: 10.tp.fitScreen) {
                            ForEach(0 ..< colums, id:\.self) { colum in
                                let currentIndex = row * colums + colum
                                if currentIndex < datas.count {
                                    TPHeaderCell(model: datas[currentIndex], isSelected: self.selectedIndex == currentIndex)
                                        .onTapGesture {
                                            self.selectedIndex = row * colums + colum
                                        }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct TPHeaderCell: View {
    let model: TPChangeVoiceItemModel
    let isSelected: Bool
    var body: some View {
        ZStack(alignment: .centerLastTextBaseline) {
            VStack {
                Spacer()
                    .frame(height: 11.tp.fitScreen)
                Image(model.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56.tp.fitScreen, height: 56.tp.fitScreen)
                Spacer()
                    .frame(height: 16.tp.fitScreen)
                Text(model.name)
                    .font(13)
                    .foregroundColor(.g287)
                Spacer()
                    .frame(height: 4.tp.fitScreen)
            }
            .frame(width: 88.tp.fitScreen,
                   height: 106.tp.fitScreen)
            if model.using {
                Text("使用中")
                    .padding()
                    .frame(width: 88.tp.fitScreen,
                           height: 27.tp.fitScreen)
                    .font(14)
                    .foregroundColor(.g000)
                    .background(UIColor.y10FED.color)
                    .clipShape(CornersRounded(cornerRadius: 8.tp.fitScreen, corners: [.bottomLeft, .bottomRight]))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8.tp.fitScreen)
                .inset(by: 0.5)
                .stroke(isSelected ? Color.red: UIColor.clear.color, lineWidth: 1)
        )
    }
}

#Preview {
    TPChangeVoiceView()
}

