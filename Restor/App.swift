//
//  App.swift
//  Restor
//
//  Created by jsloop on 23/01/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class App {
    static let shared: App = App()
    var addItemPopupView: PopupView?
    var popupBottomContraints: NSLayoutConstraint?
    private var dbService = PersistenceService.shared
    private let localdb = CoreDataService.shared
    /// Entity diff rescheduler.
    var diffRescheduler = EARescheduler(interval: 0.3, repeats: false, type: .everyFn)
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
    /// List of managed objects modified so that in case of discard, these entities can be reset.
    var editReqManIds: Set<NSManagedObjectID> = Set()
    
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
    
    /// Invocked before application termination to perform save state, clean up.
    func saveState() {
        self.localdb.saveBackgroundContext(isForce: true)
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
    
    func viewError(_ error: Error, vc: UIViewController) {
        UI.viewToast(self.getErrorMessage(for: error), vc: vc)
    }
    
    func getDataForURL(_ url: URL, completion: EADataResultCallback? = nil) {
        //if EAFileManager.isFileExists(at: url) {  // since the app is sandboxed, this check will not work.
            let fm = EAFileManager(url: url)
            fm.readToEOF(completion: completion)
        //} else {
         //   if let cb = completion { cb(.failure(AppError.fileNotFound)) }
        //}
    }
    
    func getFileName(_ url: URL) -> String {
        return url.lastPathComponent
    }
    
    /// Return a request name based on the current project's request count.
    func getNewRequestName() -> String {
        if let proj = AppState.currentProject { return "Request \(proj.requests?.count ?? 0)" }
        return "Request"
    }
    
    /// Return a request name and index based on the current project's request count.
    func getNewRequestNameWithIndex() -> (String, Int) {
        if let proj = AppState.currentProject {
            let idx = proj.requests?.count ?? 0
            return (idx == 0 ? "Request" : "Request (\(idx + 1))", idx)
        }
        return ("Request", 0)
    }
    
    /// Returns an error message that can be displayed to the user for the given error type.
    func getErrorMessage(for error: Error) -> String {
        if let err = error as? AppError {
            switch err {
            case .fileNotFound:
                return "The file is not found"
            case .fileOpen:
                return "Unable to open the file. Please try again."
            case .fileRead:
                return "Unable to read the file. Please try again."
            case .fileWrite:
                return "Unable to write to the file. Please try again."
            default:
                break
            }
        }
        return "Application encountered an error"
    }
    
    /// Display popup view controller with the given model
    func viewPopupScreen(_ vc: UIViewController, model: PopupModel) {
        let screen = vc.storyboard!.instantiateViewController(withIdentifier: StoryboardId.popupVC.rawValue) as! PopupViewController
        screen.model = model
        vc.present(screen, animated: true, completion: nil)
    }
    
    /// MARK: - Entity change tracking
    
    func addEditRequestManagedObjectId(_ id: NSManagedObjectID?) {
        if id != nil { self.editReqManIds.insert(id!) }
    }
    
    func removeEditRequestManagedObjectId(_ id: NSManagedObjectID) {
        self.editReqManIds.remove(id)
    }
    
    func clearEditRequestManagedObjectIds() {
        self.editReqManIds.removeAll()
    }
    
    // MARK: - Request change
    
    /// Checks if the request changed.
    /// - Parameters:
    ///   - x: The request object.
    ///   - request: The initial request dictionary.
    ///   - callback: The callback function.
    func didRequestChange(_ x: ERequest, request: [String: Any], callback: @escaping (Bool) -> Void) {
        // We need to check the whole object for change because, if a element changes, we set true, if another element did not change, we cannot
        // set false. So we would then have to keep track of which element changed the status and such.
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReq, block: { () -> Bool in
            return self.didRequestChangeImp(x, request: request)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    /// Checks if the request changed.
    /// - Parameters:
    ///   - x: The request object.
    ///   - request: The initial request dictionary.
    func didRequestChangeImp(_ x: ERequest, request: [String: Any]) -> Bool {
        self.addEditRequestManagedObjectId(x.objectID)
        if x.url == nil || x.url!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if self.didRequestURLChangeImp(x.url ?? "", request: request) { return true }
        if self.didRequestMetaChangeImp(name: x.name ?? "", desc: x.desc ?? "", request: request) { return true }
        if self.didRequestMethodIndexChangeImp(x.selectedMethodIndex, request: request) { return true }
        self.addEditRequestManagedObjectId(x.method?.objectID)
        if (x.method == nil && request["method"] != nil) || (x.method != nil && (x.method!.isInserted || x.method!.isDeleted) && request["method"] == nil) { return true }
        if let hm = request["method"] as? [String: Any], let ida = x.id, let idb = hm["id"] as? String, ida != idb { return true }
        if let methods = x.project?.requestMethods?.allObjects as? [ERequestMethodData] {
            if self.didAnyRequestMethodChangeImp(methods, request: request) { return true }
        }
        if self.didRequestBodyChangeImp(x.body, request: request) { return true }
        if let headers = x.headers?.allObjects as? [ERequestData] {
            if self.didAnyRequestHeaderChangeImp(headers, request: request) { return true }
        } else {
            if let headers = request["headers"] as? [[String: Any]], headers.count > 0 { return true }
        }
        if let params = x.params?.allObjects as? [ERequestData] {
            if self.didAnyRequestParamChangeImp(params, request: request) { return true }
        } else {
            if let params = request["params"] as? [[String: Any]], params.count > 0 { return true }
        }
        return false
    }
    
    /// Checks if the selected request method changed.
    /// - Parameters:
    ///   - x: The selected request method index.
    ///   - request: The initial request dictionary.
    ///   - callback: The callback function.
    func didRequestMethodIndexChange(_ x: Int64, request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqMethodIndex, block: { () -> Bool in
            return self.didRequestMethodIndexChangeImp(x, request: request)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    /// Checks if the selected request method changed.
    /// - Parameters:
    ///   - x: The selected request method index.
    ///   - request: The initial request dictionary.
    func didRequestMethodIndexChangeImp(_ x: Int64, request: [String: Any]) -> Bool {
        if let index = request["selectedMethodIndex"] as? Int64 { return x != index }
        return false
    }
    
    /// Checks if the request method changed.
    /// - Parameters:
    ///   - x: The request method.
    ///   - y: The initial request method dictionary.
    ///   - callback: The callback function.
    func didRequestMethodChange(_ x: ERequestMethodData, y: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqMethod, block: { () -> Bool in
            return self.didRequestMethodChangeImp(x, y: y)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    /// Checks if the request method changed.
    /// - Parameters:
    ///   - x: The request method.
    ///   - y: The initial request method dictionary.
    func didRequestMethodChangeImp(_ x: ERequestMethodData, y: [String: Any]) -> Bool {
        if x.created != y["created"] as? Int64 ||
            x.index != y["index"] as? Int64 ||
            x.isCustom != y["isCustom"] as? Bool ||
            x.name != y["name"] as? String {
            return true
        }
        return false
    }
    
    /// Checks if any request method changed.
    /// - Parameters:
    ///   - xs: The list of request methods.
    ///   - request: The initial request dictionary.
    ///   - callback: The callback function.
    func didAnyRequestMethodChange(_ xs: [ERequestMethodData], request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdAnyReqMethod, block: { () -> Bool in
            return self.didAnyRequestMethodChangeImp(xs, request: request)
        }, callback: { status in
            callback(status)
        }, args: xs))
    }
    
    /// Checks if any request method changed.
    /// - Parameters:
    ///   - xs: The list of request methods.
    ///   - request: The initial request dictionary.
    func didAnyRequestMethodChangeImp(_ xs: [ERequestMethodData], request: [String: Any]) -> Bool {
        let xsa = xs.filter { x -> Bool in
            let flag = x.isCustom && x.hasChanges
            if flag { self.addEditRequestManagedObjectId(x.objectID) }
            return flag
        }
        let xsb = (request["methods"] as? [[String: Any]])?.filter({ hm -> Bool in
            if let isCustom = hm["isCustom"] as? Bool { return isCustom }
            return false
        })
        let len = xsa.count
        if xsb == nil && len > 0 { return true }
        if xsb != nil && xsb!.count != len { return true }
        if xsb != nil {
            for i in 0..<len {
                if self.didRequestMethodChangeImp(xsa[i], y: xsb![i]) { return true }
            }
        }
        return false
    }
    
    /// Checks if the request URL changed.
    /// - Parameters:
    ///   - url: The request url.
    ///   - request: The initial request dictionary.
    ///   - callback: The callback function.
    func didRequestURLChange(_ url: String, request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqURL, block: { () -> Bool in
            return self.didRequestURLChangeImp(url, request: request)
        }, callback: { status in
            callback(status)
        }, args: [url]))
    }
    
    /// Checks if the request URL changed.
    /// - Parameters:
    ///   - url: The request url.
    ///   - request: The initial request dictionary.
    func didRequestURLChangeImp(_ url: String, request: [String: Any]) -> Bool {
        if let aUrl = request["url"] as? String { return aUrl != url }
        return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Checks if the request name changed.
    /// - Parameters:
    ///   - name: The request name
    ///   - request: The initial request dictionary.
    ///   - callback: The callback function.
    func didRequestNameChange(_ name: String, request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqName, block: { () -> Bool in
            return self.didRequestNameChangeImp(name, request: request)
        }, callback: { status in
            callback(status)
        }, args: [name]))
    }
    
    /// Checks if the request name changed.
    /// - Parameters:
    ///   - name: The request name
    ///   - request: The initial request dictionary.
    func didRequestNameChangeImp(_ name: String, request: [String: Any]) -> Bool {
        if let aName = request["name"] as? String { return aName != name }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Checks if the request description changed.
    /// - Parameters:
    ///   - desc: The request description.
    ///   - request: The initial request dictionary.
    ///   - callback: The callback function.
    func didRequestDescriptionChange(_ desc: String, request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqDesc, block: { () -> Bool in
            return self.didRequestDescriptionChangeImp(desc, request: request)
        }, callback: { status in
            callback(status)
        }, args: [desc]))
    }
    
    /// Checks if the request description changed.
    /// - Parameters:
    ///   - desc: The request description.
    ///   - request: The initial request dictionary.
    func didRequestDescriptionChangeImp(_ desc: String, request: [String: Any]) -> Bool {
        if let aDesc = request["desc"] as? String { return aDesc != desc }
        return !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Checks if any of the request's meta data changed.
    func didRequestMetaChange(name: String, desc: String, request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqMeta, block: { () -> Bool in
            return self.didRequestMetaChangeImp(name: name, desc: desc, request: request)
        }, callback: { status in
            callback(status)
        }, args: [name, desc]))
    }
    
    func didRequestMetaChangeImp(name: String, desc: String, request: [String: Any]) -> Bool {
        return self.didRequestNameChangeImp(name, request: request) || self.didRequestDescriptionChangeImp(desc, request: request)
    }
    
    func didAnyRequestHeaderChange(_ xs: [ERequestData], request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqHeader, block: { () -> Bool in
            return self.didAnyRequestHeaderChangeImp(xs, request: request)
        }, callback: { status in
            callback(status)
        }, args: xs))
    }
    
    /// Check if any of the request headers changed.
    func didAnyRequestHeaderChangeImp(_ xs: [ERequestData], request: [String: Any]) -> Bool {
        var xs: [Entity] = xs
        xs.forEach { x in self.addEditRequestManagedObjectId(x.objectID) }
        self.localdb.sortByCreated(&xs)
        let len = xs.count
        if len != (request["headers"] as! [[String: Any]]).count { return true }
        let headers: [[String: Any]] = request["headers"] as! [[String: Any]]
        for i in 0..<len {
            if self.didRequestDataChangeImp(x: xs[i] as! ERequestData, y: headers[i], type: .header) { return true }
        }
        return false
    }

    func didAnyRequestParamChange(_ xs: [ERequestData], request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqParam, block: { () -> Bool in
            return self.didAnyRequestParamChangeImp(xs, request: request)
        }, callback: { status in
            callback(status)
        }, args: xs))
    }
    
    /// Check if any of the request params changed.
    func didAnyRequestParamChangeImp(_ xs: [ERequestData], request: [String: Any]) -> Bool {
        var xs: [Entity] = xs
        xs.forEach { x in self.addEditRequestManagedObjectId(x.objectID) }
        self.localdb.sortByCreated(&xs)
        let len = xs.count
        if len != (request["params"] as! [[String: Any]]).count { return true }
        let params: [[String: Any]] = request["params"] as! [[String: Any]]
        for i in 0..<len {
            if self.didRequestDataChangeImp(x: xs[i] as! ERequestData, y: params[i], type: .param) { return true }
        }
        return false
    }
    
    func didRequestBodyChange(_ x: ERequestBodyData?, request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqBody, block: { () -> Bool in
            return self.didRequestBodyChangeImp(x, request: request)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    /// Checks if the request body changed
    func didRequestBodyChangeImp(_ x: ERequestBodyData?, request: [String: Any]) -> Bool {
        self.addEditRequestManagedObjectId(x?.objectID)
        if (x == nil && request["body"] != nil) || (x != nil && request["body"] == nil) { return true }
        if let body = request["body"] as? [String: Any] {
            if x?.index != body["index"] as? Int64 ||
                x?.json != body["json"] as? String ||
                x?.raw != body["raw"] as? String ||
                x?.selected != body["selected"] as? Int64 ||
                x?.xml != body["xml"] as? String {
                return true
            }
            // TODO: handle binary
            if x != nil && self.didAnyRequestBodyFormChangeImp(x!, request: request) { return true }
        }
        return false
    }
    
    func didAnyRequestBodyFormChange(_ x: ERequestBodyData, request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdAnyReqBodyForm, block: { () -> Bool in
            return self.didAnyRequestBodyFormChangeImp(x, request: request)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    /// Checks if the any of the request body form elements changed.
    func didAnyRequestBodyFormChangeImp(_ x: ERequestBodyData, request: [String: Any]) -> Bool {
        if request["body"] == nil { return true }
        if let body = request["body"] as? [String: Any] {
            if (x.form != nil && body["form"] == nil) || (x.form == nil && body["form"] != nil) { return true }
            if (x.multipart != nil && body["multipart"] == nil) || (x.multipart == nil && body["multipart"] != nil) { return true }
            var formxsa: [Entity] = []
            var formxsb: [[String: Any]] = []
            let selectedType = RequestBodyType(rawValue: x.selected.toInt()) ?? .form
            var reqDataType = RequestDataType.form
            if selectedType == .form {
                formxsa = x.form!.allObjects as! [Entity]
                formxsb = body["form"] as! [[String: Any]]
                reqDataType = .form
            } else if selectedType == .multipart {
                formxsa = x.multipart?.allObjects as! [Entity]
                formxsb = body["multipart"] as! [[String: Any]]
                reqDataType = .multipart
            } else if selectedType == .binary {
                return self.didRequestBodyBinaryChangeImp(x.binary, body: body)
            }
            formxsa.forEach { e in self.addEditRequestManagedObjectId(e.objectID) }
            if formxsa.count != formxsb.count { return true }
            self.localdb.sortByCreated(&formxsa)
            
            let len = formxsa.count
            for i in 0..<len {
                if self.didRequestDataChangeImp(x: formxsa[i] as! ERequestData, y: formxsb[i], type: reqDataType) { return true }
            }
        }
        return false
    }
    
    func didRequestBodyBinaryChangeImp(_ reqData: ERequestData?, body: [String: Any]) -> Bool {
        let obin = body["binary"] as? [String: Any]
        if (obin == nil && reqData != nil) || (obin != nil && reqData == nil) { return true }
        guard let lbin = reqData, let rbin = obin else { return true }
        if lbin.created != rbin["created"] as? Int64 { return true }
        if self.didRequestBodyFormAttachmentChangeImp(lbin, y: rbin) { return true }
        return false
    }
    
    func didRequestBodyFormChange(_ body: ERequestBodyData, reqData: ERequestData, request: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqBodyForm, block: { () -> Bool in
            return self.didRequestBodyFormChangeImp(body, reqData: reqData, request: request)
        }, callback: { status in
            callback(status)
        }, args: [body]))
    }
    
    // TODO: add unit test
    func didRequestBodyFormChangeImp(_ body: ERequestBodyData, reqData: ERequestData, request: [String: Any]) -> Bool {
        if let reqDataId = reqData.id, let set = body.form, let xs = set.allObjects as? [ERequestData], let _ = xs.first(where: { x -> Bool in
            x.id == reqDataId
        }) {
            // Check if form and request data are the same
            if let type = RequestDataType(rawValue: reqData.type.toInt()) {
                if self.didRequestDataChangeImp(x: reqData, y: request, type: type) { return true }
            }
        } else {  // No request data found in forms => added
            return true
        }
        return false
    }
    
    func didRequestBodyFormAttachmentChange(_ x: ERequestData, y: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqBodyFormAttachment, block: { () -> Bool in
            return self.didRequestBodyFormAttachmentChangeImp(x, y: y)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    /// Checks if the given form's attachments changed.
    func didRequestBodyFormAttachmentChangeImp(_ x: ERequestData, y: [String: Any]) -> Bool {
        self.addEditRequestManagedObjectId(x.image?.objectID)
        if (x.image != nil && y["image"] == nil) || (x.image == nil && y["image"] != nil) { return true }
        if let ximage = x.image, let yimage = y["image"] as? [String: Any]  {
            if self.didRequestImageChangeImp(x: ximage, y: yimage) { return true }
        }
        if (x.files != nil && y["files"] == nil) || (x.files == nil && y["file"] != nil) { return true }
        let yfiles = y["files"] as! [[String: Any]]
        if x.files!.count != yfiles.count { return true }
        if let set = x.files, var xs = set.allObjects as? [Entity] {
            xs.forEach { x in self.addEditRequestManagedObjectId(x.objectID) }
            self.localdb.sortByCreated(&xs)
            let len = xs.count
            for i in 0..<len {
                if self.didRequestFileChangeImp(x: xs[i] as! EFile, y: yfiles[i]) { return true }
            }
        }
        return false
    }
    
    func didRequestDataChange(x: ERequestData, y: [String: Any], type: RequestDataType, callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqData, block: { () -> Bool in
            return self.didRequestDataChangeImp(x: x, y: y, type: type)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    func didRequestDataChangeImp(x: ERequestData, y: [String: Any], type: RequestDataType) -> Bool {
        if x.created != y["created"] as? Int64 ||
            x.fieldFormat != y["fieldFormat"] as? Int64 ||
            x.index != y["index"] as? Int64 ||
            x.key != y["key"] as? String ||
            x.type != y["type"] as? Int64 ||
            x.value != y["value"] as? String {
            return true
        }
        if type == .form {
            if self.didRequestBodyFormAttachmentChangeImp(x, y: y) { return true }
        }
        return false
    }
    
    func didRequestFileChange(x: EFile, y: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqFile, block: { () -> Bool in
            return self.didRequestFileChangeImp(x: x, y: y)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    func didRequestFileChangeImp(x: EFile, y: [String: Any]) -> Bool {
        if x.created != y["created"] as? Int64 ||
            x.index != y["index"] as? Int64 ||
            x.name != y["name"] as? String ||
            x.type != y["type"] as? Int64  {
            return true
        }
        if let id = x.id, let xdata = x.data, let file = self.localdb.getFileData(id: id), let ydata = file.data {
            if xdata != ydata { return true }
        }
        return false
    }
    
    func didRequestImageChange(x: EImage, y: [String: Any], callback: @escaping (Bool) -> Void) {
        self.diffRescheduler.schedule(fn: EAReschedulerFn(id: self.fnIdReqImage, block: { () -> Bool in
            return self.didRequestImageChangeImp(x: x, y: y)
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    func didRequestImageChangeImp(x: EImage, y: [String: Any]) -> Bool {
        if x.created != y["created"] as? Int64 ||
            x.index != y["index"] as? Int64 ||
            x.name != y["name"] as? String ||
            x.isCameraMode != y["isCameraMode"] as? Bool ||
            x.type != y["type"] as? String  {
            return true
        }
        if let id = x.id, let xdata = x.data, let image = self.localdb.getImageData(id: id), let ydata = image.data {
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
        public static let lightGrey1 = UIColor(red: 241/255, green: 241/255, blue: 246/255, alpha: 1.0)
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
        public static var tableViewBg: UIColor = {
            if #available(iOS 13, *) {
                return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                    if UITraitCollection.userInterfaceStyle == .dark {
                        return UIColor.systemBackground
                    } else {
                        return Color.lightGrey1
                    }
                }
            } else {
                return Color.lightGrey1
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
    case editRequestVC
    case environmentGroupVC
    case optionsPickerNav
    case optionsPickerVC
    case popupVC
    case projectVC
    case requestListVC
    case settingsVC
    case workspaceVC
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
    case binary
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
