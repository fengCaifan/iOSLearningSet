//
//  PetFood.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/4/11.
//

import SwiftUI

enum FoodCellType {
    case realFood
    case buyPlacehold
}

struct FoodModel {
    var type: FoodCellType = .realFood
    var name: String = ""
    var imageName: String = ""
    var count: Int = 0
    var desc: String = "适用于小兔子宠物，可产出红色系宝石。每份可增加50点饱食度"
}

struct PetFoodView: View {
    
    let list = [
        FoodModel(name: "红色饲料", imageName: "红色饲料", count: 5),
        FoodModel(name: "蓝色饲料", imageName: "蓝色饲料", count: 5),
        FoodModel(name: "蓝色饲料", imageName: "蓝色饲料", count: 5),
        FoodModel(name: "红色饲料", imageName: "红色饲料", count: 5),
        FoodModel(name: "蓝色饲料", imageName: "蓝色饲料", count: 5),
        FoodModel(name: "蓝色饲料", imageName: "蓝色饲料", count: 5),
        FoodModel(type: .buyPlacehold)
    ]
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16.0) {
                ForEach(0..<list.count, id:\.self) { index in
                    PetFoodCell(food: list[index])
                        .background(Color.blue)
                }
            }
            .padding(EdgeInsets(top: 0.0,
                                leading: 19.0,
                                bottom: 0.0,
                                trailing: 19.0))
        }
    }
}

struct PetFoodCell: View {
    let food: FoodModel
    
    var body: some View {
        switch food.type {
        case .realFood:
            VStack(spacing: 12.0) {
                ZStack(alignment: .topTrailing) {
                    VStack(alignment: .center, spacing: 0.0) {
                        Spacer()
                            .frame(height: 12)
                        Image(food.imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .background(Color.blue)
                        Spacer().frame(height: 8)
                        Text(food.name + "xxxxx")
                            .fontWeight(.medium)
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                            .background(Color.blue)
                            .frame(height: 21)
                        Text("持有\(food.count)")
                            .font(.system(size: 14))
                            .foregroundColor(.black.opacity(0.7))
                            .frame(height: 18)
                            .background(Color.blue)
                        Spacer().frame(height: 12)
                    }
                    .frame(width: 90)
                    
                    Button(action: {
                        
                    }, label: {
                        Image("食物详情")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32.0, height: 18.0)
                            .padding(.trailing, -5)
                            .padding(.top, -5)
                    })
                }
                .background(
                    Image("宝箱奖励背景")
                        .resizable()
                )
                
                Button(action: {
                    
                }, label: {
                    Text("あげる")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .background(
                            Image("按钮28")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 65.0, height: 28.0)
                        )
                })
            }
            .frame(width: 90, height: 183)
            .background(Color.red)
        case .buyPlacehold:
            VStack {
                Spacer()
                    .frame(height: 5.0)
                VStack(alignment: .center, spacing: 0.0) {
                    Spacer()
                        .frame(height: 36.0)
                    Image("背包兜底商店")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 43, height: 38)
                    Spacer().frame(height: 16)
                    Button(action: {
                        
                    }, label: {
                        Text("去购买")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .frame(width: 50.0, height: 24.0)
                            .background(Color.red)
                            .cornerRadius(12.0)
                    })
                    Spacer().frame(height: 12)
                }
                .background(
                    Image("宝箱奖励背景")
                        .resizable()
                        .frame(width: 90, height: 143)
                )
                Spacer().frame(height: 40)
            }
            .frame(width: 90, height: 183)
            .background(Color.red)
        }
    }
}

#Preview {
    PetFoodView()
}
