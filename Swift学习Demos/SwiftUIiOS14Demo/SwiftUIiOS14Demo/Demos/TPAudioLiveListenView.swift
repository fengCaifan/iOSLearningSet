//
//  TPAudioLiveListenView.swift
//  SwiftUIiOS14Demo
//
//  Created by fengcaifan on 2024/11/18.
//

import SwiftUI
import Kingfisher

struct TPAudioLiveListenView: View {
    var interestTags: [String] = ["恋愛·結婚", "#SKY星1","#SKY星を紡ぐ2","#SKY星を紡たち3"]
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 16.tp.fitScreen) {
                ZStack {
                    Text("试听语音房")
                        .boldFont(18)
                        .foregroundColor(UIColor.g000)
                    HStack {
                        Spacer()
                        Button {
                            print("通报按钮被点击")
                        } label: {
                            Text("通报")
                                .boldFont(16)
                                .frame(width: 36.tp.fitScreen)
                                .padding()
                                .foregroundColor(.g030)
                        }
                    }
                }
                TPAudioLiveListenNameView()
                TPVerticalFlow(hSpacing: 8.tp.fitScreen, vSpacing: 8.tp.fitScreen, items: .constant(interestTags)) { item in
                    if item == "恋愛·結婚" {
                        HStack {
                            Image("living_icon")
                            Text("\(999)")
                                .font(12)
                                .foregroundColor(UIColor.yC688.color)
                        }
                        .padding(.horizontal, 8.tp.fitScreen)
                        .background(UIColor.yFEDAA330.color)
                        .frame(height: 20.tp.fitScreen)
                        .cornerRadius(10.tp.fitScreen)
                    } else {
                        Text(item)
                            .font(14)
                            .foregroundColor(.g070)
                            .padding(.horizontal, 8.tp.fitScreen)
                            .background(UIColor.g006.color)
                            .frame(height: 20.tp.fitScreen)
                            .cornerRadius(10.tp.fitScreen)
                    }
                }
                
                TPAudioLiveListenBulletinView()
                    .frame(width: UIScreen.main.bounds.width - 48.tp.fitScreen)
                
                HStack {
                    Image("earphone")
                    ProgressView(value: 20, total: 100)
                        .progressViewStyle(TPLinearProgressViewStyle(progressColor: UIColor.y10FED.color, trackColor: UIColor.g006.color, cornerRadius: 4.tp.fitScreen))
                        .frame(height: 8.tp.fitScreen)
                    Text("30s")
                        .font(12)
                        .foregroundColor(UIColor.g070)
                }
                
                Button {
                    print("按钮被点击")
                } label: {
                    Text("使用する")
                        .boldFont(16)
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(UIColor.y10FED.color)
                        .foregroundColor(.g000)
                        .cornerRadius(28.tp.fitScreen)
                }
                .frame(height: 56.tp.fitScreen)
                Spacer().frame(height: 10.tp.fitScreen)
            }
            .padding(24.tp.fitScreen)
            .background(Color.white)
            .clipShape(CornersRounded(cornerRadius: 24.tp.fitScreen, corners: [.topLeft, .topRight]))
        }
        .edgesIgnoringSafeArea(.bottom)
    }
}

struct TPAudioLiveListenNameView: View {
    var body: some View {
        HStack(spacing: 16.tp.fitScreen) {
            if let url = URL(string: "https://s2.loli.net/2024/11/05/B9Cs3neJ4pKjbk5.png") {
                KFImage(url)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 70.tp.fitScreen, height: 70.tp.fitScreen)
            }
            
            VStack(alignment: .leading) {
                Text(" K-POPかけながらプリンを食べる🍮 K-POPかけながらプリンを食べる🍮 K-POPかけながらプリンを食べる🍮")
                    .boldFont(16)
                    .foregroundColor(UIColor.g000)
                    .lineLimit(2)
                
                HStack {
                    Text("あひなつありさひなつ")
                        .font(12)
                        .foregroundColor(UIColor.g070)
                    Spacer()
                    HStack {
                        Image("hot_icon")
                        Image("people_icon")
                        Text("\(999)")
                            .font(12)
                            .foregroundColor(UIColor.g070)
                    }
                }
            }
        }
    }
}

/// 公告
struct TPAudioLiveListenBulletinView: View {
    var body: some View {
        ScrollView {
            VStack {
                AttributedLabel(icon: "living_icon", text: "ボーニャス袋から这里是礼物名字をゲット！这里是收礼方名字さんに贈りました！\nボーニャス袋から这里是礼物名字をゲット！这里是收礼方名字さんに贈りました", textColor: UIColor.g050)
                
                if let url = URL(string: "https://s2.loli.net/2024/11/05/B9Cs3neJ4pKjbk5.png") {
                    KFImage(url)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 334.tp.fitScreen, height: 334.tp.fitScreen)
                }
            }
            .frame(width: UIScreen.main.bounds.width - 80.tp.fitScreen)
            .padding(.all, 16.tp.fitScreen)
        }
        .background(UIColor.g006.color)
        .frame(height: 120.tp.fitScreen)
        .cornerRadius(8.0)
    }
}

struct AttributedLabel: UIViewRepresentable {
    var icon: String // 图标名称
    var iconSize: CGSize = CGSizeMake(18.tp.fitScreen, 18.tp.fitScreen) // 图标大小
    var text: String // 文本内容
    var textFont: UIFont = UIFont.systemFont(ofSize: 12) // 字体
    var textColor: UIColor = .g000 // 文本颜色
    var maxLayoutWidth: CGFloat = UIScreen.main.bounds.width - 80.tp.fitScreen

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.backgroundColor = .clear
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.attributedText = makeAttributedString()
        
        // 设置最大宽度
        DispatchQueue.main.async {
            uiView.preferredMaxLayoutWidth = maxLayoutWidth
        }
    }

    private func makeAttributedString() -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        
        // 添加图片
        let imageAttachment = NSTextAttachment()
        if let iconImage = UIImage(named: icon) {
            imageAttachment.image = iconImage
            imageAttachment.bounds = CGRect(x: 0, y: -4, width: iconSize.width, height: iconSize.height)
            attributedString.append(NSAttributedString(attachment: imageAttachment))
        }
        
        // 添加文本
        let textAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: textFont
        ]
        let attributedText = NSAttributedString(string: "\(text)", attributes: textAttributes)
        attributedString.append(attributedText)
        
        return attributedString
    }
}


#Preview {
    TPAudioLiveListenView()
        .background(Color.black.opacity(0.50))
}
