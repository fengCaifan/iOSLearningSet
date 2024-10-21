//
//  ListDemo.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/10/17.
//

import SwiftUI

struct ListItem: Identifiable {
    var id = UUID()
    var name: String
    var iconName: String
}

struct ListDemo: View {
    @State var lists = [
        ListItem(name: "111111111", iconName: "star.fill"),
        ListItem(name: "2222222", iconName: "heart"),
        ListItem(name: "3333333", iconName: "trash"),
        ListItem(name: "4444444", iconName: "plus.circle"),
        ListItem(name: "5555555", iconName: "cart"),
        ListItem(name: "6666666", iconName: "person"),
    ]
    
    var body: some View {
        List {
            ForEach(lists) { item in
                HStack {
                    ListDemoCell(item: item)
                        .listRowBackground(UIColor.g020.color)
                }
            }
            .onDelete(perform: { indexSet in
                self.lists.remove(atOffsets: indexSet)
            })
            .onMove(perform: { indices, newOffset in
                self.lists.move(fromOffsets: indices, toOffset: newOffset)
            })
        }
        .listStyle(PlainListStyle())
        
//        List(lists) { item in
//            ListDemoCell(item: item)
////            .listRowInsets(EdgeInsets()) // 设置没过cell 内容内边距
//            .listRowBackground(UIColor.g020.color) // 设置每个cell的背景色
////            .listRowSeparator(.hidden)
//            // iOS 13和iOS 14没有 ListRowSeparator，如果要隐藏分隔线，需要
//        }
    }
}

struct ListDemoCell: View {
    let item: ListItem
    var body: some View {
        HStack {
            Image(systemName: item.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 40.tp.fitScreen, height: 40.tp.fitScreen)
                .cornerRadius(5)
            Text(item.name)
                .padding()
        }
    }
}

#Preview {
    ListDemo()
        .background(Color.red)
}
