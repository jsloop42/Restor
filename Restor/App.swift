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
    private let localdb = CoreDataService.shared
    private var rescheduler = EARescheduler(interval: 0.3, repeats: false, type: .everyFn)
    /// Diff ids for `EAReschedulerFn`s
    private let fnIdReq = "request-fn"
    private let fnIdReqMethodIndex = "request-method-index-fn"
    private let fnIdReqMethod = "request-method-fn"
    private let fnIdAnyReqMethod = "any-request-method-fn"
    private let fnIdReqURL = "request-url-fn"
    private let fnIdReqName = "request-name-fn"
    private let fnIdReqDesc = "request-description-fn"
    private let fnIdReqMeta = "request-meta-fn"
    private let fnIdReqHeader = "request-header-fn"
    private let fnIdReqParam = "request-param-fn"
    private let fnIdReqBody = "request-body-fn"
    private let fnIdAnyReqBodyForm = "any-request-body-form-fn"
    private let fnIdReqBodyForm = "request-body-form-fn"
    private let fnIdReqBodyFormAttachment = "request-body-form-attachment-fn"
    private let fnIdReqData = "request-data-fn"
    private let fnIdReqFile =  "request-file-fn"
    private let fnIdReqImage = "request-image-fn"
    
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
    
    // MARK: - Request change
    
    /// Checks if the request changed.
    func didRequestChange(_ x: ERequest, request: [String: Any]) -> Bool {
        //if self.didRequestURLChange(x.url ?? "", request: request) { return true }
        //if self.didRequestMetaChange(name: x.name ?? "", desc: x.desc ?? "", request: request) { return true }
        if self.didRequestMethodIndexChange(x.selectedMethodIndex, y: request) { return true }
        if let methods = x.methods?.allObjects as? [ERequestMethodData] {
            if self.didAnyRequestMethodChange(methods, request: request) { return true }
        }
        if self.didRequestBodyChange(x.body, request: request) { return true }
        if let headers = x.headers?.allObjects as? [ERequestData] {
            if self.didAnyRequestHeaderChange(headers, request: request) { return true }
        } else {
            if let headers = request["headers"] as? [[String: Any]], headers.count > 0 { return true }
        }
        if let params = x.params?.allObjects as? [ERequestData] {
            if self.didAnyRequestParamChange(params, request: request) { return true }
        } else {
            if let params = request["params"] as? [[String: Any]], params.count > 0 { return true }
        }
        return false
    }
    
    func didRequestMethodIndexChange(_ x: Int32, y: [String: Any]) -> Bool {
        if let index = y["selectedMethodIndex"] as? Int32 { return x != index }
        return false
    }
    
    func didRequestMethodChange(_ x: ERequestMethodData, y: [String: Any]) -> Bool {
        if x.created != y["created"] as? Int64 ||
            x.index != y["index"] as? Int64 ||
            x.isCustom != y["isCustom"] as? Bool ||
            x.name != y["name"] as? String {
            return true
        }
        return false
    }
    
    func didAnyRequestMethodChange(_ xs: [ERequestMethodData], request: [String: Any]) -> Bool {
        let xsa = xs.filter { x -> Bool in x.isCustom }
        let xsb = (request["methods"] as? [[String: Any]])?.filter({ hm -> Bool in
            if let isCustom = hm["isCustom"] as? Bool { return isCustom }
            return false
        })
        let len = xsa.count
        if xsb == nil && len > 0 { return true }
        if xsb != nil && xsb!.count != len { return true }
        if xsb != nil {
            for i in 0..<len {
                if self.didRequestMethodChange(xsa[i], y: xsb![i]) { return true }
            }
        }
        return false
    }
    
    /// Checks if the request URL changed.
    func didRequestURLChange(_ x: String, request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.rescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqURL, block: { (x: Any?) -> Bool in
            return self.didRequestURLChangeImp(x as! String, request: request)
        }, callback: { status in
            callback(status)
        }, arg: x))
    }
    
    func didRequestURLChangeImp(_ x: String, request: [String: Any]) -> Bool {
        if let url = request["url"] as? String { return x != url }
        return !x.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Checks if the request name changed.
    func didRequestNameChange(_ x: String, request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.rescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqName, block: { (x: Any?) -> Bool in
            return self.didRequestNameChangeImp(x as! String, request: request)
        }, callback: { status in
            callback(status)
        }, arg: x))
    }
    
    func didRequestNameChangeImp(_ x: String, request: [String: Any]) -> Bool {
        if let name = request["name"] as? String { return x != name }
        return !x.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Checks if the request's description changed.
    func didRequestDescriptionChange(_ x: String, request: [String: Any], callback: @escaping (Bool) -> Void) {
        //self.rescheduler.schedule { [weak self] in if self != nil { callback(self!.didRequestDescriptionChangeImp(x, request: request)) } }
    }
    
    func didRequestDescriptionChangeImp(_ x: String, request: [String: Any]) -> Bool {
        if let desc = request["desc"] as? String { return x != desc }
        return !x.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Checks if any of the request's meta data changed.
    func didRequestMetaChange(name: String, desc: String, request: [String: Any], callback: @escaping (Bool) -> Void) {
        //self.rescheduler.schedule { [weak self] in if self != nil { callback(self!.didRequestMetaChangeImp(name: name, desc: desc, request: request)) } }
    }
    
    func didRequestMetaChangeImp(name: String, desc: String, request: [String: Any]) -> Bool {
        return self.didRequestNameChangeImp(name, request: request) || self.didRequestDescriptionChangeImp(desc, request: request)
    }
    
    /// Check if any of the request headers changed.
    func didAnyRequestHeaderChange(_ xs: [ERequestData], request: [String: Any]) -> Bool {
        var xs: [Entity] = xs
        self.localdb.sortByCreated(&xs)
        let len = xs.count
        if len != (request["headers"] as! [[String: Any]]).count { return true }
        let headers: [[String: Any]] = request["headers"] as! [[String: Any]]
        for i in 0..<len {
            if self.didRequestDataChange(x: xs[i] as! ERequestData, y: headers[i], type: .header) { return true }
        }
        return false
    }

    /// Check if any of the request params changed.
    func didAnyRequestParamChange(_ xs: [ERequestData], request: [String: Any]) -> Bool {
        var xs: [Entity] = xs
        self.localdb.sortByCreated(&xs)
        let len = xs.count
        if len != (request["params"] as! [[String: Any]]).count { return true }
        let params: [[String: Any]] = request["params"] as! [[String: Any]]
        for i in 0..<len {
            if self.didRequestDataChange(x: xs[i] as! ERequestData, y: params[i], type: .param) { return true }
        }
        return false
    }
    
    /// Checks if the request body changed
    func didRequestBodyChange(_ x: ERequestBodyData?, request: [String: Any]) -> Bool {
        if (x == nil && request["body"] != nil) || (x != nil && request["body"] == nil) { return true }
        if let body = request["body"] as? [String: Any] {
            if x?.binary != body["binary"] as? Data ||
                x?.index != body["index"] as? Int64 ||
                x?.json != body["json"] as? String ||
                x?.raw != body["raw"] as? String ||
                x?.selected != body["selected"] as? Int32 ||
                x?.xml != body["xml"] as? String {
                return true
            }
            if x != nil && self.didAnyRequestBodyFormChange(x!, request: request) { return true }
        }
        return false
    }
    
    /// Checks if the any of the request body form elements changed.
    func didAnyRequestBodyFormChange(_ x: ERequestBodyData, request: [String: Any]) -> Bool {
        if request["body"] == nil { return true }
        if let body = request["body"] as? [String: Any] {
            if (x.form != nil && body["form"] == nil) || (x.form == nil && body["form"] != nil) { return true }
            if (x.multipart != nil && body["multipart"] == nil) || (x.multipart == nil && body["multipart"] != nil) { return true }
            
            var formxsa = x.form!.allObjects as! [Entity]
            let formxsb = body["form"] as! [[String: Any]]
            self.localdb.sortByCreated(&formxsa)
            
            let len = formxsa.count
            for i in 0..<len {
                if self.didRequestDataChange(x: formxsa[i] as! ERequestData, y: formxsb[i], type: .form) { return true }
            }
        }
        return false
    }
    
    // TODO: add unit test
    func didRequestBodyFormChange(_ body: ERequestBodyData, reqData: ERequestData, request: [String: Any]) -> Bool {
        if let reqDataId = reqData.id, let set = body.form, let xs = set.allObjects as? [ERequestData], let _ = xs.first(where: { x -> Bool in
            x.id == reqDataId
        }) {
            // Check if form and request data are the same
            if let type = RequestDataType(rawValue: reqData.type.toInt()) {
                if self.didRequestDataChange(x: reqData, y: request, type: type) { return true }
            }
        } else {  // No request data found in forms => added
            return true
        }
        return false
    }
    
    /// Checks if the given form's attachments changed.
    func didRequestBodyFormAttachmentChange(_ x: ERequestData, y: [String: Any]) -> Bool {
        if (x.image != nil && y["image"] == nil) || (x.image == nil && y["image"] != nil) { return true }
        if let ximage = x.image, let yimage = y["image"] as? [String: Any]  {
            if self.didRequestImageChange(x: ximage, y: yimage) { return true }
        }
        if (x.files != nil && y["files"] == nil) || (x.files == nil && y["file"] != nil) { return true }
        let yfiles = y["files"] as! [[String: Any]]
        if x.files!.count != yfiles.count { return true }
        if let set = x.files, var xs = set.allObjects as? [Entity] {
            self.localdb.sortByCreated(&xs)
            let len = xs.count
            for i in 0..<len {
                if self.didRequestFileChange(x: xs[i] as! EFile, y: yfiles[i]) { return true }
            }
        }
        return false
    }
    
    func didRequestDataChange(x: ERequestData, y: [String: Any], type: RequestDataType) -> Bool {
        if x.created != y["created"] as? Int64 ||
            x.fieldFormat != y["fieldFormat"] as? Int32 ||
            x.index != y["index"] as? Int64 ||
            x.key != y["key"] as? String ||
            x.type != y["type"] as? Int32 ||
            x.value != y["value"] as? String {
            return true
        }
        if type == .form {
            if self.didRequestBodyFormAttachmentChange(x, y: y) { return true }
        } else if type == .multipart {
            // TODO:
        }
        return false
    }
    
    func didRequestFileChange(x: EFile, y: [String: Any]) -> Bool {
        if x.created != y["created"] as? Int64 ||
            x.index != y["index"] as? Int64 ||
            x.name != y["name"] as? String ||
            x.path != y["path"] as? URL ||  // TODO: test
            x.type != y["type"] as? Int32  {
            return true
        }
        if let id = x.id, let xdata = x.data, let file = self.localdb.getFileData(id: id), let ydata = file.data {
            if xdata != ydata { return true }
        }
        return false
    }
    
    func didRequestImageChange(x: EImage, y: [String: Any]) -> Bool {
        if x.created != y["created"] as? Int64 ||
            x.index != y["index"] as? Int64 ||
            x.name != y["name"] as? String ||
            x.isCameraMode != y["isCameraMode"] as? Bool ||
            x.type != y["type"] as? String  {
            return true
        }
        if let id = x.id, let xdata = x.image, let image = self.localdb.getImageData(id: id), let ydata = image.image {
            if xdata != ydata { return true }
        }
        return false
    }

    // MARK: - Theme
    public struct Color {
        //public static let lightGreen = UIColor(red: 196/255, green: 223/255, blue: 168/255, alpha: 1.0)
        public static let lightGreen = UIColor(red: 120/255, green: 184/255, blue: 86/255, alpha: 1.0)
        public static let darkGreen = UIColor(red: 91/255, green: 171/255, blue: 60/255, alpha: 1.0)
        public static let darkGrey = UIColor(red: 75/255, green: 74/255, blue: 75/255, alpha: 1.0)
        public static let lightGrey = UIColor(red: 209/255, green: 209/255, blue: 208/255, alpha: 1.0)
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
        public static var requestEditDoneBtnDisabled: UIColor = {
            if #available(iOS 13, *) {
                return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                    if UITraitCollection.userInterfaceStyle == .dark {
                        return UIColor.darkGray
                    } else {
                        return Color.lightGrey
                    }
                }
            } else {
                return Color.lightGrey
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
