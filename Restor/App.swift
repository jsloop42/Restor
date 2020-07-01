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
import CloudKit

struct EditRequestInfo: Hashable {
    var id: String
    var moID: NSManagedObjectID
    var recordType: RecordType
    var isDelete: Bool = false
}

class App {
    static let shared: App = App()
    var popupBottomContraints: NSLayoutConstraint?
    private var dbService = PersistenceService.shared
    private let localdb = CoreDataService.shared
    private let utils = EAUtils.shared
    /// Entity diff rescheduler.
    var diffRescheduler = EARescheduler(interval: 0.3, type: .everyFn)
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
    var editReqInfo: Set<EditRequestInfo> = Set()
    var editReqDelete: Set<EditRequestInfo> = Set()
    private let editReqLock = NSLock()
    private let nc = NotificationCenter.default
    private var appLaunched = false
    
    enum Screen {
        case workspaceList
        case projectList
        case requestList
        case editRequest
        case request
        case settings
        case envGroup
        case envVar
        case requestMethodList
        case requestBodyTypeList  // json, xml ..
        case requestBodyFormTypeList  // text, file
        case popup
    }
    
    func bootstrap() {
        self.initDB()
        self.initState()
    }
    
    func initDB() {
        
    }
    
    func initState() {
        _ = self.getSelectedWorkspace()
    }
    
    func initUI(_ vc: UINavigationController) {
        self.updateViewBackground(vc.view)
        self.updateNavigationControllerBackground(vc)
    }
    
    // MARK: - App lifecycle events
    
    private func didFinishLaunchingImpl(window: UIWindow) {
        if !self.appLaunched {
            CoreDataService.shared.bootstrap()
            EACloudKit.shared.bootstrap()
            self.initUI(window.rootViewController as! UINavigationController)
            self.appLaunched = true
        }
    }
    
    @available(iOS 13.0, *)
    func didFinishLaunching(scene: UIScene, window: UIWindow) {
        Log.debug("did finish launching")
        self.didFinishLaunchingImpl(window: window)
    }
    
    @available(iOS 10.0, *)
    func didFinishLaunching(app: UIApplication, window: UIWindow) {
        Log.debug("did finish launching")
        self.didFinishLaunchingImpl(window: window)
    }
    
    func willEnterForground() {
        do {
            self.nc.addObserver(self, selector: #selector(self.reachabilityDidChange(_:)), name: .reachabilityDidChange, object: EAReachability.shared)
            try EAReachability.shared.startNotifier()
        } catch let error {
            Log.error("Error starting reachability notifier: \(error)")
        }
    }
    
    func didEnterBackground() {
        self.nc.removeObserver(self, name: .reachabilityDidChange, object: EAReachability.shared)
        EAReachability.shared.stopNotifier()
        self.saveState()
    }
    
    @objc func reachabilityDidChange(_ notif: Notification) {
        Log.debug("reachability did change: \(notif)")
        if let reachability = notif.object as? EAReachability {
            Log.debug("network status: \(reachability.connection.description)")
            if reachability.connection == .unavailable {
                self.nc.post(name: .offline, object: self)
            } else {
                self.nc.post(name: .online, object: self)
            }
        }
    }
    
    func saveSelectedWorkspaceId(_ id: String) {
        EACloudKit.shared.saveValue(key: Const.selectedWorkspaceIdKey, value: id)
    }
    
    /// Invoked before application termination to perform save state, clean up.
    func saveState() {
        //self.localdb.saveBackgroundContext(isForce: true)
        self.localdb.saveMainContext()
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
        window?.backgroundColor = UIColor.clear
    }
    
    func updateViewBackground(_ view: UIView?) {
        if #available(iOS 13.0, *) {
            view?.backgroundColor = UIColor.systemBackground
        } else {
            view?.backgroundColor = UIColor.white
        }
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
        if let proj = AppState.currentProject {
            let idx = proj.requests?.count ?? 0
            return idx == 0 ? "Request" : "Request (\(idx + 1))"
        }
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
    func viewPopupScreen(_ vc: UIViewController, model: PopupModel, completion: (() -> Void)? = nil) {
        let screen = vc.storyboard!.instantiateViewController(withIdentifier: StoryboardId.popupVC.rawValue) as! PopupViewController
        screen.model = model
        vc.present(screen, animated: true, completion: completion)
    }
    
    func getSelectedWorkspace() -> EWorkspace {
        if AppState.currentWorkspace != nil { return AppState.currentWorkspace! }
        if let wsId = EACloudKit.shared.getValue(key: Const.selectedWorkspaceIdKey) as? String {
            if let ws = self.localdb.getWorkspace(id: wsId) {
                AppState.currentWorkspace = ws
                return ws
            }
        }
        let ws = self.localdb.getDefaultWorkspace()
        Log.debug("ws: \(ws)")
        self.saveSelectedWorkspaceId(ws.getId())
        return ws
    }
    
    func setSelectedWorkspace(_ ws: EWorkspace) {
        AppState.currentWorkspace = ws
        if let wsId = ws.id { self.saveSelectedWorkspaceId(wsId) }
    }
    
    func didReceiveMemoryWarning() {
        Log.debug("app: did receive memory warning")
        PersistenceService.shared.clearCache()
    }
    
    func getImageType(_ url: URL) -> ImageType? {
        let name = url.lastPathComponent
        if let ext = name.components(separatedBy: ".").last {
            return ImageType(rawValue: ext)
        }
        return .jpeg  // default photo extension
    }
    
    /// Get text for displaying in name, value cells. If the text value is not present, a space character will be returned so that cells gets displayed with
    /// proper dimension.
    func getKVText(_ text: String?) -> String {
        if text == nil { return " " }
        return text!.isEmpty ? " " : text!
    }
    
    // MARK: - Mark entity for delete
    
    func addEditRequestDeleteObject(_ obj: Entity?) {
        guard let obj = obj else { return }
        obj.managedObjectContext?.performAndWait {
            if obj.objectID.isTemporaryID { CoreDataService.shared.deleteEntity(obj); return }
            guard let type = RecordType.from(id: obj.getId()) else { return }
            self.editReqDelete.insert(EditRequestInfo(id: obj.getId(), moID: obj.objectID, recordType: type, isDelete: true))
        }
    }
    
    func removeEditRequestDeleteObject(_ obj: Entity) {
        guard let type = RecordType.from(id: obj.getId()) else { return }
        self.editReqDelete.remove(EditRequestInfo(id: obj.getId(), moID: obj.objectID, recordType: type, isDelete: true))
    }
    
    func clearEditRequestDeleteObjects() {
        self.editReqDelete.removeAll()
    }
    
    func markEntityForDelete(file: EFile?, ctx: NSManagedObjectContext? = nil) {
        ctx?.performAndWait {
            guard let file = file else { return }
            file.requestData = nil
            self.localdb.markEntityForDelete(file, ctx: ctx)
            self.addEditRequestDeleteObject(file)
        }
    }
    
    func markForDelete(image: EImage?, ctx: NSManagedObjectContext? = nil) {
        ctx?.performAndWait {
            guard let image = image else { return }
            image.requestData = nil
            self.localdb.markEntityForDelete(image, ctx: ctx)
            self.addEditRequestDeleteObject(image)
        }
    }
    
    func markEntityForDelete(reqData: ERequestData?, ctx: NSManagedObjectContext? = nil) {
        ctx?.performAndWait {
            guard let reqData = reqData else { return }
            if let xs = reqData.files?.allObjects as? [EFile] {
                xs.forEach { file in self.markEntityForDelete(file: file, ctx: ctx) }
            }
            if let img = reqData.image { self.markForDelete(image: img, ctx: ctx) }
            self.localdb.markEntityForDelete(reqData, ctx: ctx)
            reqData.header = nil
            reqData.param = nil
            reqData.form = nil
            reqData.multipart = nil
            reqData.binary = nil
            reqData.image = nil
            self.addEditRequestDeleteObject(reqData)
        }
    }
    
    func markEntityForDelete(body: ERequestBodyData?, ctx: NSManagedObjectContext? = nil) {
        ctx?.performAndWait {
            guard let body = body else { return }
            if let xs = body.form?.allObjects as? [ERequestData] {
                xs.forEach { reqData in self.markEntityForDelete(reqData: reqData, ctx: ctx) }
            }
            if let xs = body.multipart?.allObjects as? [ERequestData] {
                xs.forEach { reqData in self.markEntityForDelete(reqData: reqData, ctx: ctx) }
            }
            if let bin = body.binary { self.markEntityForDelete(reqData: bin, ctx: ctx) }
            body.request = nil
            self.localdb.markEntityForDelete(body, ctx: ctx)
            AppState.editRequest?.body = nil
            self.addEditRequestDeleteObject(body)
        }
    }
    
    func markEntityForDelete(reqMethodData: ERequestMethodData?, ctx: NSManagedObjectContext? = nil) {
        ctx?.performAndWait {
            guard let reqMethodData = reqMethodData else { return }
            self.localdb.markEntityForDelete(reqMethodData)
            reqMethodData.project = nil
            self.addEditRequestDeleteObject(reqMethodData)
        }
    }
    
    func markEntityForDelete(req: ERequest?, ctx: NSManagedObjectContext? = nil) {
        ctx?.performAndWait {
            guard let req = req else { return }
            self.localdb.markEntityForDelete(req)
            guard let projId = req.project?.getId() else { return }
            req.project = nil
            self.markEntityForDelete(body: req.body)
            if let xs = req.headers?.allObjects as? [ERequestData] {
                xs.forEach { reqData in self.markEntityForDelete(reqData: reqData) }
            }
            if let xs = req.params?.allObjects as? [ERequestData] {
                xs.forEach { reqData in self.markEntityForDelete(reqData: reqData) }
            }
            let reqMethods = self.localdb.getRequestMethodDataMarkedForDelete(projId: projId, ctx: ctx)
            reqMethods.forEach { method in self.markEntityForDelete(reqMethodData: method, ctx: ctx) }
            self.addEditRequestDeleteObject(req)
        }
    }
    
    func markEntityForDelete(proj: EProject?, ctx: NSManagedObjectContext? = nil) {
        ctx?.performAndWait {
            guard let proj = proj else { return }
            self.localdb.markEntityForDelete(proj)
            proj.workspace = nil
            if let xs = proj.requests?.allObjects as? [ERequest] {
                xs.forEach { req in self.markEntityForDelete(req: req, ctx: ctx) }
            }
            self.addEditRequestDeleteObject(proj)
        }
    }
    
    func markEntityForDelete(ws: EWorkspace?, ctx: NSManagedObjectContext? = nil) {
        ctx?.performAndWait {
            guard let ws = ws else { return }
            self.localdb.markEntityForDelete(ws)
            if let xs = ws.projects?.allObjects as? [EProject] {
                xs.forEach { proj in self.markEntityForDelete(proj: proj, ctx: ctx) }
            }
            self.addEditRequestDeleteObject(ws)
        }        
    }
    
    /// MARK: - Entity change tracking
    
    func addEditRequestEntity(_ obj: Entity?) {
        guard let obj = obj, let type = RecordType.from(id: obj.getId()) else { return }
        self.editReqLock.lock()
        self.editReqInfo.insert(EditRequestInfo(id: obj.getId(), moID: obj.objectID, recordType: type))
        self.editReqLock.unlock()
    }
    
    func removeEditRequestEntityId(_ obj: Entity) {
        guard let type = RecordType.from(id: obj.getId()) else { return }
        self.editReqInfo.remove(EditRequestInfo(id: obj.getId(), moID: obj.objectID, recordType: type))
    }
    
    func clearEditRequestEntityIds() {
        self.editReqInfo.removeAll()
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
            var status = true
            x.managedObjectContext?.performAndWait { status = self.didRequestChangeImp(x, request: request) }
            return status
        }, callback: { status in
            callback(status)
        }, args: [x]))
    }
    
    /// Checks if the request changed.
    /// - Parameters:
    ///   - x: The request object.
    ///   - request: The initial request dictionary.
    func didRequestChangeImp(_ x: ERequest, request: [String: Any]) -> Bool {
        self.addEditRequestEntity(x)
        if x.markForDelete != request["markForDelete"] as? Bool { x.isSynced = false; x.setChangeTagWithEditTs(); return true }
        if x.url == nil || x.url!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if x.validateSSL != request["validateSSL"] as? Bool { x.setChangeTagWithEditTs(); return true }
        if self.didRequestURLChangeImp(x.url ?? "", request: request) { x.setChangeTagWithEditTs(); return true }
        if self.didRequestMetaChangeImp(name: x.name ?? "", desc: x.desc ?? "", request: request) { x.setChangeTagWithEditTs(); return true }
        if self.didRequestMethodIndexChangeImp(x.selectedMethodIndex, request: request) { x.setChangeTagWithEditTs(); return true }
        self.addEditRequestEntity(x.method)
        if (x.method == nil && request["method"] != nil) || (x.method != nil && (x.method!.isInserted || x.method!.isDeleted) && request["method"] == nil) { return true }
        if let hm = request["method"] as? [String: Any], let ida = x.id, let idb = hm["id"] as? String, ida != idb { return true }
        guard let projId = x.project?.getId() else { return true }
        let methods = self.localdb.getRequestMethodData(projId: projId, ctx: x.managedObjectContext)
        if self.didAnyRequestMethodChangeImp(methods, request: request) { return true }
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
            x.isCustom != y["isCustom"] as? Bool ||
            x.name != y["name"] as? String ||
            x.markForDelete != y["markForDelete"] as? Bool {
            x.setChangeTagWithEditTs();
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
    
    /// Checks if any custom request method changed.
    /// - Parameters:
    ///   - xs: The list of request methods.
    ///   - request: The initial request dictionary.
    func didAnyRequestMethodChangeImp(_ xs: [ERequestMethodData], request: [String: Any]) -> Bool {
        let xsa = xs.filter { x -> Bool in
            let flag = x.isCustom && x.hasChanges
            if flag { self.addEditRequestEntity(x) }
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
        xs.forEach { x in self.addEditRequestEntity(x) }
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
        xs.forEach { x in self.addEditRequestEntity(x) }
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
        self.addEditRequestEntity(x)
        if (x == nil && request["body"] != nil) || (x != nil && request["body"] == nil) { x?.isSynced = false; return true }
        if let body = request["body"] as? [String: Any] {
            if x?.json != body["json"] as? String ||
                x?.raw != body["raw"] as? String ||
                x?.selected != body["selected"] as? Int64 ||
                x?.xml != body["xml"] as? String ||
                x?.markForDelete != request["markForDelete"] as? Bool {
                x?.isSynced = false
                x?.setChangeTagWithEditTs()
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
        if request["body"] == nil { x.isSynced = false; return true }
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
            formxsa.forEach { e in self.addEditRequestEntity(e) }
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
        if (obin == nil && reqData != nil) || (obin != nil && reqData == nil) { reqData?.isSynced = false; reqData?.setChangeTagWithEditTs(); return true }
        guard let lbin = reqData, let rbin = obin else { reqData?.isSynced = false; reqData?.setChangeTagWithEditTs(); return true }
        if lbin.created != rbin["created"] as? Int64 || lbin.markForDelete != rbin["markForDelete"] as? Bool { reqData?.isSynced = false; reqData?.setChangeTagWithEditTs(); return true }
        if self.didRequestBodyFormAttachmentChangeImp(lbin, y: rbin) { reqData?.isSynced = false; reqData?.setChangeTagWithEditTs(); return true }
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
                if self.didRequestDataChangeImp(x: reqData, y: request, type: type) { body.isSynced = false; return true }
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
        self.addEditRequestEntity(x.image)
        if (x.image != nil && y["image"] == nil) || (x.image == nil && y["image"] != nil) { x.isSynced = false; x.setChangeTagWithEditTs(); return true }
        if let ximage = x.image, let yimage = y["image"] as? [String: Any]  {
            if self.didRequestImageChangeImp(x: ximage, y: yimage) { x.isSynced = false; x.setChangeTagWithEditTs(); return true }
        }
        if (x.files != nil && y["files"] == nil) || (x.files == nil && y["file"] != nil) { return true }
        let yfiles = y["files"] as! [[String: Any]]
        if x.files!.count != yfiles.count { x.isSynced = false; return true }
        if let set = x.files, var xs = set.allObjects as? [Entity] {
            xs.forEach { x in self.addEditRequestEntity(x) }
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
            x.key != y["key"] as? String ||
            x.type != y["type"] as? Int64 ||
            x.value != y["value"] as? String ||
            x.markForDelete != y["markForDelete"] as? Bool {
            x.isSynced = false
            x.setChangeTagWithEditTs()
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
            x.name != y["name"] as? String ||
            x.type != y["type"] as? Int64 ||
            x.markForDelete != y["markForDelete"] as? Bool {
            x.isSynced = false
            x.setChangeTagWithEditTs();
            return true
        }
        if let id = x.id, let xdata = x.data, let file = self.localdb.getFileData(id: id), let ydata = file.data {
            if xdata != ydata { x.isSynced = false; x.setChangeTagWithEditTs(); return true }
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
            x.name != y["name"] as? String ||
            x.isCameraMode != y["isCameraMode"] as? Bool ||
            x.type != y["type"] as? String ||
            x.markForDelete != y["markForDelete"] as? Bool {
            x.isSynced = false
            x.setChangeTagWithEditTs()
            return true
        }
        if let id = x.id, let xdata = x.data, let image = self.localdb.getImageData(id: id), let ydata = image.data {
            if xdata != ydata { x.isSynced = false; x.setChangeTagWithEditTs(); return true }
        }
        return false
    }
    
    func getStatusCodeViewColor(_ statusCode: Int) -> UIColor {
        var color: UIColor!
        if statusCode > 0 {
            if (200..<299) ~= statusCode {
                color = UIColor(named: "http-status-200")
            } else if (300..<399) ~= statusCode {
                color = UIColor(named: "http-status-300")
            } else if (400..<500) ~= statusCode {
                color = UIColor(named: "http-status-400")
            } else if (500..<600) ~= statusCode {
                color = UIColor(named: "http-status-500")
            }
        } else if statusCode <= -1 {  // error
            color = UIColor(named: "http-status-error")
        } else {
            color = UIColor(named: "http-status-none")
        }
        return color!
    }

    // MARK: - Theme
    public struct Color {
        //public static let lightGreen = UIColor(red: 196/255, green: 223/255, blue: 168/255, alpha: 1.0)
        public static let lightGreen = UIColor(red: 120/255, green: 184/255, blue: 86/255, alpha: 1.0)
        public static let darkGreen = UIColor(red: 91/255, green: 171/255, blue: 60/255, alpha: 1.0)
        public static let darkGrey = UIColor(red: 75/255, green: 74/255, blue: 75/255, alpha: 1.0)
        public static let lightGrey = UIColor(red: 209/255, green: 209/255, blue: 208/255, alpha: 1.0)
        public static let lightGrey1 = UIColor(red: 241/255, green: 241/255, blue: 246/255, alpha: 1.0)
        public static let lightPurple = UIColor(red: 119/255, green: 123/255, blue: 246/255, alpha: 1.0)  // purple like
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
        public static var labelTitleFg: UIColor = {
            if #available(iOS 13, *) {
                return UIColor.secondaryLabel
            }
            return UIColor(red: 96/255, green: 97/255, blue: 101/255, alpha: 1.0)
        }()
        public static var textViewFg: UIColor = {
            if #available(iOS 13, *) {
                return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                    if UITraitCollection.userInterfaceStyle == .dark {
                        return UIColor.white
                    } else {
                        return UIColor.black
                    }
                }
            }
            return UIColor.black
        }()
        public static var navBarBg: UIColor = {
            let light = UIColor(red: 246/255, green: 247/255, blue: 248/255, alpha: 1.0)
            if #available(iOS 13, *) {
                return UIColor { (UITraitCollection: UITraitCollection) -> UIColor in
                    if UITraitCollection.userInterfaceStyle == .dark {
                        return UIColor(red: 39/255, green: 40/255, blue: 42/255, alpha: 1.0)
                    } else {
                        return light
                    }
                }
            }
            return light
        }()
    }
    
    public struct Font {
        static let monospace13 = UIFont(name: "Menlo-Regular", size: 13)
        static let monospace14 = UIFont(name: "Menlo-Regular", size: 14)
        static let font17 = UIFont.systemFont(ofSize: 17)
        static let font15 = UIFont.systemFont(ofSize: 15)
    }
}

enum TableCellId: String {
    case workspaceCell
}

enum StoryboardId: String {
    case base64VC
    case rootNav
    case editRequestVC
    case requestTabBar
    case requestVC
    case responseVC
    case environmentGroupVC
    case envEditVC
    case envVarVC
    case envPickerVC
    case importExportVC
    case optionsPickerNav
    case optionsPickerVC
    case popupVC
    case projectListVC
    case requestListVC
    case settingsVC
    case historyVC
    case workspaceListVC
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
    
    static func toString(_ type: Int) -> String {
        guard let _type = RequestBodyType(rawValue: type) else { return "" }
        switch _type {
        case .json:
            return "json"
        case .xml:
            return "xml"
        case .raw:
            return "raw"
        case .form:
            return "form"
        case .multipart:
            return "multipart"
        case .binary:
            return "binary"
        }
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
    case extrapolate
    case fileOpen
    case fileRead
    case fileWrite
    case fileNotFound
    case notFound
    case create
    case read
    case write
    case update
    case delete
    case network
    case offline
    case server
    case fetch
}

extension CKRecord {
    func getWsId() -> String {
        return self["wsId"] ?? ""
    }
}

extension UIStoryboard {
    static var main: UIStoryboard { UIStoryboard(name: "Main", bundle: nil) }
    static var rootNav: UINavigationController? { self.main.instantiateViewController(withIdentifier: StoryboardId.rootNav.rawValue) as? UINavigationController }
    static var workspaceListVC: WorkspaceListViewController? { self.main.instantiateViewController(withIdentifier: StoryboardId.workspaceListVC.rawValue) as? WorkspaceListViewController }
    static var projectListVC: ProjectListViewController? { self.main.instantiateViewController(withIdentifier: StoryboardId.projectListVC.rawValue) as? ProjectListViewController }
    static var requestListVC: RequestListViewController? { self.main.instantiateViewController(withIdentifier: StoryboardId.requestListVC.rawValue) as? RequestListViewController }
    static var requestTabBar: RequestTabBarController? { self.main.instantiateViewController(withIdentifier: StoryboardId.requestTabBar.rawValue) as? RequestTabBarController }
    static var editRequestVC: EditRequestTableViewController? { self.main.instantiateViewController(withIdentifier: StoryboardId.editRequestVC.rawValue) as? EditRequestTableViewController }
}
