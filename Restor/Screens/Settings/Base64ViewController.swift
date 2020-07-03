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
    let font = App.Font.monospace14!
    let bgColor = UIColor(named: "table-view-cell-bg")
    @IBOutlet weak var inputTextLabel: UILabel!
    @IBOutlet weak var outputTextLabel: UILabel!
    @IBOutlet weak var inputTextView: UITextView!
    @IBOutlet weak var outputTextView: UITextView!
    private var encodeInpText = ""
    private var decodeInpText = ""
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.textViewDidChange(self.inputTextView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("base64 vc did load")
        self.initUI()
        self.initEvents()
    }
    
    func initUI() {
        self.navigationItem.title = "Base64"
        self.inputTextLabel.textColor = App.Color.labelTitleFg
        self.outputTextLabel.textColor = App.Color.labelTitleFg
        self.updateTextViewUI(self.inputTextView)
        self.updateTextViewUI(self.outputTextView)
    }
    
    func updateTextViewUI(_ tv: UITextView) {
        tv.font = self.font
        tv.backgroundColor = self.bgColor
        UI.addCornerRadius(tv)
        //tv.backgroundColor = .yellow // visual debugging
        tv.delegate = self
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
            self.keyboardHeight = kbHeight
            if !self.isViewDidOffset {
                //self.scrollView.contentSize.height += self.keyboardHeight
                //self.scrollView.showsVerticalScrollIndicator = false
                //self.inputTextView.isScrollEnabled = true
                self.isViewDidOffset = true
            }
        }
    }
    
    @objc func keyboardWillHide(notif: Notification) {
        if self.isViewDidOffset {
            //self.scrollView.contentSize.height -= self.keyboardHeight
            //self.scrollView.showsVerticalScrollIndicator = true
            self.isViewDidOffset = false
        }
    }
    
    @objc func menuDidChange() {
        Log.debug("menu did change")
        if self.menu.selectedSegmentIndex == 0 {
            self.decodeInpText = self.inputTextView.text
            self.inputTextView.text = self.encodeInpText
            self.inputTextLabel.text = "PLAIN TEXT"
            self.outputTextLabel.text = "ENCODED TEXT"
        } else {
            self.encodeInpText = self.inputTextView.text
            self.inputTextView.text = self.decodeInpText
            self.inputTextLabel.text = "ENCODED TEXT"
            self.outputTextLabel.text = "PLAIN TEXT"
        }
        self.outputTextView.text = ""
        self.textViewDidChange(self.inputTextView)
    }
    
    func updateTextView(_ text: String) {
        if self.menu.selectedSegmentIndex == 0 {
            self.outputTextView.text = self.utils.base64Encode(text)
        } else {
            self.outputTextView.text = self.utils.base64Decode(text)
        }
    }
    
    func textViewDidChange(_ textView: UITextView) {
        Log.debug("text view did end editing")
        self.updateTextView(textView.text ?? "")
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        Log.debug("text view did begin editing")
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        Log.debug("text view did end editing")
    }
}
