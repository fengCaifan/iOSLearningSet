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
        guard let path = Bundle.main.path(forResource: "index", ofType: "html") else { return }
        let url = URL(filePath: path)
        let request = URLRequest(url: url)
        webView.load(request)
    }
}

extension ViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "nativeCallback" {
            if let msg = message.body as? String {
                showAlert(msg)
            }
        }
    }
    
    private func showAlert(_ message: String) {
        let alertController = UIAlertController(title: "Toast", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "ok", style: .default, handler: nil)
        alertController.addAction(okAction)
        present(alertController, animated: true)
    }
}

extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("displayDate()") { any, error in
            if error != nil {
                print(error ?? "err")
            }
        }
    }
}
