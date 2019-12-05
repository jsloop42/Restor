//
//  ViewController.swift
//  Restor
//
//  Created by jsloop on 02/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import UIKit

class WorkspaceViewController: UIViewController {
    @IBOutlet weak var toolbar: UIToolbar!
    private var addItemPopupView: PopupView?
    private var popupBottomContraints: NSLayoutConstraint?
    private var isKeyboardActive = false
    private var keyboardHeight: CGFloat = 0.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initUI()
    }

    func initUI() {
        
    }
    
    @IBAction func addBtnDidTap(_ sender: Any) {
        Log.debug("add btn did tap")
        self.viewAlert(vc: self, storyboard: self.storyboard!)
    }
    
    func viewAlert(vc: UIViewController, storyboard: UIStoryboard, message: String? = nil, title: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "New Workspace", style: .default, handler: { action in
            Log.debug("new workspace did tap")
            self.viewPopup(type: .workspace)
        }))
        alert.modalPresentationStyle = .popover
        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.sourceView = vc.view
            popoverPresentationController.sourceRect = vc.view.bounds
            popoverPresentationController.permittedArrowDirections = []
        }
        vc.present(alert, animated: true, completion: nil)
    }
    
    func updateConstraints() {
        let bottom: CGFloat = 0
        if let popup = self.addItemPopupView {
            self.popupBottomContraints?.isActive = false
            if self.isKeyboardActive {
                self.popupBottomContraints = popup.bottomAnchor.constraint(equalTo: self.toolbar.topAnchor,
                                                                           constant: -self.keyboardHeight+bottom)
            } else {
                self.popupBottomContraints = popup.bottomAnchor.constraint(equalTo: self.toolbar.topAnchor, constant: bottom)
            }
            self.popupBottomContraints?.isActive = true
        }
    }
    
    func viewPopup(type: PopupType) {
        if self.addItemPopupView == nil, let popup = PopupView.initFromNib(owner: self) as? PopupView {
            popup.delegate = self
            popup.nameTextField.delegate = popup
            popup.type = type
            popup.alpha = 0.0
            self.view.addSubview(popup)
            popup.animateSlideIn()
            if type == .workspace {
                popup.setTitle("New Workspace")
                popup.setNamePlaceholder("My personal workspace")
                popup.setDescriptionPlaceholder("API tests for my personal projects")
            } else if type == .project {
                popup.setTitle("New Project")
                popup.setNamePlaceholder("API server")
                popup.setDescriptionPlaceholder("APIs for my app server")
            }
            popup.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                popup.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 0),
                popup.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: 0),
                popup.heightAnchor.constraint(equalToConstant: 207)
            ])
            self.addItemPopupView = popup
            self.updateConstraints()
        }
    }
    
    func createNewWorkspace() {
        let ws = Workspace(name: "", desc: "")
    }
}

extension WorkspaceViewController: PopupViewDelegate {
    func cancelDidTap(_ sender: Any) {
        Log.debug("cancel did tap")
        if let popup = self.addItemPopupView {
            popup.animateSlideOut {
                popup.nameTextField.text = ""
                popup.removeFromSuperview()
                self.addItemPopupView = nil
            }
        }
    }

    func doneDidTap(_ sender: Any) -> Bool {
        Log.debug("done did tap")
        if let popup = self.addItemPopupView {
            if let name = popup.nameTextField.text {
                if name.isEmpty {
                    popup.viewValidationError("Please enter a name")
                    return false
                }
                if name.trimmingCharacters(in: .whitespaces) == "" {
                    popup.viewValidationError("Please enter a valid name")
                    return false
                }
                popup.animateSlideOut {
                    popup.nameTextField.text = ""
                    popup.removeFromSuperview()
                    self.addItemPopupView = nil
                }
            } else {
                popup.viewValidationError("Please enter a valid name")
                return false
            }
        }
        return true
    }
}
