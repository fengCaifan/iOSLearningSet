//
//  TPGrowTaskListView.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/5/6.
//

import SwiftUI

struct TaskTestView: View {
    var body: some View {
        ScrollView {
            TPGrowTaskListView()
        }
    }
}

struct TPGrowTaskListView: View {
    var body: some View {
        VStack(spacing: 16.tp.fitScreen) {
            ZStack {
                Image("point_finsh_task_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 169.tp.fitScreen)
                VStack(spacing: 0.0) {
                    TPGrowTaskSectionHeader()
                    TPGrowTaskItemCell3()
                }
            }
            .clipShape(CornersRounded(cornerRadius: 16.tp.fitScreen, corners: .allCorners))
            .shadow(color: UIColor.g008.color, radius: 12.tp.fitScreen)
            
            TPGrowTaskView(backgroundColor: Color.white,
                           cornerRadius: 16.tp.fitScreen,
                           shadowColor: UIColor.g008.color,
                           shadowRadius: 12.tp.fitScreen) {
                TPGrowTaskSectionHeader()
                TPGrowTaskItemCell1()
                TPGrowTaskItemCell1()
            }
            
            TPGrowTaskView(backgroundColor: Color.white,
                           cornerRadius: 16.tp.fitScreen,
                           shadowColor: UIColor.g008.color,
                           shadowRadius: 12.tp.fitScreen) {
                TPGrowTaskSectionHeader()
                TPGrowTaskItemCell2()
                TPGrowTaskItemCell1()
                TPGrowTaskItemCell1()
            }
            
            TPGrowTaskView(backgroundColor: Color.white,
                           cornerRadius: 16.tp.fitScreen,
                           shadowColor: UIColor.g008.color,
                           shadowRadius: 12.tp.fitScreen) {
                TPGrowTaskSectionHeader()
                TPGrowTaskItemCell1()
                TPGrowTaskItemCell1()
            }
            
            TPGrowTaskView(backgroundColor: Color.white,
                           cornerRadius: 16.tp.fitScreen,
                           shadowColor: UIColor.g008.color,
                           shadowRadius: 12.tp.fitScreen) {
                TPGrowTaskSectionHeader()
                TPGrowTaskItemCell1()
            }
        }
        .padding(.all, 16.tp.fitScreen)
        .background(UIColor.g10F3F3.color)
    }
}

struct TPGrowTaskView<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat

    init(backgroundColor: Color,
         cornerRadius: CGFloat,
         shadowColor: Color,
         shadowRadius: CGFloat,
         @ViewBuilder content: () -> Content) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadowColor = shadowColor
        self.shadowRadius = shadowRadius
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0.0) {
            content
        }
        .background(backgroundColor)
        .clipShape(CornersRounded(cornerRadius: cornerRadius, corners: .allCorners)) // 假设CornersRounded是你自定义的ViewModifier或Shape
        .shadow(color: shadowColor, radius: shadowRadius)
    }
}

struct TPGrowTaskSectionHeader: View {
    var body: some View {
        HStack(spacing: 4.tp.fitScreen) {
            Text("BigTitle")
                .boldFont(18)
                .foregroundColor(.g000)
            Text("subTitle")
                .boldFont(12)
                .foregroundColor(.g050)
            Spacer()
        }
        .padding(EdgeInsets(top: 16.tp.fitScreen, leading: 16.tp.fitScreen, bottom: 12.tp.fitScreen, trailing: 16.tp.fitScreen))
        .frame(width: kScreenWidth - 32.tp.fitScreen, height: 55.tp.fitScreen)
    }
}

struct TPGrowTaskItemCell1: View {
    var body: some View {
        HStack(spacing: 12.tp.fitScreen) {
            Image("grow_task_comment")
                .resizable()
                .scaledToFill()
                .frame(width: 66.tp.fitScreen, height: 66.tp.fitScreen)
            VStack(alignment: .leading, spacing: 4.tp.fitScreen) {
                Text("itemTitle")
                    .mediumFont(14)
                    .foregroundColor(.g087)
                Text("1/10回")
                    .font(12)
                    .foregroundColor(.g030)
                HStack(alignment: .center, spacing: 1.0) {
                    Image("pet_integral")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16.tp.fitScreen, height: 16.tp.fitScreen)
                    Text("3000")
                        .boldFont(14)
                        .foregroundColor(.g070)
                }
            }
            Spacer()
            
            TPGrowTaskButton(state: .doTask)
                .padding(.trailing, 24.tp.fitScreen)
        }
        .padding(.horizontal, 16.tp.fitScreen)
        .frame(width: kScreenWidth - 32.tp.fitScreen,
               height: 102.tp.fitScreen)
    }
}

struct TPGrowTaskItemCell2: View {
    var body: some View {
        VStack(spacing: 0.0) {
            TPGrowTaskItemCell1()
            HStack {
                Text("#话题话题话题话题话题话题")
                    .font(14)
                    .foregroundColor(.g050)
                Spacer()
                    
                Button(action: {
                    
                }, label: {
                    Image("积分兑换箭头")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 7.tp.fitScreen, height: 12.tp.fitScreen)
                })
            }
            .padding(.horizontal, 12.tp.fitScreen)
            .frame(width: kScreenWidth - 72.tp.fitScreen,
                   height: 45.tp.fitScreen)
            .background(Color.yellow)
            .clipShape(CornersRounded(cornerRadius: 12.tp.fitScreen, corners: .allCorners))
        }
        .frame(height: 157.tp.fitScreen)
    }
}

struct TPGrowTaskItemCell3: View {
    var body: some View {
        HStack(spacing: 12.tp.fitScreen) {
            Image("grow_task_award_portraitFrame")
                .resizable()
                .scaledToFill()
                .frame(width: 66.tp.fitScreen, height: 66.tp.fitScreen)
            VStack(alignment: .leading, spacing: 4.tp.fitScreen) {
                Text("itemTitle")
                    .mediumFont(14)
                    .foregroundColor(.g087)
                Text("1/10回")
                    .font(12)
                    .foregroundColor(.g030)
                HStack(alignment: .center, spacing: 1.0) {
                    ForEach(0..<10, id:\.self) { index in
                        if index < 3 {
                            UIColor.yFEDAA3.color
                                .frame(width: 16.tp.fitScreen, height: 10.tp.fitScreen)
                                .cornerRadius(2.0)
                        } else {
                            UIColor.g005.color
                                .frame(width: 16.tp.fitScreen, height: 10.tp.fitScreen)
                                .cornerRadius(2.0)
                        }
                    }
                }
            }
            TPGrowTaskButton(state: .getTask)
                .padding(.trailing, 8.tp.fitScreen)
        }
        .padding(.horizontal, 16.tp.fitScreen)
        .frame(width: kScreenWidth - 32.tp.fitScreen,
               height: 102.tp.fitScreen)
    }
}

struct TPGrowTaskButton: View {
    @State var state: TPGrowTaskState = .noBegin
    var body: some View {
        if case .finished = state {
            Image("grow_task_finished")
                .resizable()
                .scaledToFill()
                .frame(width: 66.tp.fitScreen, height: 66.tp.fitScreen)
        } else {
            Button(action: {
                
            }, label: {
                let title = state.title
                
                Text(state.title)
                    .frame(width: 78.tp.fitScreen, height: 28.tp.fitScreen)
                    .boldFont(12)
                    .foregroundColor(state.lightTitleColor)
                    .background(state.lightBgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14.tp.fitScreen)
                            .inset(by: 0.5)
                            .stroke(state.lightBorderColor)
                    )
                    .cornerRadius(14.tp.fitScreen)
            })
        }
    }
}

enum TPGrowTaskState {
    case noBegin // 未开始
    case getTask // 可以领取
    case doTask // 做任务
    case getAward // 领取奖励
    case finished // 已完成
    
    var title: String {
        switch self {
        case .noBegin:
            "未完成"
        case .getTask:
            "领取任务"
        case .doTask:
            "チャレンジ"
        case .getAward:
            "领取奖励"
        case .finished:
            ""
        }
    }
    
    var lightBgColor: Color {
        switch self {
        case .noBegin:
            return UIColor.g003.color
        case .getTask:
            return UIColor.yFEDAA3.color
        case .doTask:
            return UIColor.clear.color
        case .getAward:
            return UIColor.g000.color
        case .finished:
            return UIColor.clear.color
        }
    }
    
    var lightBorderColor: Color {
        switch self {
        case .noBegin,.getTask, .getAward, .finished:
            return UIColor.clear.color
        case .doTask:
            return UIColor.g000.color
        }
    }
    
    var lightTitleColor: Color {
        switch self {
        case .noBegin:
            return UIColor.g016.color
        case .getTask:
            return UIColor.g000.color
        case .doTask:
            return UIColor.g000.color
        case .getAward:
            return UIColor.yFEDAA3.color
        case .finished:
            return UIColor.clear.color
        }
    }
}


#Preview {
    TaskTestView()
}
