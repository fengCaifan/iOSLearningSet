//
//  PetStarToIntegralView.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/4/15.
//

import SwiftUI

struct PetStarToIntegralItem {
    var starCount: Int
    var integralCount: Int
}

struct PetStarToIntegralView: View {
    let list = [PetStarToIntegralItem(starCount: 3, integralCount: 750),
                PetStarToIntegralItem(starCount: 25, integralCount: 7500),
                PetStarToIntegralItem(starCount: 125, integralCount: 37500),
                PetStarToIntegralItem(starCount: 250, integralCount: 75000),
                PetStarToIntegralItem(starCount: 1250, integralCount: 375000)]
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image("普通弹窗背景")
                .resizable(capInsets: EdgeInsets(top: 44.tp.fitScreen, leading: 45.tp.fitScreen, bottom: 44.tp.fitScreen, trailing: 45.tp.fitScreen), resizingMode: .stretch)
                .frame(width: 348.tp.fitScreen, height: 426.tp.fitScreen)
                .scaledToFit()
            VStack(spacing: 0.0) {
                Spacer().frame(height: 31.tp.fitScreen)
                Text("ポイント購入")
                    .boldFont(18)
                    .foregroundColor(.y826A66)
                    .frame(height: 27.tp.fitScreen)
                Spacer().frame(height: 7.tp.fitScreen)
                Text("星粒でポイントを購入できるよ")
                    .font(14)
                    .foregroundColor(.y826A66)
                    .frame(height: 21.tp.fitScreen)
                ForEach(0..<list.count, id:\.self) { index in
                    PetStarToIntegralViewCell(item: list[index], isLastItem: index == list.count - 1)
                }
            }
            .frame(width: 330.tp.fitScreen, height: 406.tp.fitScreen)
            .padding(.all, 10.tp.fitScreen)
            
            Button(action: {
                
            }, label: {
                Image("关闭弹窗")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36.tp.fitScreen, height: 36.tp.fitScreen)
            })
            .padding(.trailing, -5.tp.fitScreen)
            .padding( .top, -5.tp.fitScreen)
        }
        .frame(width: 348.tp.fitScreen, height: 430.tp.fitScreen)
    }
}

struct PetStarToIntegralViewCell: View {
    let item: PetStarToIntegralItem
    let isLastItem: Bool
    var body: some View {
        VStack(spacing: 0.0) {
            Spacer().frame(height: 16.tp.fitScreen)
            HStack(content: {
                HStack(spacing: 4.tp.fitScreen) {
                    Image("pet_star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16.tp.fitScreen, height: 16.tp.fitScreen)
                    Text("\(item.starCount)")
                        .boldFont(16)
                        .foregroundColor(.y826A66)
                    Spacer()
                }
                .frame(width: 87.tp.fitScreen)
                Spacer()
                Image("积分兑换箭头")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20.tp.fitScreen, height: 20.tp.fitScreen)
                HStack(spacing: 4.tp.fitScreen) {
                    Image("pet_integral")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16.tp.fitScreen, height: 16.tp.fitScreen)
                    Text("\(item.integralCount)")
                        .boldFont(16)
                        .foregroundColor(.y826A66)
                    Spacer()
                }
                .frame(width: 114.tp.fitScreen)
                Spacer()
                Button(action: {
                    
                }, label: {
                    Text("買う")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .background(
                            Image("按钮28")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 54.0, height: 28.0)
                        )
                })
                .frame(width: 54.tp.fitScreen, height: 28.tp.fitScreen)
            })
            .frame(height: 28.tp.fitScreen)
            
            Spacer().frame(height: 16.tp.fitScreen)
            if !isLastItem {
                Image("商店履历分割线")
                    .resizable()
                    .scaledToFill()
                    .frame(width: .infinity, height: 4.tp.fitScreen)
            }
        }
        .padding(EdgeInsets(top: 0, leading: 16.tp.fitScreen, bottom: 0, trailing: 16.tp.fitScreen))
        .frame(width: 330.tp.fitScreen, height: 64.tp.fitScreen)
    }
}


#Preview {
    PetStarToIntegralView()
}
