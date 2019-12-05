//
//  PopupView.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation
import UIKit

protocol PopupViewDelegate: class {
    func cancelDidTap(_ sender: Any)
    /// Return a flag indicating if the keyboard can be dismissed if present
    func doneDidTap(_ sender: Any) -> Bool
}

enum PopupType {
    case workspace
    case project
}

class PopupView: UIView {
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var descTextField: UITextField!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var navbarView: UIView!
    @IBOutlet weak var nameFieldValidationLabel: UILabel!
    weak var delegate: PopupViewDelegate?
    var centerY: NSLayoutYAxisAnchor?
    private static var popupView: PopupView?
    var type: PopupType = .workspace {
        didSet {
            if type == .workspace {
                self.nameTextField.placeholder = "My personal workspace"
            } else if type == .project {
                self.nameTextField.placeholder = "API Server"
            }
        }
    }
    
    static func initFromNib(owner: Any? = nil) -> UIView? {
        if let aPopupView = self.popupView {
            return aPopupView
        } else if let aPopupView = UINib(nibName: "PopupView", bundle: nil).instantiate(withOwner: owner, options: nil)[0] as? PopupView {
            aPopupView.initUIStyle()
            self.popupView = aPopupView
            return aPopupView
        }
        return nil
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layoutSubviews() {
        Log.debug("layout subviews")
        self.initUIStyle()
    }

    func initUIStyle() {
        UI.roundTopCornersWithBorder(view: self.navbarView, name: "topBorder")
        self.nameTextField.cornerRadius = 5
        self.hideValidationError()
    }
    
    func setTitle(_ text: String) {
        self.titleLabel.text = text
    }
    
    func setNamePlaceholder(_ text: String) {
        self.nameTextField.placeholder = text
    }
    
    func setDescriptionPlaceholder(_ text: String) {
        self.descTextField.placeholder = text
    }
    
    @IBAction func cancelDidTap(_ sender: Any) {
        Log.debug("Cancel did tap")
    }
    
    
    @IBAction func doneDidTap(_ sender: Any) {
        Log.debug("Done did tap")
    }
    
    func animateSlideIn(_ completion: (() -> Void)? = nil) {
        self.transform = CGAffineTransform(translationX: 0, y: self.bounds.height)
        self.alpha = 0.0
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 1.0
            self.transform = .identity
        }) { _ in
            if let cb = completion { cb() }
        }
    }

    func animateSlideOut(_ completion: (() -> Void)? = nil) {
        self.transform = .identity
        self.alpha = 1.0
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0.0
            self.transform = CGAffineTransform(translationX: 0, y: self.bounds.height)
        }) { _ in
            self.removeFromSuperview()
            if let cb = completion { cb() }
        }
    }

    func viewValidationError(_ msg: String) {
        self.nameFieldValidationLabel.text = msg
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
            self.nameTextField.addBorderWithColor(color: .red, width: 0.75)
            //self.nameTextField.addBottomBorderWithColor(color: .red, width: 0.75, name: "validationBorder")
            self.nameFieldValidationLabel.isHidden = false
            self.layoutIfNeeded()
        }
    }

    func hideValidationError() {
        self.nameFieldValidationLabel.text = ""
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
            self.nameTextField.removeBorder()
            //self.nameTextField.removeBottomBorder(name: "validationBorder")
            self.nameFieldValidationLabel.isHidden = true
            self.layoutIfNeeded()
        }
    }
}

extension PopupView: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        Log.debug("text field did begin editing")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        Log.debug("text field should return")
        if let status = self.delegate?.doneDidTap(textField) {
            if status { textField.resignFirstResponder() }
            return status
        }
        return true
    }
}
