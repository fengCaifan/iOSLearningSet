//
//  TPGrowTaskItem.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/5/6.
//

import Foundation

struct TPGrowTaskList {
//    @Default<Empty<[TPGrowTaskItem]>>
    var list: [TPGrowTaskItem]
    
//    enum CodingKeys: String, CodingKey {
//        case list = "grow_list"
//    }
}

struct TPGrowTaskItem {
    var id: Int
    var name: String
    var remark: String
    var addPoint: Int
    var progress: String
    var status: Int
    var type: Int
    var ext: TPGrowTaskItemExt
}

struct TPGrowTaskItemExt {
    var giftId: String
    var giftUrl: String
}
