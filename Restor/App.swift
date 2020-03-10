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
            if let ws = try self.dbService.initDefaultWorkspace() {
                AppState.workspaces.append(ws)
                AppState.selectedWorkspace = 0
                AppState.selectedProject = 0
            }
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
    
    /// Present the option picker view as a modal with the given data
    func presentOptionPicker(type: OptionPickerType, title: String, modelIndex: Int, selectedIndex: Int, data: [String], model: Any? = nil,
                             modelxs: [Any]? = [], storyboard: UIStoryboard?, navVC: UINavigationController?) {
        if let vc = storyboard?.instantiateViewController(withIdentifier: StoryboardId.optionsPickerVC.rawValue) as? OptionsPickerViewController {
            vc.pickerType = type
            vc.modelIndex = modelIndex
            vc.selectedIndex = selectedIndex
            vc.data = data
            vc.name = title
            vc.model = model
            vc.modelxs = modelxs ?? []
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
    
    func getDataForURL(_ url: URL, completion: EADataResultCallback? = nil) {
        if EAFileManager.isFileExists(at: url) {
            let fm = EAFileManager(url: url)
            fm.readToEOF(completion: completion)
        } else {
            if let cb = completion { cb(.failure(AppError.fileNotFound)) }
        }
    }
    
    func getFileName(_ url: URL) -> String {
        return url.lastPathComponent
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
enum RequestCellType: Int {
    case description
    case header
    case param
    case body
    case auth
    case option
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
    
    static var allCases: [String] {
        return ["json", "xml", "raw", "form", "multipart", "binary"]
    }
}

/// Indicates to which model the `ERequestData` belongs to
enum RequestDataType: Int {
    case header
    case param
    case form
    case multipart
}

/// Form fields under request body
enum RequestBodyFormFieldFormatType: Int {
    case text
    case file

    static var allCases: [String] {
        return ["Text", "File"]
    }
}

enum ImageType: String {
    case png
    case jpeg
    case jpg
    case heic
    case gif
    case tiff
    case webp
    case svg
}

enum AppError: Error {
    case entityGet
    case entityUpdate
    case entityDelete
    case error
    case fileOpen
    case fileRead
    case fileWrite
    case fileNotFound
}
