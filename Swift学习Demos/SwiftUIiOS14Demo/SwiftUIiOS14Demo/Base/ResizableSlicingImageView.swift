//
//  ResizableSlicingImageView.swift
//  SwiftUIiOS13Demo
//
//  Created by fengcaifan on 2024/4/12.
//

import Foundation
import UIKit
import SwiftUI

struct ResizableImageView: UIViewRepresentable {
    var imageName: String
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit // 或者任何适合您需求的contentMode
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = UIImage(named: imageName)
    }
}
