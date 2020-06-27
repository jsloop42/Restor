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
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView(frame: .zero)
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    private var titleLabel: UILabel {
        let lbl = UILabel(frame: .zero)
        lbl.font = UIFont.systemFont(ofSize: 12)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.textColor = App.Color.labelTitleFg
        return lbl
    }
    private lazy var inpTextLabel: UILabel = {
        let lbl = self.titleLabel
        lbl.text = "PLAIN TEXT"
        return lbl
    }()
    private lazy var outTextLabel: UILabel = {
        let lbl = self.titleLabel
        lbl.text = "ENCODED TEXT"
        return lbl
    }()
    private lazy var inputTextView: UITextView = {
       let tv = UITextView(frame: .zero, textContainer: nil)
        tv.font = self.font
        tv.backgroundColor = self.bgColor
        UI.addCornerRadius(tv)
        //tv.backgroundColor = .yellow // visual debugging
        tv.delegate = self
        tv.isScrollEnabled = false   // causes expanding height
//        tv.addBorderWithColor(color: UIColor(named: "cell-separator-bg")!, width: 1)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    private lazy var outputTextView: UITextView = {
        let tv = UITextView(frame: .zero, textContainer: nil)
        tv.font = font
        tv.backgroundColor = bgColor
        UI.addCornerRadius(tv)
        tv.isEditable = false
        //tv.backgroundColor = .blue // visual debugging
        tv.isScrollEnabled = false   // causes expanding height
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    private var inpHeightConstraint: NSLayoutConstraint?
    private var outHeightConstraint: NSLayoutConstraint?
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
        self.containerView.addSubview(self.scrollView)
        self.scrollView.addSubview(self.inpTextLabel)
        self.scrollView.addSubview(self.inputTextView)
        self.scrollView.addSubview(self.outTextLabel)
        self.scrollView.addSubview(self.outputTextView)

        // Auto Layout
        NSLayoutConstraint.activate([
            self.scrollView.topAnchor.constraint(equalTo: self.containerView.topAnchor),
            self.scrollView.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.containerView.bottomAnchor)
        ])
        NSLayoutConstraint.activate([
            self.inpTextLabel.topAnchor.constraint(equalTo: self.containerView.topAnchor),
            self.inpTextLabel.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
            //self.inpTextLabel.bottomAnchor.constraint(equalTo: self.inputTextView.topAnchor, constant: -8)
        ])
        NSLayoutConstraint.activate([
            self.inputTextView.topAnchor.constraint(equalTo: self.inpTextLabel.bottomAnchor, constant: 8),
            self.inputTextView.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
            self.inputTextView.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor),
        ])
        self.inpHeightConstraint = NSLayoutConstraint(item: self.inputTextView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 200)
        self.inpHeightConstraint?.isActive = true
        NSLayoutConstraint.activate([
            self.outTextLabel.topAnchor.constraint(equalTo: self.inputTextView.bottomAnchor, constant: 12),
            self.outTextLabel.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
            //self.outTextLabel.bottomAnchor.constraint(equalTo: self.outputTextView.topAnchor, constant: -8)
        ])
        NSLayoutConstraint.activate([
            self.outputTextView.topAnchor.constraint(equalTo: self.outTextLabel.bottomAnchor, constant: 8),
            self.outputTextView.leadingAnchor.constraint(equalTo: self.containerView.leadingAnchor),
            self.outputTextView.trailingAnchor.constraint(equalTo: self.containerView.trailingAnchor)
        ])
        self.outHeightConstraint = NSLayoutConstraint(item: self.outputTextView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 200)
        self.outHeightConstraint?.isActive = true
        self.scrollView.contentSize.width = UIScreen.main.bounds.width - 48
        self.scrollView.showsHorizontalScrollIndicator = false
        self.updateUI()
    }
    
    func initEvents() {
        self.menu.addTarget(self, action: #selector(self.menuDidChange), for: .valueChanged)
        self.nc.addObserver(self, selector: #selector(self.keyboardWillShow(notif:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        self.nc.addObserver(self, selector: #selector(self.keyboardWillHide(notif:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.viewDidTap)))
    }
    
    func getHeights() -> (CGFloat, CGFloat) {
        let bounds = UIScreen.main.bounds
        let width = bounds.width - 48
        return (self.inputTextView.text.height(width: width, font: font) + 8, self.outputTextView.text.height(width: width, font: font) + 8)
    }
    
    func updateUI() {
        if self.isViewDidOffset { return }
        self.inputTextView.isScrollEnabled = false
        let h = self.getHeights()
        print("height: \(h)")
        UIView.animate(withDuration: 0.3) {
            self.scrollView.contentSize.height = max(h.0 + h.1, 400) + 44
            self.inpHeightConstraint?.isActive = false
            self.outHeightConstraint?.isActive = false
            self.inpHeightConstraint?.constant = max(h.0, 200) + 12
            self.outHeightConstraint?.constant = max(h.1, 200)
            self.outHeightConstraint?.isActive = true
            self.inpHeightConstraint?.isActive = true
        }
    }
    
    @objc func viewDidTap() {
        UI.endEditing()
    }
    
    @objc func keyboardWillShow(notif: Notification) {
        if let userInfo = notif.userInfo, let keyboardSize = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            let kbHeight = keyboardSize.cgRectValue.height
            self.keyboardHeight = kbHeight
            if !self.isViewDidOffset {
                self.scrollView.contentSize.height += self.keyboardHeight
                self.scrollView.showsVerticalScrollIndicator = false
                self.inputTextView.isScrollEnabled = true
                self.isViewDidOffset = true
            }
        }
    }
    
    @objc func keyboardWillHide(notif: Notification) {
        if self.isViewDidOffset {
            self.scrollView.contentSize.height -= self.keyboardHeight
            self.scrollView.showsVerticalScrollIndicator = true
            self.isViewDidOffset = false
            self.updateUI()
        }
    }
    
    @objc func menuDidChange() {
        Log.debug("menu did change")
        if self.menu.selectedSegmentIndex == 0 {
            self.decodeInpText = self.inputTextView.text
            self.inputTextView.text = self.encodeInpText
            self.inpTextLabel.text = "PLAIN TEXT"
            self.outTextLabel.text = "ENCODED TEXT"
        } else {
            self.encodeInpText = self.inputTextView.text
            self.inputTextView.text = self.decodeInpText
            self.inpTextLabel.text = "ENCODED TEXT"
            self.outTextLabel.text = "PLAIN TEXT"
        }
        self.outputTextView.text = ""
        self.textViewDidChange(self.inputTextView)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.updateUI()
        guard let text = textView.text, !text.isEmpty else { return }
        if self.menu.selectedSegmentIndex == 0 {
            self.outputTextView.text = self.utils.base64Encode(text)
        } else {
            self.outputTextView.text = self.utils.base64Decode(text)
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        textView.isScrollEnabled = true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        textView.isScrollEnabled = false
        self.updateUI()
    }
}
