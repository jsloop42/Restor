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
        let textView1 = UITextView(frame: .zero, textContainer: nil)
        //textView1.backgroundColor = .blue // visual debugging
        textView1.isScrollEnabled = true   // causes expanding height
        self.containerView.addSubview(textView1)
        
        let textView = EATextView(frame: .zero, textContainer: nil)
        //textView.backgroundColor = .yellow // visual debugging
        textView.isScrollEnabled = false   // causes expanding height
        textView.addBorderWithColor(color: UIColor(named: "cell-separator-bg")!, width: 1)
        self.containerView.addSubview(textView)
        
        let btn = UIButton(type: .system)
        btn.setTitle("Process", for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        //btn.addBorderWithColor(color: btn.tintColor, width: 1.0)
        self.containerView.addSubview(btn)

        // Auto Layout
        textView1.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            textView1.topAnchor.constraint(equalTo: containerView.topAnchor),
            textView1.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textView1.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.placeholder = "> Plain text string"
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: textView1.bottomAnchor, constant: -4),
            textView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: btn.leadingAnchor, constant: -4),
            textView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        let heightContraint = NSLayoutConstraint(item: textView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 100)
        heightContraint.priority = .defaultHigh
        heightContraint.isActive = true
        btn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            btn.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor, constant: -8),
            btn.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor),
            btn.heightAnchor.constraint(equalToConstant: 35)
        ])
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
