//
//  PetFoodDetail.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/4/11.
//

import SwiftUI

struct PetFoodDetail: View {
    var body: some View {
        let food = FoodModel(name: "红色饲料", imageName: "红色饲料", count: 5)
        ZStack(alignment: .topTrailing) {
            HStack(alignment: .center) {
                Spacer().frame(width: 16.0)
                Image(food.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .background(Color.blue)
                Spacer().frame(width: 12.0)
                VStack(alignment: .leading, spacing: 4.0) {
                    Text(food.name + "xxxxx")
                        .fontWeight(.medium)
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                        .frame(height: 24)
                    Text("持有\(food.count)")
                        .font(.system(size: 12))
                        .foregroundColor(.black.opacity(0.7))
                        .frame(height: 18)
                    Text(food.desc)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .frame(height: 118.0)
            
            Button(action: {
                
            }, label: {
                Text("買う")
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .background(
                        Image("按钮28")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 65.0, height: 28.0)
                    )
                    .frame(width: 65.0, height: 28.0)
            })
            .padding(.trailing, 16)
            .padding( .top, 16)
        }
        .frame(maxWidth: .infinity)
        .background(
            Image("饲料背景")
                .resizable()
                .background(Color.red)
        )
        .padding(EdgeInsets(top: 30.0,
                            leading: 28.0,
                            bottom: 30.0,
                            trailing: 28.0))
    }
}

#Preview {
    PetFoodDetail()
}
