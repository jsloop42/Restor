//
//  WorkspaceListViewController.swift
//  Restor
//
//  Created by jsloop on 02/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import UIKit
import CoreData

extension Notification.Name {
    static let workspaceVCShouldPresent = Notification.Name("workspace-vc-should-present")
    static let workspaceDidChange = Notification.Name("workspace-did-change")
    static let workspaceWillClose = Notification.Name("workspace-will-close")
}

class WorkspaceListViewController: RestorViewController {
    static weak var shared: WorkspaceListViewController?
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addBtn: UIBarButtonItem!
    private var popupBottomContraints: NSLayoutConstraint?
    private var isKeyboardActive = false
    private var keyboardHeight: CGFloat = 0.0
    private let utils = EAUtils.shared
    private let app: App = App.shared
    private let nc = NotificationCenter.default
    private lazy var localdb = { CoreDataService.shared }()
    private var frc: NSFetchedResultsController<EWorkspace>!
    private lazy var db = { PersistenceService.shared }()
    private var wsSelected: EWorkspace!
    
    deinit {
        self.nc.post(name: .workspaceWillClose, object: self)
        self.nc.removeObserver(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        WorkspaceListViewController.shared = self
        AppState.setCurrentScreen(.workspaceList)
        self.navigationItem.title = "Workspaces"
        self.reloadData()
        self.tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initData()
        self.initUI()
        self.initEvents()
    }

    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        if #available(iOS 13.0, *) {
            self.isModalInPresentation = true
        }
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.reloadData()
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.databaseWillUpdate(_:)), name: .databaseWillUpdate, object: nil)
        self.nc.addObserver(self, selector: #selector(self.databaseDidUpdate(_:)), name: .databaseDidUpdate, object: nil)
        self.nc.addObserver(self, selector: #selector(self.workspaceDidSync(_:)), name: .workspaceDidSync, object: nil)
    }
    
    func initData() {
        if self.frc == nil {
            if let _frc = self.localdb.getFetchResultsController(obj: EWorkspace.self, predicate: NSPredicate(format: "markForDelete == %hhd", false), ctx: self.localdb.mainMOC) as? NSFetchedResultsController<EWorkspace> {
                self.frc = _frc
                self.frc.delegate = self
            }
        }
        self.reloadData()
    }
    
    func updateData() {
        if self.frc == nil { return }
        self.frc.delegate = nil
        try? self.frc.performFetch()
        self.frc.delegate = self
        self.tableView.reloadData()
    }
    
    func postWorkspaceWillCloseEvent() {
        self.nc.post(name: .workspaceWillClose, object: self)
    }
    
    func close() {
        self.postWorkspaceWillCloseEvent()
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func workspaceDidSync(_ notif: Notification) {
        DispatchQueue.main.async { self.reloadData() }
    }
    
    @objc func databaseWillUpdate(_ notif: Notification) {
        DispatchQueue.main.async { self.frc.delegate = nil }
    }
    
    @objc func databaseDidUpdate(_ notif: Notification) {
        DispatchQueue.main.async {
            self.frc.delegate = self
            self.reloadData()
        }
    }
    
    func reloadData() {
        self.wsSelected = self.app.getSelectedWorkspace()
        if self.frc == nil { return }
        do {
            try self.frc.performFetch()
            self.tableView.reloadData()
        } catch let error {
            Log.error("Error fetching: \(error)")
        }
    }
    
    @IBAction func addBtnDidTap(_ sender: Any) {
        Log.debug("add btn did tap")
        self.viewAlert(vc: self, storyboard: self.storyboard!)
    }
    
    @objc func settingsBtnDidTap(_ sender: Any) {
        Log.debug("settings button did tap")
    }
    
    func viewPopup() {
        self.app.viewPopupScreen(self, model: PopupModel(title: "New Workspace", iCloudSyncFieldEnabled: true, shouldValidate: true, doneHandler: { model in
            Log.debug("model value: \(model.name) - \(model.desc)")
            AppState.setCurrentScreen(.workspaceList)
            self.addWorkspace(name: model.name, desc: model.desc, isSyncEnabled: model.iCloudSyncFieldEnabled)
        }, validateHandler: { model in
            return !model.name.isEmpty
        }))
    }
    
    func didPopupModelChange(_ model: PopupModel, ws: EWorkspace) -> Bool {
        var didChange = true
        ws.managedObjectContext?.performAndWait {
            if model.name.isEmpty {
                didChange = false
            } else {
                didChange = false
                if ws.name != model.name {
                    didChange = true
                }
                if ws.desc != model.desc {
                    didChange = true
                }
            }
        }
        return didChange
    }
    
    func viewEditPopup(_ ws: EWorkspace) {
        self.app.viewPopupScreen(self, model: PopupModel(title: "Edit Workspace", name: ws.getName(), desc: ws.desc ?? "", shouldValidate: true, doneHandler: { model in
            Log.debug("model value: \(model.name) - \(model.desc)")
            var didChange = false
            if ws.name != model.name {
                ws.name = model.name
                didChange = true
            }
            if ws.desc != model.desc {
                ws.desc = model.desc
                didChange = true
            }
            if didChange {
                self.localdb.saveMainContext()
                self.updateData()
            }
        }, validateHandler: { model in
            return self.didPopupModelChange(model, ws: ws)
        }))
    }
    
    func displayAddButton() {
        self.addBtn.isEnabled = true
    }
    
    func hideAddButton() {
        self.addBtn.isEnabled = false
    }
    
    func viewAlert(vc: UIViewController, storyboard: UIStoryboard, message: String? = nil, title: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "New Workspace", style: .default, handler: { action in
            Log.debug("new workspace did tap")
            self.viewPopup()
        }))
        alert.modalPresentationStyle = .popover
        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.sourceView = vc.view
            popoverPresentationController.sourceRect = vc.view.bounds
            popoverPresentationController.permittedArrowDirections = []
        }
        vc.present(alert, animated: true, completion: nil)
    }
    
    func addWorkspace(name: String, desc: String, isSyncEnabled: Bool) {
        AppState.totalworkspaces = self.frc.numberOfRows(in: 0)
        if let ws = self.localdb.createWorkspace(id: self.localdb.workspaceId(), name: name, desc: desc, isSyncEnabled: isSyncEnabled) {
            self.localdb.saveMainContext()
            self.db.saveWorkspaceToCloud(ws)
            self.reloadData()
        }
    }
}

class WorkspaceCell: UITableViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var descLbl: UILabel!
}

extension WorkspaceListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.frc.numberOfRows(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableCellId.workspaceCell.rawValue, for: indexPath) as! WorkspaceCell
        let ws = self.frc.object(at: indexPath)
        cell.accessoryType = .none
        if ws.id == self.wsSelected.id { cell.accessoryType = .checkmark }
        cell.nameLbl.text = ws.name
        cell.descLbl.text = ws.desc
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("workspace cell did select \(indexPath.row)")
        let ws = self.frc.object(at: indexPath)
        self.app.setSelectedWorkspace(ws)
        self.nc.post(name: .workspaceDidChange, object: self, userInfo: ["workspace": ws])
        self.close()
    }
    
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let ws = self.frc.object(at: indexPath)
        let edit = UIContextualAction(style: .normal, title: "Edit") { action, view, completion in
            Log.debug("edit row: \(indexPath)")
            self.viewEditPopup(ws)
            completion(true)
        }
        edit.backgroundColor = App.Color.lightPurple
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            Log.debug("delete row: \(indexPath)")
            if ws == self.wsSelected {  // Reset selection to the default workspace
                let wss = self.localdb.getAllWorkspaces(offset: 0, limit: 1, includeMarkForDelete: false, ctx: self.localdb.mainMOC)
                self.wsSelected = !wss.isEmpty ? wss.first! : self.localdb.getDefaultWorkspace()
            }
            self.localdb.markEntityForDelete(ws)
            self.localdb.saveMainContext()
            self.db.deleteDataMarkedForDelete(ws, ctx: self.localdb.mainMOC)
            self.updateData()
            completion(true)
        }
        let swipeActionConfig = UISwipeActionsConfiguration(actions: ws.isInDefaultMode ? [edit] : [delete, edit])
        swipeActionConfig.performsFirstActionWithFullSwipe = false
        return swipeActionConfig
    }
}

extension WorkspaceListViewController: NSFetchedResultsControllerDelegate {    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("workspace list frc did change object: \(anObject)")
        if AppState.currentScreen != .workspaceList { return }
        DispatchQueue.main.async {
            self.tableView.reloadData()
            switch type {
            case .insert:
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.tableView.scrollToBottom(section: 0) }
            default:
                break
            }
        }
    }
}
