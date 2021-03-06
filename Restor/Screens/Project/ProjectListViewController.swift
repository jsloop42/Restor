//
//  ProjectListViewController.swift
//  Restor
//
//  Created by jsloop on 09/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import CoreData

extension Notification.Name {
    static let navigatedBackToProjectList = Notification.Name("did-navigate-back-to-project-list-vc")
}

class ProjectListViewController: RestorViewController {
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var workspaceBtn: UIButton!
    @IBOutlet weak var helpTextLabel: UILabel!
    private var workspace: EWorkspace!
    private var popupBottomContraints: NSLayoutConstraint?
    private var isKeyboardActive = false
    private var keyboardHeight: CGFloat = 0.0
    private let utils: EAUtils = EAUtils.shared
    private let app: App = App.shared
    private let nc = NotificationCenter.default
    private lazy var localdb = { CoreDataService.shared }()
    private lazy var db = { PersistenceService.shared }()
    private var frc: NSFetchedResultsController<EProject>!
    private let cellReuseId = "projectCell"
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.setCurrentScreen(.projectList)
        self.navigationItem.title = "Projects"
        self.navigationItem.leftBarButtonItem = self.addSettingsBarButton()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addBtnDidTap(_:)))
        self.workspace = self.app.getSelectedWorkspace()
        self.updateWorkspaceTitle(self.workspace.name ?? "")
        if !isRunningTests {
            self.reloadData()
            self.tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("project view did load")
        if !isRunningTests {
            self.app.bootstrap()
            self.initData()
            self.initUI()
            self.initEvent()
        }
    }
    
    func initUI() {
        Log.debug("init UI")
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.app.updateNavigationControllerBackground(self.navigationController)
    }
    
    func initEvent() {
        self.nc.addObserver(self, selector: #selector(self.databaseWillUpdate(_:)), name: .databaseWillUpdate, object: nil)
        self.nc.addObserver(self, selector: #selector(self.databaseDidUpdate(_:)), name: .databaseDidUpdate, object: nil)
        self.nc.addObserver(self, selector: #selector(self.workspaceDidSync(_:)), name: .workspaceDidSync, object: nil)
        self.nc.addObserver(self, selector: #selector(self.workspaceDidChange(_:)), name: .workspaceDidChange, object: nil)
    }
    
    func getFRCPredicate(_ wsId: String) -> NSPredicate {
        return NSPredicate(format: "workspace.id == %@ AND name != %@ AND markForDelete == %hdd", wsId, "", false)
        //return NSPredicate(format: "workspace.id == %@ AND name != %@", wsId, "")
    }
    
    func initData() {
        self.workspace = self.app.getSelectedWorkspace()
        if self.frc == nil, let wsId = self.workspace.id {
            let predicate = self.getFRCPredicate(wsId)
            if let _frc = self.localdb.getFetchResultsController(obj: EProject.self, predicate: predicate, ctx: self.localdb.mainMOC) as? NSFetchedResultsController<EProject> {
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
        self.checkHelpShouldDisplay()
        self.tableView.reloadData()
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
    
    func checkHelpShouldDisplay() {
        if self.frc.numberOfRows(in: 0) == 0 {
            self.displayHelpText()
        } else {
            self.hideHelpText()
        }
    }
    
    func reloadData() {
        if self.frc == nil { return }
        do {
            try self.frc.performFetch()
            self.checkHelpShouldDisplay()
            self.tableView.reloadData()
        } catch let error {
            Log.error("Error fetching: \(error)")
        }
    }
    
    func displayHelpText() {
        if !self.helpTextLabel.isHidden { return }
        UIView.animate(withDuration: 0.3) {
            self.helpTextLabel.isHidden = false
        }
    }
    
    func hideHelpText() {
        if self.helpTextLabel.isHidden { return }
        UIView.animate(withDuration: 0.3) {
            self.helpTextLabel.isHidden = true
        }
    }
    
    func updateWorkspaceTitle(_ name: String) {
        DispatchQueue.main.async { self.workspaceBtn.setTitle(name, for: .normal) }
    }
    
    func updateListingWorkspace(_ ws: EWorkspace) {
        if self.workspace == ws { return }
        self.workspace = ws
        if let wsId = ws.id {
            let predicate = self.getFRCPredicate(wsId)
            if let _frc = self.localdb.updateFetchResultsController(self.frc as! NSFetchedResultsController<NSFetchRequestResult>, predicate: predicate, ctx: self.localdb.mainMOC) as? NSFetchedResultsController<EProject> {
                self.frc = _frc
                self.frc.delegate = self
                self.reloadData()
            }
        }
    }
    
    func addSettingsBarButton() -> UIBarButtonItem {
        if #available(iOS 13.0, *) {
            return UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(self.settingsButtonDidTap(_:)))
        }
        return UIBarButtonItem(image: UIImage(named: "settings"), style: .plain, target: self, action: #selector(self.settingsButtonDidTap(_:)))
    }
    
    @objc func workspaceDidSync(_ notif: Notification) {
        DispatchQueue.main.async {
            self.workspace = self.app.getSelectedWorkspace()
            self.updateWorkspaceTitle(self.workspace.name ?? "")
        }
    }
    
    @objc func settingsButtonDidTap(_ sender: Any) {
        Log.debug("settings btn did tap")
        UI.pushScreen(self.navigationController!, storyboard: self.storyboard!, storyboardId: StoryboardId.settingsVC.rawValue)
    }
    
    func addProject(name: String, desc: String) {
        if let ctx = self.workspace.managedObjectContext {
            if let proj = self.localdb.createProject(id: self.localdb.projectId(), wsId: self.workspace.getId(), name: name, desc: desc, ws: self.workspace, ctx: ctx) {
                proj.workspace = self.workspace
                self.localdb.saveMainContext()
                self.db.saveProjectToCloud(proj)
            }
        }
    }
    
    @objc func addBtnDidTap(_ sender: Any) {
        Log.debug("add button did tap")
        //self.viewAlert(vc: self, storyboard: self.storyboard!)
        self.viewPopup()
    }
    
    @IBAction func workspaceDidTap(_ sender: Any) {
        Log.debug("workspace did tap")
        if let vc = UIStoryboard.workspaceListVC {
            self.navigationController!.present(vc, animated: true, completion: nil)
        }
    }
    
    @objc func workspaceDidChange(_ notif: Notification) {
        Log.debug("workspace did change notif")
        if let info = notif.userInfo, let ws = info["workspace"] as? EWorkspace {
            self.updateWorkspaceTitle(ws.getName())
            self.updateListingWorkspace(ws)
        }
    }
    
    @IBSegueAction func workspaceSegue(_ coder: NSCoder) -> WorkspaceListViewController? {
        let ws = WorkspaceListViewController(coder: coder)
        return ws
    }
    
    func viewPopup() {
        self.app.viewPopupScreen(self, model: PopupModel(title: "New Project", shouldValidate: true, doneHandler: { model in
            Log.debug("model value: \(model.name) - \(model.desc)")
            AppState.setCurrentScreen(.projectList)
            self.addProject(name: model.name, desc: model.desc)
        }, validateHandler: { model in
            return !model.name.isEmpty
        }))
    }
    
    func didPopupModelChange(_ model: PopupModel, proj: EProject) -> Bool {
        var didChange = true
        proj.managedObjectContext?.performAndWait {
            if model.name.isEmpty {
                didChange = false
            } else {
                didChange = false
                if proj.name != model.name {
                    didChange = true
                }
                if proj.desc != model.desc {
                    didChange = true
                }
            }
        }
        return didChange
    }
    
    func viewEditPopup(_ proj: EProject) {
        self.app.viewPopupScreen(self, model: PopupModel(title: "Edit Project", name: proj.getName(), desc: proj.desc ?? "", shouldValidate: true, doneHandler: { model in
            Log.debug("model value: \(model.name) - \(model.desc)")
            var didChange = false
            if proj.name != model.name {
                proj.name = model.name
                didChange = true
            }
            if proj.desc != model.desc {
                proj.desc = model.desc
                didChange = true
            }
            if didChange {
                self.localdb.saveMainContext()
                self.updateData()
            }
        }, validateHandler: { model in
            return self.didPopupModelChange(model, proj: proj)
        }))
    }
    
    func viewAlert(vc: UIViewController, storyboard: UIStoryboard, message: String? = nil, title: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "New Project", style: .default, handler: { action in
            Log.debug("new project did tap")
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
}

class ProjectCell: UITableViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var descLbl: UILabel!
    @IBOutlet weak var borderView: UIView!
    
    func hideBottomBorder() {
        self.borderView.isHidden = true
    }
    
    func displayBottomBorder() {
        self.borderView.isHidden = false
    }
}

extension ProjectListViewController: UITableViewDelegate, UITableViewDataSource {
    func getDesc(proj: EProject) -> String {
        return proj.desc ?? ""
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.frc == nil { return 0 }
        return self.frc.numberOfRows(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseId, for: indexPath) as! ProjectCell
        let proj = self.frc.object(at: indexPath)
        cell.nameLbl.text = proj.name
        let desc = self.getDesc(proj: proj)
        cell.descLbl.text = desc
        self.hideHelpText()
        if desc.isEmpty {
            cell.descLbl.isHidden = true
        } else {
            cell.descLbl.isHidden = false
        }
        if indexPath.row == self.frc.numberOfRows(in: indexPath.section) - 1 {
            cell.displayBottomBorder()
        } else {
            cell.hideBottomBorder()
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let proj = self.frc.object(at: indexPath)
        AppState.currentProject = proj  // TODO: remove AppState.currentProject
        DispatchQueue.main.async {
            if let vc = UIStoryboard.requestListVC {
                vc.project = proj
                self.navigationController!.pushViewController(vc, animated: true)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let edit = UIContextualAction(style: .normal, title: "Edit") { action, view, completion in
            Log.debug("edit row: \(indexPath)")
            let proj = self.frc.object(at: indexPath)
            self.viewEditPopup(proj)
            completion(true)
        }
        edit.backgroundColor = App.Color.lightPurple
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            Log.debug("delete row: \(indexPath)")
            let proj = self.frc.object(at: indexPath)
            self.localdb.markEntityForDelete(proj)
            self.localdb.saveMainContext()
            self.db.deleteDataMarkedForDelete(proj, ctx: self.localdb.mainMOC)
            self.updateData()
            completion(true)
        }
        let swipeActionConfig = UISwipeActionsConfiguration(actions: [delete, edit])
        swipeActionConfig.performsFirstActionWithFullSwipe = false
        return swipeActionConfig
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let proj = self.frc.object(at: indexPath)
        let name = proj.name ?? ""
        let desc = self.getDesc(proj: proj)
        let w = tableView.frame.width
        let h1 = name.height(width: w, font: App.Font.font17) + 20
        let h2: CGFloat =  desc.isEmpty ? 0 : desc.height(width: w, font: App.Font.font15) + 10
        return max(h1 + h2, 46)
    }
}

extension ProjectListViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("projects list frc did change")
        if AppState.currentScreen != .projectList { return }
        DispatchQueue.main.async {
            if self.navigationController?.topViewController == self {
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
}
