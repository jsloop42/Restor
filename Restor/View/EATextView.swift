//
//  EATextView.swift
//  Restor
//
//  Created by jsloop on 08/02/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

@IBDesignable
open class EATextView: UITextView {
    public let placeholderLabel: UILabel = UILabel()
    private var placeholderLabelConstraints = [NSLayoutConstraint]()
    private let nc = NotificationCenter.default
    
    static let defaultiOSPlaceholderColor: UIColor = {
        if #available(iOS 13.0, *) {
            return .systemGray3
        }
        return UIColor(red: 0.0, green: 0.0, blue: 0.0980392, alpha: 0.22)
    }()
    
    @IBInspectable
    open var placeholder: String = "" {
        didSet {
            self.placeholderLabel.text = self.placeholder
        }
    }
    
    @IBInspectable
    open var placeholderColor: UIColor = EATextView.defaultiOSPlaceholderColor {
        didSet {
            self.placeholderLabel.textColor = self.placeholderColor
        }
    }
    
    open override var font: UIFont! {
        didSet {
            if self.placeholderFont == nil {
                self.placeholderLabel.font = self.font
            }
        }
    }
    
    open var placeholderFont: UIFont? {
        didSet {
            let f = self.placeholderFont != nil ? self.placeholderFont : self.font
            self.placeholderLabel.font = f
        }
    }
    
    open override var textAlignment: NSTextAlignment {
        didSet {
            self.placeholderLabel.textAlignment = self.textAlignment
        }
    }
    
    open override var text: String! {
        didSet {
            self.textDidChange()
        }
    }
    
    open override var attributedText: NSAttributedString! {
        didSet {
            self.textDidChange()
        }
    }
    
    open override var textContainerInset: UIEdgeInsets {
        didSet {
            self.updateConstraintsForPlaceholderLabel()
        }
    }
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        self.bootstrap()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.bootstrap()
    }
    
    func bootstrap() {
        self.nc.addObserver(self, selector: #selector(self.textDidChange), name: UITextView.textDidChangeNotification, object: nil)
        self.placeholderLabel.font = self.font
        self.placeholderLabel.textColor = self.placeholderColor
        self.placeholderLabel.textAlignment = self.textAlignment
        self.placeholderLabel.text = self.placeholder
        self.placeholderLabel.numberOfLines = 0
        self.placeholderLabel.backgroundColor = .clear
        self.placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(self.placeholderLabel)
        self.updateConstraintsForPlaceholderLabel()
    }
    
    func updateConstraintsForPlaceholderLabel() {
        let hori = NSLayoutConstraint(item: self.placeholderLabel, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: self.textContainerInset.left + self.textContainer.lineFragmentPadding)
        let vert = NSLayoutConstraint(item: self.placeholderLabel, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: self.textContainerInset.top)
        let height = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .greaterThanOrEqual, toItem: self.placeholderLabel, attribute: .height, multiplier: 1, constant: self.textContainerInset.top + self.textContainerInset.bottom)
        let width = NSLayoutConstraint(item: self.placeholderLabel, attribute: .width, relatedBy: .equal, toItem: self, attribute: .width, multiplier: 1, constant: -(self.textContainerInset.left + self.textContainerInset.right + self.textContainer.lineFragmentPadding * 2.0))

        self.removeConstraints(self.placeholderLabelConstraints)
        let xs = [hori, vert, height, width]
        self.addConstraints(xs)
        self.placeholderLabelConstraints = xs
    }
    
    @objc func textDidChange() {
        self.placeholderLabel.isHidden = !self.text.isEmpty
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        self.placeholderLabel.preferredMaxLayoutWidth = self.textContainer.size.width - self.textContainer.lineFragmentPadding * 2.0
    }
}
