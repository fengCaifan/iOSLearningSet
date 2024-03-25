//
//  AudioLiveHomeOwnerEndPage.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/1/26.
//

import SwiftUI

struct AudioLiveHomeOwnerEndPage: View {
    var body: some View {
        VStack(spacing: 16.0) {
            Spacer()
                .frame(height: 100.0)
            AudioLiveDataContent()
            AudioLiveProcessContent()
            Spacer()
        }
        .padding(.horizontal, 16.0)
    }
}




#Preview {
    AudioLiveHomeOwnerEndPage()
        .background(Color.black)
}
