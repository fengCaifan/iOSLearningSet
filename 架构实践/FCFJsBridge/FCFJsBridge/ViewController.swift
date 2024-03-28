//
//  ViewController.swift
//  FCFJsBridge
//
//  Created by fengcaifan on 2024/3/26.
//

import UIKit
import WebKit

class ViewController: UIViewController {
    var webView: WKWebView!
    
    override func loadView() {
        let contentController = WKUserContentController()
        contentController.add(self, name: "nativeCallback")
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        let frame = CGRect(origin: CGPoint.zero, size: UIScreen.main.bounds.size)
        webView = WKWebView(frame: frame, configuration: config)
        webView.navigationDelegate = self
        view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        guard let url = URL(string: "https://www.baidu.com") else { return }
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

extension ViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        
    }
}

extension ViewController: WKNavigationDelegate {
    
}
