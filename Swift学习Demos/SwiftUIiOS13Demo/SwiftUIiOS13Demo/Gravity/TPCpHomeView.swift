//
//  TPCpHomeView.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/9/26.
//

import SwiftUI

struct TPCpHomeView: View {
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16.tp.fitScreen) {
                Button {
                    print("点击了戒指")
                } label: {
                    Image("ring01")
                        .frame(width: 160.tp.fitScreen, height: 120.tp.fitScreen)
                }
                TPCpDetailView()
                
                ScrollView {
                    TPCpLevelView()
                    TPCpWearingRingView()
                    TPCpRingsView()
                }
            }
            .padding(.horizontal, 24.tp.fitScreen)
            .background(Color.pink)
        }
    }
}

struct TPCpDetailView: View {
    var body: some View {
        ZStack {
            VStack(spacing: 0.0) {
                Spacer().frame(height: 45.tp.fitScreen)
                Color.white
                    .clipShape(CornersRounded(cornerRadius: 16.tp.fitScreen, corners: .allCorners))
            }
            VStack(spacing: 0.0) {
                HStack {
                    Button {
                        print("点击了左侧头像")
                    } label: {
                        Image("girlAvtar01")
                            .frame(width: 90.tp.fitScreen, height: 90.tp.fitScreen)
                    }
                    .padding(.trailing, -20.tp.fitScreen)
                    Button {
                        print("点击了右侧头像")
                    } label: {
                        Image("boyAvatar01")
                            .frame(width: 90.tp.fitScreen, height: 90.tp.fitScreen)
                    }
                    .padding(.leading, -20.tp.fitScreen)
                }
                Spacer().frame(height: 16.tp.fitScreen)
                Text("已结为CP")
                    .font(14)
                    .foregroundColor(.g050)
                Spacer().frame(height: 5.tp.fitScreen)
                HStack(spacing: 0.0) {
                    Text("2430")
                        .boldFont(20)
                        .foregroundColor(.g087)
                    Text("日")
                        .font(16)
                        .foregroundColor(.g070)
                }
                Spacer().frame(height: 16.tp.fitScreen)
                
                HStack(spacing: 0.0) {
                    Text("親密度：")
                        .font(16)
                        .foregroundColor(.p8971EB)
                    Text("45000009")
                        .boldFont(16)
                        .foregroundColor(.p8971EB)
                }
                .padding(.horizontal, 24.tp.fitScreen)
                .frame(height: 36.tp.fitScreen)
                .background(UIColor.p8971EB10.color)
                .clipShape(CornersRounded(cornerRadius: 8.tp.fitScreen, corners: .allCorners))
                Spacer().frame(height: 24.tp.fitScreen)
            }
        }
        .frame(height: 238.tp.fitScreen)
    }
}

struct TPCpLevelView: View {
    @State private var progressValue: CGFloat = 0.5

    var body: some View {
        VStack(spacing: 10.0) {
            HStack {
                Text("Lv.1")
                    .boldFont(18)
                    .foregroundColor(.g087)
                Spacer()
                Button {
                    debugPrint("点击了cp权益")
                } label: {
                    Text("CP权益")
                        .frame(width: 72.tp.fitScreen, height: 28.tp.fitScreen)
                        .boldFont(12)
                        .foregroundColor(.g000)
                        .background(UIColor.g006.color)
                        .cornerRadius(14.tp.fitScreen)
                }
            }
            HStack(spacing: 0.0) {
                Text("到下一级还差")
                    .font(14)
                    .foregroundColor(.g087)
                Text("xxx")
                    .mediumFont(14)
                    .foregroundColor(.g087)
                Text("亲密值")
                    .font(14)
                    .foregroundColor(.g087)
                Spacer()
            }
            ProgressBar(value: $progressValue,
                        bgColor: UIColor.p8971EB10.color,
                        tintColor: UIColor.p8971EB.color,
                        cornerRadius: 4.0)
            .frame(height: 8.0)
            HStack {
                Text("LV1")
                    .font(14)
                    .foregroundColor(.g087)
                Spacer()
                Text("LV2")
                    .font(14)
                    .foregroundColor(.g087)
            }
        }
        .frame(height: 138.tp.fitScreen)
        .padding(.horizontal, 16.tp.fitScreen)
        .background(Color.white)
        .clipShape(CornersRounded(cornerRadius: 16.tp.fitScreen, corners: .allCorners))
    }
}

struct TPCpWearingRingView: View {
    var body: some View {
        HStack {
            Image("ring01")
                .resizable()
                .frame(width: 64.tp.fitScreen, height: 48.tp.fitScreen)
            Text("絆の証：星星皇冠")
                .font(16)
                .foregroundColor(.g000)
            Spacer()
            Button {
                debugPrint("点击了更换")
            } label: {
                Text("更换")
                    .frame(width: 60.tp.fitScreen, height: 28.tp.fitScreen)
                    .boldFont(12)
                    .foregroundColor(.g000)
                    .background(UIColor.g006.color)
                    .cornerRadius(14.tp.fitScreen)
            }
        }
        .frame(height: 88.tp.fitScreen)
        .padding(.horizontal, 16.tp.fitScreen)
        .background(Color.white)
        .clipShape(CornersRounded(cornerRadius: 16.tp.fitScreen, corners: .allCorners))
    }
}

struct TPCpRingsView: View {
    let colums: Int = 4
    let allCount: Int = 14
    var body: some View {
        VStack(spacing: 20.tp.fitScreen) {
            HStack {
                Text("所有戒指絆の証")
                    .mediumFont(16)
                    .foregroundColor(.g000)
                Spacer()
            }
            VStack(alignment: .leading,
                   spacing: 24.tp.fitScreen) {
                ForEach(0..<allCount, id:\.self) { index in
                    let row = index / colums
                    if index % colums == 0 {
                        HStack(spacing: 22.tp.fitScreen) {
                            ForEach(0 ..< colums, id:\.self) { colum in
                                let currentIndex = row * colums + colum
                                if currentIndex < allCount {
                                    Image("ring01")
                                        .resizable()
                                        .frame(width: 64.tp.fitScreen, height: 48.tp.fitScreen)
                                        .onTapGesture {
                                            debugPrint("点击了戒指001")
                                        }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16.tp.fitScreen)
        .padding(.vertical, 20.tp.fitScreen)
        .background(Color.white)
        .clipShape(CornersRounded(cornerRadius: 16.tp.fitScreen, corners: .allCorners))
    }
}

#Preview {
    TPCpHomeView()
}
