//
//  PetFoodPurchaseView.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/4/12.
//

import SwiftUI

struct FoodPurchaseModel {
    var name: String = ""
    var imageUrl: String = ""
    var count: Int = 0
    var price: Int = 0
}

struct PetFoodPurchaseView: View {
    let food = FoodPurchaseModel(name: "红色饲料", imageUrl: "红色饲料", count: 5, price: 1000)
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
                Image("购买弹窗背景2")
                    .resizable(capInsets: EdgeInsets(top: 125.0, leading: 0, bottom: 20.0, trailing: 0), resizingMode: .stretch)
                    .frame(width: 348.tp.fitScreen, height: 503.tp.fitScreen)
                    .scaledToFit()
                    .background(Color.red)
                VStack {
                    Spacer()
                        .frame(height: 28.tp.fitScreen)
                    Image(food.imageUrl)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72.tp.fitScreen, height: 72.tp.fitScreen)
                    Spacer().frame(height: 12.tp.fitScreen)
                    Text(food.name)
                        .boldFont(16)
                        .foregroundColor(.y826A66)
                        .frame(height: 24.tp.fitScreen)
                    Spacer().frame(height: 8.tp.fitScreen)
                    Text("食べものぼっくす : \(food.count)個")
                        .font(14)
                        .foregroundColor(.y826A66)
                        .frame(height: 21.tp.fitScreen)
                    Spacer().frame(height: 24.tp.fitScreen)
                    PetFoodPurchaseNumView(selectedNum: 0)
                    Spacer().frame(height: 24.tp.fitScreen)
                    HStack {
                        Text("おねだん")
                            .font(16)
                            .foregroundColor(.y826A66)
                        Spacer()
                        HStack(alignment: .center, spacing: 4.tp.fitScreen) {
                            Image("兑换积分消费履历")
                                .resizable()
                                .scaledToFit()
                            Text("\(food.price)")
                                .boldFont(16)
                                .foregroundColor(.y826A66)
                        }
                    }
                    .frame(height: 24.tp.fitScreen)
                    .padding(EdgeInsets(top: 0.0,
                                        leading: 36.tp.fitScreen,
                                        bottom: 0.0,
                                        trailing: 36.tp.fitScreen))
                    Spacer().frame(height: 46.tp.fitScreen)
                    Button(action: {
                        
                    }, label: {
                        Text("購入決定！")
                            .boldFont(16)
                            .foregroundColor(.g000)
                            .background(
                                Image("按钮29")
                                    .resizable()
                                  .frame(width: 220.tp.fitScreen, height: 48.tp.fitScreen)
                                  .scaledToFit()
                            )
                            .frame(width: 220.tp.fitScreen, height: 48.tp.fitScreen)
                            .background(Color.red)
                    })
                    Spacer()
                }
                .frame(width: 330.tp.fitScreen, height: 400.tp.fitScreen)
                .padding(EdgeInsets(top: 100.tp.fitScreen, leading: 9.tp.fitScreen, bottom: 0, trailing: 9.tp.fitScreen))
                
//                Button(action: {
//                    
//                }, label: {
//                    Image("关闭弹窗")
//                        .resizable()
//                        .scaledToFit()
//                        .frame(width: 36.tp.fitScreen, height: 36.tp.fitScreen)
//                })
//                .padding(.trailing, 5.tp.fitScreen)
//                .padding( .top, 90.tp.fitScreen)
            }
            .frame(width: 348.tp.fitScreen, height: 503.tp.fitScreen)
            .background(
                Color.red.opacity(0.3)
            )
    }
}

struct PetFoodPurchaseNumView: View {
    @State var selectedNum: Int
    var nums = [1, 5, 10]
    var body: some View {
        HStack(spacing: 24.tp.fitScreen) {
            ForEach(0..<nums.count, id:\.self) { index in
                let isSelected = selectedNum == index
                Button(action: {
                    selectedNum = index
                }, label: {
                    Text("\(nums[index])個")
                        .boldFont(16)
                        .foregroundColor(
                            isSelected ? .g200 : .y826A6680
                        )
                        .frame(width: 70.tp.fitScreen, height: 36.tp.fitScreen)
                        .background(
                            isSelected ? UIColor.y826A6680.color: Color.clear
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18.tp.fitScreen)
                                .inset(by: 0.5)
                                .stroke(UIColor.y826A6680.color)
                        )
                        .cornerRadius(18.tp.fitScreen)
                })
            }
        }
        .padding(EdgeInsets(top: 0.0,
                            leading: 36.tp.fitScreen,
                            bottom: 0.0,
                            trailing: 36.tp.fitScreen))
    }
}

#Preview {
    PetFoodPurchaseView()
}
