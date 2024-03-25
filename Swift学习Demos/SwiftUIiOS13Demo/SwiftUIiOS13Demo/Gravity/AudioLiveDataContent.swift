//
//  AudioLiveDataContent.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/1/26.
//

import SwiftUI

struct DataItem: Hashable {
    var data: String
    var desc: String
}

/// 本次直播数据统计
struct AudioLiveDataContent: View {
    private var testDatas: [DataItem] = [
        DataItem(data: "00:00:30", desc: "配信時間"),
        DataItem(data: "1", desc: "ルーム参加した人数"),
        DataItem(data: "120", desc: "最大同時接続数"),
        DataItem(data: "140", desc: "新規フォロワー数"),
        DataItem(data: "1", desc: "いいね数")
    ]
    
    private var rows: [[DataItem]] {
        stride(from: 0, to: testDatas.count, by: 2).map {
            Array(testDatas[$0..<min($0+2, testDatas.count)])
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16.0) {
            Text("本次直播数据")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.87))
            Color.white.opacity(0.06).frame(height: 1.0)
            VStack(alignment: .leading, spacing: 20.0) {
                ForEach(0..<rows.count, id: \.self) { rowIndex in
                    HStack {
                        ForEach(self.rows[rowIndex], id: \.self) { item in
                            AudioLiveDataItemView(data: item.data, desc: item.desc)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20.0)
        .padding(.vertical, 16.0)
        .background(Color.white.opacity(0.12))
        .clipShape(CornersRounded(cornerRadius: 8.0, corners: .allCorners))
    }
}

struct AudioLiveDataItemView: View {
    private let data: String
    private let desc: String
    init(data: String, desc: String) {
        self.data = data
        self.desc = desc
    }
    
    var body: some View {
        VStack {
            Text(data)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(red: 1, green: 0.85, blue: 0.64))
                .frame(width: 160.0, height: 36.0)
            Text(desc)
                .multilineTextAlignment(.center)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.87))
                .frame(width: 160.0, height: 24.0)
        }
    }
}

#Preview {
    AudioLiveDataContent()
        .background(Color.black)
}
