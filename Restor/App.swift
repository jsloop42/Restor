//
//  App.swift
//  Restor
//
//  Created by jsloop on 23/01/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class App {
    static let shared: App = App()
    var addItemPopupView: PopupView?
    var popupBottomContraints: NSLayoutConstraint?
    private var dbService = PersistenceService.shared
    
    func addSettingsBarButton() -> UIBarButtonItem {
        if #available(iOS 13.0, *) {
            return UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(self.settingsBtnDidTap(_:)))
        }
        return UIBarButtonItem(image: UIImage(), style: .plain, target: self, action: #selector(self.settingsBtnDidTap(_:)))
    }
    
    @objc func settingsBtnDidTap(_ sender: Any) {
        Log.debug("settings btn did tap")
    }
    
    func bootstrap() {
        self.initDB()
        self.initState()
    }
    
    func initDB() {
        
    }
    
    func initState() {
        do {
            let ws = try self.dbService.initDefaultWorkspace()
            AppState.workspaces.append(ws)
            AppState.selectedWorkspace = 0
            AppState.selectedProject = 0
        } catch let error {
            Log.error("Error initializing state: \(error)")
        }
    }

    func addWorkspace(_ ws: EWorkspace) {
        AppState.workspaces.append(ws)
    }
    
    func addProject(_ project: EProject) {
        // TODO
        //AppState.workspaces[AppState.selectedWorkspace].projects.append(project)
    }
    
    /// Presents an option picker view as a modal
    func presentOptionPicker(_ pickerType: OptionPickerType, storyboard: UIStoryboard?, delegate: OptionsPickerViewDelegate?, navVC: UINavigationController?) {
        if let vc = storyboard?.instantiateViewController(withIdentifier: StoryboardId.optionsPickerVC.rawValue) as? OptionsPickerViewController {
            vc.optionsDelegate = delegate
            vc.pickerType = pickerType
            navVC?.present(vc, animated: true, completion: nil)
        }
    }
    
    /// Draws a bottom border to the given text field
    func updateTextFieldWithBottomBorder(_ tf: EATextField) {
        tf.borderStyle = .none
        if #available(iOS 13.0, *) {
            tf.tintColor = .secondaryLabel
        } else {
            tf.tintColor = .lightGray
        }
    }
    
    /// Fixes appearance of a translucent background during transition
    func updateNavigationControllerBackground(_ navVC: UINavigationController?) {
        if #available(iOS 13.0, *) {
            navVC?.view.backgroundColor = UIColor.systemBackground
        } else {
            navVC?.view.backgroundColor = UIColor.white
        }
    }
    
    func updateWindowBackground(_ window: UIWindow?) {
        if #available(iOS 13.0, *) {
            window?.backgroundColor = UIColor.systemBackground
        } else {
            window?.backgroundColor = UIColor.white
        }
    }
    
    func updateViewBackground(_ view: UIView?) {
        if #available(iOS 13.0, *) {
            view?.backgroundColor = UIColor.systemBackground
        } else {
            view?.backgroundColor = UIColor.white
        }
    }
    
    // MARK: - Popup
    
    /// Display popup view over the current view controller
    /// - Parameters:
    ///   - type: The popup type
    ///   - delegate: The optional delegate
    ///   - parentView: The view of the parent view controller
    ///   - bottomView: The view to which the bottom contrainst will be added
    func viewPopup(type: PopupType, delegate: PopupViewDelegate?, parentView: UIView, bottomView: UIView, vc: UIViewController) {
        if self.addItemPopupView == nil {
            self.addItemPopupView = PopupView.initFromNib(owner: vc) as? PopupView
        }
        guard let popup = self.addItemPopupView else { return }
        popup.delegate = delegate
        popup.type = type
        popup.alpha = 0.0
        parentView.addSubview(popup)
        popup.animateSlideIn()
        popup.initConstraints(parentView: parentView, bottomView: bottomView)
        self.addItemPopupView = popup
    }
    
    // MARK: - Theme
    public struct Color {
        //public static let lightGreen = UIColor(red: 196/255, green: 223/255, blue: 168/255, alpha: 1.0)
        public static let lightGreen = UIColor(red: 120/255, green: 184/255, blue: 86/255, alpha: 1.0)
        public static let darkGreen = UIColor(red: 91/255, green: 171/255, blue: 60/255, alpha: 1.0)
        public static var requestMethodBg: UIColor = {
            if #available(iOS 13, *) {
                return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                    if UITraitCollection.userInterfaceStyle == .dark {
                        return Color.darkGreen
                    } else {
                        return Color.lightGreen
                    }
                }
            } else {
                return Color.lightGreen
            }
        }()
    }
}

enum TableCellId: String {
    case workspaceCell
    case projectCell
    case requestCell
}

enum StoryboardId: String {
    case workspaceVC
    case projectVC
    case requestListVC
    case requestVC
    case optionsPickerVC
    case optionsPickerNav
}

/// The request option elements
enum RequestHeaderInfo: Int {
    case description = 0
    case headers
    case urlParams
    case body
    case auth
    case options
}

enum Screen {
    case workspaceListing
    case projectListing
    case requestListing
    case request
    case requestEdit
    case optionListing
}

enum RequestMethod: String, Codable {
    case get = "GET"
    case head = "HEAD"
    
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    
    case delete = "DELETE"
    
    case trace = "TRACE"
    case option = "OPTIONS"
}

enum RequestBodyType: Int {
    case json
    case xml
    case raw
    case form
    case multipart
    case binary
}

/// Form fields under request body
enum RequestBodyFormFieldType: Int {
    case text
    case file

    static var allCases: [String] {
        return ["Text", "File"]
    }
}

enum AppError: Error {
    case entityGet
    case entityUpdate
    case entityDelete
}
