import SwiftUI

struct TPTestUI: View {
    var body: some View {
        ZStack {
            Color.gray.opacity(0.1).edgesIgnoringSafeArea(.all)
            PricingCardView()
        }
    }
}

struct TPTestUI_Previews: PreviewProvider {
    static var previews: some View {
        TPTestUI()
    }
}
