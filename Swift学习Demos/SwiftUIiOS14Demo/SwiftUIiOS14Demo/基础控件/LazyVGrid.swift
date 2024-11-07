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
        LazyVGridTestItem(type: .image, url: "https://s2.loli.net/2024/11/05/B9Cs3neJ4pKjbk5.png")
    ]
    
    private var appleSymbols = ["house.circle", "person.circle", "bag.circle", "location.circle", "bookmark.circle", "gift.circle", "globe.asia.australia.fill", "lock.circle", "pencil.circle", "link.circle"]
    
    let columns: [GridItem] = [
        GridItem(.fixed(50.tp.fitScreen), spacing: 3.0),
        GridItem(.fixed(50.tp.fitScreen), spacing: 3.0),
        GridItem(.fixed(50.tp.fitScreen), spacing: 3.0)
    ]
    
    let columns2: [GridItem] = [
        GridItem(.adaptive(minimum: 30))
    ]
    
    let columns3: [GridItem] = [
        GridItem(.flexible(), spacing: 30.0),
        GridItem(.flexible(), spacing: 30.0),
        GridItem(.flexible(), spacing: 30.0)
    ]
    
    var body: some View {
        ScrollView {
//            LazyVGrid(columns: columns,
//                      spacing: 20.tp.fitScreen) {
//                ForEach(0..<10, id: \.self) { index in
//                    cell(id: index, color: Color.random())
//                        .frame(height: 50.0)
//                }
//            }
//                      .background(Color.gray)
//            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))],
                      spacing: 3.tp.fitScreen) {
                ForEach(0..<10, id: \.self) { index in
                    cell(id: index, color: Color.random())
                        .frame(width: 30, height: 50)
                }
            }
            .background(Color.gray)
//            
//            LazyVGrid(columns: columns3,
//                      spacing: 10.tp.fitScreen) {
//                ForEach(0..<10, id: \.self) { index in
//                    cell(id: index, color: Color.random())
//                        .frame(height: 50)
//                    // .frame(minWidth: 0, maxWidth: .infinity, minHeight: 50)
//                }
//            }
//                      .background(Color.gray)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum:30))], alignment: .center, spacing: 10){
                ForEach(0...10,id:\.self){ id in
                    cell(id:id,color:Color.random())
                        .frame(height: 50)
                }
            }
            
            //横向滚动
            ScrollView(.horizontal) {
                LazyHGrid(rows: [GridItem(.fixed(50)),GridItem(.fixed(50))]){
                    ForEach(0...100,id:\.self){id in
                        cell(id:id,color:Color.random())
                            .frame(width: 50)
                    }
                }
            }
            .frame(height: 240, alignment: .center)
            LazyVGrid(columns: [GridItem(.adaptive(minimum:40))], alignment: .center, spacing: 10){
                ForEach(0...100,id:\.self){ id in
                    cell(id:id,color:Color.random())
                        .frame(height: 50)
                }
            }
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum:40))], alignment: .center, spacing: 20.0, pinnedViews: [.sectionHeaders, .sectionFooters]) {
                Section(header: Text("Header").boldFont(16), footer: Text("Footer").boldFont(16)){
                    ForEach(0...20, id:\.self){ id in
                        cell(id:id,color:Color.random())
                            .frame(height: 50)
                    }
                }
//                .headerProminence(.standard) // 禁用悬停
//                .headerProminence(.increased)  悬停
            }
        }
    }
    
    func cell(id:Int,color:Color) -> some View{
        RoundedRectangle(cornerRadius: 10)
            .fill(color)
            .overlay(Text("\(id)").foregroundColor(.white))
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
