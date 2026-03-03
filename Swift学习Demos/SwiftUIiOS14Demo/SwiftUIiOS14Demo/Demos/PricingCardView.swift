import SwiftUI

struct PricingCardView: View {
    var body: some View {
        VStack(spacing: 20) {
            // 标题和价格部分
            VStack(spacing: 8) {
                Text("Premium")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Monthly Charge")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("$89.99")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.blue)
            }
            .padding(.top)
            
            // 功能列表
            VStack(alignment: .leading, spacing: 15) {
                FeatureRow(text: "Free Setup")
                FeatureRow(text: "Bandwidth Limit 10 GB")
                FeatureRow(text: "20 User Connection")
                FeatureRow(text: "Analytics Report")
                FeatureRow(text: "Public API Access")
                FeatureRow(text: "Plugins Intregation")
                FeatureRow(text: "Custom Content Management")
                FeatureRow(text: "Free Setup12121212121212122")
                FeatureRow(text: "Free Setup12121212121212122")
            }
            .padding(.horizontal)
            
            // 按钮部分
            VStack(spacing: 12) {
                Button(action: {
                    // 处理开始按钮点击
                }) {
                    Text("Get Started")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                Button(action: {
                    // 处理试用按钮点击
                }) {
                    Text("Start Your 30 Day Free Trial")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
        .frame(maxWidth: 300)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 10)
    }
}

struct FeatureRow: View {
    let text: String
    
    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 15))
            Spacer()
        }
    }
}

struct PricingCardView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all)
            PricingCardView()
        }
    }
} 