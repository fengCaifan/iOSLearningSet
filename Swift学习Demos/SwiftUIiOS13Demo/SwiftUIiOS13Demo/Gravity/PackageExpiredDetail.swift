//
//  AudioLivePackageExpiredDetail.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/3/4.
//

import SwiftUI

struct PackageExpiredModel {
    var url: String
    var name: String
    var restrictTimeDays: Int // 过期天数
    var giftCount: Int // 礼物数量
    
    var desc: String {
        return "\(name)x\(giftCount)" // 拼接
    }
    
    var times: String {
        return "\(restrictTimeDays)天后过期"
    }
}

struct PackageExpiredDetailPage: View {
    var body: some View {
        VStack(spacing: 16.0) {
            PackageExpiredDetailList()
        }
        .padding()
    }
}

/// 背包礼物过期详情
struct PackageExpiredDetailList: View {
    var list = [
        PackageExpiredModel(url: "", name: "name1", restrictTimeDays: 1, giftCount: 2),
        PackageExpiredModel(url: "", name: "name2", restrictTimeDays: 2, giftCount: 4),
        PackageExpiredModel(url: "", name: "name3", restrictTimeDays: 3, giftCount: 6),
        PackageExpiredModel(url: "", name: "name4", restrictTimeDays: 4, giftCount: 8)
    ]
    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .center) {
                    Spacer()
                    Text("过期详情")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color.black)
                    Spacer()
                }
                //.padding()
                
                Button {
                    
                } label: {
                    Image("close")
                }
            }
            ForEach(0..<list.count, id:\.self) { index in
                PackageExpiredCell(model: list[index])
            }
        }
        .padding(EdgeInsets(top: 16.0,
                            leading: 24.0,
                            bottom: 24.0,
                            trailing: 24.0))
        .background(Color.white) // .opacity(0.12)
        .clipShape(CornersRounded(cornerRadius: 8.0, corners: .allCorners))
    }
}


struct PackageExpiredCell: View {
    let model: PackageExpiredModel
    var body: some View {
        VStack {
            HStack {
                Image("star")
                    .resizable()
                    .frame(width: 40.0, height: 40.0)
                    .scaledToFit()
                Spacer()
                    .frame(width: 10.0)
                Text(model.desc)
                    .multilineTextAlignment(.leading)
                    .font(.system(size: 12))
                    .foregroundColor(Color.black)
                    .frame(height: 36.0)
                Spacer()
                Text(model.times)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 12))
                    .foregroundColor(Color.gray)
            }
            .frame(height: 72.0)
            Color.black.opacity(0.08).frame(height: 1.0)
        }
        
    }
}

#Preview {
    PackageExpiredDetailPage()
        .background(Color.black)
}
