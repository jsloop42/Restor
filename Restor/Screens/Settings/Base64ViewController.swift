//
//  Base64ViewController.swift
//  Restor
//
//  Created by jsloop on 16/06/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class Base64ViewController: UIViewController, UITextViewDelegate {
    @IBOutlet weak var menu: UISegmentedControl!
    @IBOutlet weak var containerView: UIView!
    private lazy var utils = { EAUtils.shared }()
    private let nc = NotificationCenter.default
    private var keyboardHeight: CGFloat = 0.0
    private var isViewDidOffset = false
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("base64 vc did load")
        self.initUI()
        self.initEvents()
    }
    
    func initUI() {
        //self.outputTextView.isEditable = false
        //self.inputTextView.delegate = self
        self.navigationItem.title = "Base64"
        let t0 = ">>> Researchers are at the heart of everything that scholarly and research publishers do. Accurate author and reviewer information is vital to indexing, search and discovery, publication tracking, funding and resource use attribution, and supporting peer review. ORCID serves as an information hub, enabling your authors and reviewers to reliably connect to their contributions, and to share information from their ORCID record as they interact with your publishing systems. Collecting iDs for all your authors and reviewers during the publication process -- whether for books, journals, datasets, compositions, presentations, code, or a variety of other works -- allows for information to be easily shared, ensures researchers can provide consent to share, saves researchers time and hassle, reduces the risk of errors and, critically, enables researchers to get the credit they deserve for the important work they’re doing +++ >>> Researchers are at the heart of everything that scholarly and research publishers do. Accurate author and reviewer information is vital to indexing, search and discovery, publication tracking, funding and resource use attribution, and supporting peer review. ORCID serves as an information hub, enabling your authors and reviewers to reliably connect to their contributions, and to share information from their ORCID record as they interact with your publishing systems. Collecting iDs for all your authors and reviewers during the publication process -- whether for books, journals, datasets, compositions, presentations, code, or a variety of other works -- allows for information to be easily shared, ensures researchers can provide consent to share, saves researchers time and hassle, reduces the risk of errors and, critically, enables researchers to get the credit they deserve for the important work they’re doing."
        let t1 = "Researchers are at the heart of everything that scholarly and research publishers do. Accurate author and reviewer information is vital to indexing, search and discovery, publication tracking, funding and resource use attribution, and supporting peer review. ORCID serves as an information hub, enabling your authors and reviewers to reliably connect to their contributions, and to share information from their ORCID record as they interact with your publishing systems. Collecting iDs for all your authors and reviewers during the publication process -- whether for books, journals, datasets, compositions, presentations, code, or a variety of other works -- allows for information to be easily shared, ensures researchers can provide consent to share, saves researchers time and hassle, reduces the risk of errors and, critically, enables researchers to get the credit they deserve for the important work they’re doing."
        let bounds = UIScreen.main.bounds
        let font = App.Font.monospace14!
        
        let scrollView = UIScrollView(frame: .zero)
        self.containerView.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        let width = bounds.width - (48 + scrollView.contentInset.left + scrollView.contentInset.right)
        let h0 = t0.height(width: width, font: font)
        let h1 = t1.height(width: width, font: font)
        Log.debug("width: \(width), h0: \(h0), h1: \(h1)")
        
        let textView1 = UITextView(frame: .zero, textContainer: nil)
        textView1.font = font
        textView1.backgroundColor = .blue // visual debugging
        textView1.isScrollEnabled = false   // causes expanding height
        scrollView.addSubview(textView1)
        
        let textView0 = UITextView(frame: .zero, textContainer: nil)
        textView0.font = font
        textView0.backgroundColor = .yellow // visual debugging
        textView0.isScrollEnabled = false   // causes expanding height
        textView0.addBorderWithColor(color: UIColor(named: "cell-separator-bg")!, width: 1)
        scrollView.addSubview(textView0)

        // Auto Layout
        textView1.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: self.containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor)
        ])
        
        NSLayoutConstraint.activate([
            textView0.topAnchor.constraint(equalTo: scrollView.topAnchor),
            textView0.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
            textView0.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor),
            textView0.heightAnchor.constraint(equalToConstant: h0)
        ])
        
        textView0.translatesAutoresizingMaskIntoConstraints = false
        //textView.placeholder = "> Plain text string"
        NSLayoutConstraint.activate([
            textView1.topAnchor.constraint(equalTo: textView0.bottomAnchor, constant: 4),
            textView1.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
            textView1.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor),
            //textView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            textView1.heightAnchor.constraint(equalToConstant: h1)
        ])
//        let heightContraint = NSLayoutConstraint(item: textView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 100)
//        heightContraint.priority = .defaultHigh
//        heightContraint.isActive = true
        
        textView0.text = t0
        textView1.text = t1
        scrollView.contentSize.width = UIScreen.main.bounds.width
        scrollView.contentSize.height = h0 + h1
    }
    
    func initEvents() {
        self.menu.addTarget(self, action: #selector(self.menuDidChange), for: .valueChanged)
        self.nc.addObserver(self, selector: #selector(self.keyboardWillShow(notif:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        self.nc.addObserver(self, selector: #selector(self.keyboardWillHide(notif:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.viewDidTap)))
    }
    
    @objc func viewDidTap() {
        UI.endEditing()
    }
    
    @objc func keyboardWillShow(notif: Notification) {
        if let userInfo = notif.userInfo, let keyboardSize = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let kbHeight = keyboardSize.cgRectValue.height
            keyboardHeight = kbHeight
            if !self.isViewDidOffset {
                var frame = self.view.frame
                frame.origin.y -= kbHeight
                self.view.frame = frame
                self.isViewDidOffset = true
            }
        }
    }
    
    @objc func keyboardWillHide(notif: Notification) {
        if self.isViewDidOffset {
            var frame = self.view.frame
            frame.origin.y = 0
            self.view.frame = frame
            self.isViewDidOffset = false
        }
    }
    
    
    @objc func menuDidChange() {
        Log.debug("menu did change")
//        if self.menu.selectedSegmentIndex == 0 {
//            self.inputTextView.placeholder = "> Plain text"
//        } else {
//            self.inputTextView.placeholder = "> Encoded text"
//        }
    }
    
//    func textViewDidChange(_ textView: UITextView) {
//        guard let text = textView.text, !text.isEmpty else { return }
//        if self.menu.selectedSegmentIndex == 0 {
//            self.outputTextView.text = self.utils.base64Encode(text)
//        } else {
//            self.outputTextView.text = self.utils.base64Decode(text)
//        }
//    }
}
