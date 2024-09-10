//
//  TPStyleToolContainerView.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/8/13.
//

import SwiftUI

struct TPStyleToolContainerView: View {
    var body: some View {
        VStack(spacing: 9.tp.fitScreen) {
            Spacer()
                .frame(height: 19.tp.fitScreen)
            TPStyleToolHeadViewCell()
            Spacer()
                .frame(height: 42.tp.fitScreen)
            Color(UIColor.g10F3F3)
                .frame(height: 1.0)
            HStack {
                Text("未使用")
                    .padding(.horizontal, 9.tp.fitScreen)
                    .padding(.vertical, 3.tp.fitScreen)
                    .boldFont(14)
                    .foregroundColor(.g087)
                    .background(UIColor.g005.color)
                    .cornerRadius(16.tp.fitScreen)
                Spacer()
            }
            TPStyleToolCollectionView()
            Spacer()
            Button {
                print("按钮被点击")
            } label: {
                Text("使用中")
                    .boldFont(16)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding()
                    .background(UIColor.y10FED.color)
                    .foregroundColor(.g000)
                    .cornerRadius(24.tp.fitScreen)
            }
            .frame(height: 48.tp.fitScreen)
            Spacer()
                .frame(height: 36.tp.fitScreen)
        }
        .padding(16.tp.fitScreen)
    }
}

struct TPStyleToolHeadViewCell: View {
    var body: some View {
        VStack(spacing: 0.0) {
            Image("中级沙漏")
                .resizable()
                .scaledToFit()
                .frame(width: 140.tp.fitScreen, height: 140.tp.fitScreen)
            Spacer()
                .frame(height: 4.tp.fitScreen)
            Text("中级沙漏")
                .font(.system(size: 18))
                .fontWeight(.bold)
                .foregroundColor(.g087)
            Spacer()
                .frame(height: 8.tp.fitScreen)
            Text("有効期限：3日")
                .font(.system(size: 14))
                .fontWeight(.regular)
                .foregroundColor(.g070)
        }
    }
}

struct TPStyleToolCollectionView: View {
    @State var selectedIndex: Int = 0
    
    let data = Array(0..<7)
    let colums: Int = 3
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16.tp.fitScreen) {
                ForEach(0..<data.count, id:\.self) { index in
                    let row = index / colums
                    if index % colums == 0 {
                        HStack {
                            ForEach(0 ..< colums, id:\.self) { colum in
                                let currentIndex = row * colums + colum
                                TPStyleToolViewCell(isSelected: self.selectedIndex == currentIndex)
                                .onTapGesture {
                                    self.selectedIndex = row * colums + colum
                                }
                            }
                        }
                    }
                }
            }
//            .padding(.horizontal, 14.tp.fitScreen)
        }
    }
}

struct TPStyleToolViewCell: View {
    let isSelected: Bool
    
    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .center) {
                    Image("中级沙漏")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72.tp.fitScreen, height: 72.tp.fitScreen)
                    Spacer().frame(height: 8.tp.fitScreen)
                    Text("中级沙漏")
                        .boldFont(12)
                        .foregroundColor(.g000)
                    Text("x2")
                        .font(12)
                        .foregroundColor(.g030)
                }
                .padding()
                Text("3日間")
                    .padding(.horizontal, 8.tp.fitScreen)
                    .padding(.vertical, 2.tp.fitScreen)
                    .boldFont(12)
                    .foregroundColor(.g000)
                    .background(UIColor.yFFECD1.color)
                    .clipShape(CornersRounded(cornerRadius: 8.tp.fitScreen, corners: [.bottomLeft, .topRight]))
            }
            .background(
                isSelected ? UIColor.g10F3.color: Color.clear
            )
            .cornerRadius(12.tp.fitScreen)
        }
        .frame(width: 120.tp.fitScreen,
               height: 150.tp.fitScreen)
    }
}



#Preview {
    TPStyleToolContainerView()
}

