//
//  PopupView.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

protocol PopupViewDelegate: class {
    func cancelDidTap(_ sender: Any)
    /// Return a flag indicating if the keyboard can be dismissed if present
    func doneDidTap(_ sender: Any) -> Bool
    /// Perform input text validation returning true is valid
    func validateText(_ text: String?) -> Bool
    /// Invoked when popup state changes. Eg: display validation error label
    func popupStateDidChange(isErrorMode: Bool)
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
    @IBOutlet weak var iCloudSyncSwitch: UISwitch!
    weak var delegate: PopupViewDelegate?
    var centerY: NSLayoutYAxisAnchor?
    private static weak var popupView: PopupView?
    var type: PopupType = .workspace {
        didSet {
            if type == .workspace {
                self.nameTextField.placeholder = "My personal workspace"
            } else if type == .project {
                self.nameTextField.placeholder = "API Server"
            }
        }
    }
    private var isInit = false
    private var isValidationsSuccess = true
    private var isValidated = false
    
    static func initFromNib(owner: Any? = nil) -> UIView? {
        if let aPopupView = self.popupView {
            aPopupView.resetUIState()
            return aPopupView
        } else if let aPopupView = UINib(nibName: "PopupView", bundle: nil).instantiate(withOwner: owner, options: nil)[0] as? PopupView {
            aPopupView.initUIStyle()
            aPopupView.nameTextField.delegate = aPopupView
            aPopupView.descTextField.delegate = aPopupView
            self.popupView = aPopupView
            return aPopupView
        }
        return nil
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit {
        Log.debug("popup deinit")
    }
    
    override func layoutSubviews() {
        Log.debug("layout subviews")
        self.initUIStyle()
        self.renderTheme()
    }
    
    func initUIStyle() {
        if !self.isInit {
            UI.roundTopCornersWithBorder(view: self.navbarView, name: "topBorder")
            self.renderTheme()
            self.nameTextField.cornerRadius = 5
            self.nameFieldValidationLabel.textColor = UIColor.red
            self.hideValidationError()
            self.isInit = true
        }
    }
    
    func renderTheme() {
        if #available(iOS 13.0, *) {
            self.backgroundColor = .systemBackground
            self.navbarView.backgroundColor = .quaternarySystemFill
        } else {
            self.backgroundColor = .white
            self.navbarView.backgroundColor = UIColor(red: 0.969, green: 0.969, blue: 0.969, alpha: 1.0)
        }
    }
    
    func resetUIState() {
        self.isValidated = false
        self.isValidationsSuccess = true
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
        self.delegate?.cancelDidTap(sender)
    }
    
    @IBAction func doneDidTap(_ sender: Any) {
        Log.debug("Done did tap")
        if !self.isValidated {
            self.isValidationsSuccess = self.delegate?.validateText(self.nameTextField.text) ?? false
            self.isValidated = true
        }
        if self.isValidationsSuccess {
            self.delegate?.doneDidTap(sender)
        }
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
            self.resetUIState()
            self.removeFromSuperview()
            if let cb = completion { cb() }
        }
    }

    func viewValidationError(_ msg: String) {
        Log.debug("show validation error")
        self.nameFieldValidationLabel.text = msg
        self.nameFieldValidationLabel.isHidden = false
        self.delegate?.popupStateDidChange(isErrorMode: true)
        UIView.animate(withDuration: 0.3) {
            self.layoutIfNeeded()
            self.nameTextField.addBorderWithColor(color: .red, width: 0.75)
            //self.nameTextField.addBottomBorderWithColor(color: .red, width: 0.75, name: "validationBorder")
            self.nameFieldValidationLabel.isHidden = false
            self.layoutIfNeeded()
        }
    }

    func hideValidationError() {
        Log.debug("hide validation error")
        self.nameFieldValidationLabel.text = ""
        self.nameFieldValidationLabel.isHidden = true
        self.delegate?.popupStateDidChange(isErrorMode: false)
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
        if textField == self.nameTextField, let status = self.delegate?.validateText(textField.text) {
            self.isValidationsSuccess = status
            self.isValidated = true
            if status {
                self.hideValidationError()
                self.descTextField.becomeFirstResponder()
            }
            return status
        } else if textField == self.descTextField {
            textField.resignFirstResponder()
        }
        return true
    }
}
