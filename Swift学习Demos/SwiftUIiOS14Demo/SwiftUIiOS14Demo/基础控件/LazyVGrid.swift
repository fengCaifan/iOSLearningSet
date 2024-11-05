//
//  LazyVGrid.swift
//  SwiftUIiOS14Demo
//
//  Created by fengcaifan on 2024/11/5.
//

import SwiftUI
import Kingfisher

enum LazyVGridTestType {
    case none
    case image
    case video
}

struct LazyVGridTestItem: Identifiable {
    let id = UUID()
    var type: LazyVGridTestType
    var url: String
}

struct LazyVGridTest: View {
    var testItems: [LazyVGridTestItem] = [
        LazyVGridTestItem(type: .none, url: "https://s2.loli.net/2024/11/05/B9Cs3neJ4pKjbk5.png"),
        LazyVGridTestItem(type: .image, url: "https://s2.loli.net/2024/11/05/B9Cs3neJ4pKjbk5.png"),
        LazyVGridTestItem(type: .video, url: "https://s2.loli.net/2024/11/05/yilkvjdTCYnmBga.png"),
        LazyVGridTestItem(type: .image, url: "https://s2.loli.net/2024/11/05/B9Cs3neJ4pKjbk5.png"),
        LazyVGridTestItem(type: .none, url: "https://s2.loli.net/2024/11/05/B9Cs3neJ4pKjbk5.png"),
        LazyVGridTestItem(type: .video, url: "https://s2.loli.net/2024/11/05/yilkvjdTCYnmBga.png"),
        LazyVGridTestItem(type: .video, url: "https://s2.loli.net/2024/11/05/B9Cs3neJ4pKjbk5.png"),
        LazyVGridTestItem(type: .none, url: "https://s2.loli.net/2024/11/05/B9Cs3neJ4pKjbk5.png"),
        LazyVGridTestItem(type: .image, url: "https://s2.loli.net/2024/11/05/yilkvjdTCYnmBga.png"),
        LazyVGridTestItem(type: .video, url: "https://s2.loli.net/2024/11/05/B9Cs3neJ4pKjbk5.png"),
        LazyVGridTestItem(type: .none, url: "https://s2.loli.net/2024/11/05/B9Cs3neJ4pKjbk5.png")
    ]
    
    let columns: [GridItem] = [
        GridItem(.fixed(134.tp.fitScreen), spacing: 3.0),
        GridItem(.fixed(134.tp.fitScreen), spacing: 3.0),
        GridItem(.fixed(134.tp.fitScreen), spacing: 3.0)
    ]
    
    var body: some View {
        GeometryReader(content: { _ in
            LazyVGrid(columns: columns, spacing: 3.tp.fitScreen) {
                ForEach(testItems) { item in
                    ImagesItem(item: item)
                        .onTapGesture {
                            debugPrint("\(item.id)")
                        }
                }
            }
            .padding(.horizontal, 3.tp.fitScreen)
            .padding(.vertical, 16.tp.fitScreen)
            .background(Color.gray)
        })
    }
}

struct ImagesItem: View {
    let item: LazyVGridTestItem
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let url = URL(string: item.url) {
                KFImage(url)
                    .resizable()
                    .scaledToFit()
            }
            
            LinearGradient(gradient: Gradient(colors: [UIColor.clear.color, UIColor.g050.color]), startPoint: .top, endPoint: .bottom)
            
            switch item.type {
            case .image:
                Image("imgIcon")
                    .frame(width: 16.tp.fitScreen,
                           height: 16.tp.fitScreen)
                    .padding([.bottom, .leading], 4)
            case .video:
                Image("videoIcon")
                    .frame(width: 20.tp.fitScreen,
                           height: 20.tp.fitScreen)
                    .padding([.bottom, .leading], 4)
            case .none:
                Spacer()
            }
        }
        
    }
}

#Preview {
    LazyVGridTest()
}
