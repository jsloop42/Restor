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

class ProjectListViewController: UIViewController {
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var workspaceBtn: UIButton!
    private var workspace: EWorkspace!
    private var popupBottomContraints: NSLayoutConstraint?
    private var isKeyboardActive = false
    private var keyboardHeight: CGFloat = 0.0
    private let utils: EAUtils = EAUtils.shared
    private let app: App = App.shared
    private let nc = NotificationCenter.default
    private let localdb = CoreDataService.shared
    private let db = PersistenceService.shared
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
            // test
            //self.addProject(name: "Test Project", desc: "My awesome project")
            // end test
        }
    }
    
    func initUI() {
        Log.debug("init UI")
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.app.updateNavigationControllerBackground(self.navigationController)
        // TODO: test
        //self.addProject(name: "Test project", desc: "My awesome project")
        // end test
    }
    
    func initEvent() {
        self.nc.addObserver(self, selector: #selector(self.keyboardWillShow(notif:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        self.nc.addObserver(self, selector: #selector(self.keyboardWillHide(notif:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        self.nc.addObserver(self, selector: #selector(self.workspaceDidSync(_:)), name: NotificationKey.workspaceDidSync, object: nil)
    }
    
    func initData() {
        self.workspace = self.app.getSelectedWorkspace()
        if self.frc == nil, let wsId = self.workspace.id {
            let predicate = NSPredicate(format: "workspace.id == %@", wsId)
            if let _frc = self.localdb.getFetchResultsController(obj: EProject.self, predicate: predicate) as? NSFetchedResultsController<EProject> {
                self.frc = _frc
                self.frc.delegate = self
            }
        }
        self.reloadData()
    }
    
    func reloadData() {
        if self.frc == nil { return }
        do {
            try self.frc.performFetch()
            self.tableView.reloadData()
        } catch let error {
            Log.error("Error fetching: \(error)")
        }
    }
    
    func updateWorkspaceTitle(_ name: String) {
        DispatchQueue.main.async { self.workspaceBtn.setTitle(name, for: .normal) }
    }
    
    func updateListingWorkspace(_ ws: EWorkspace) {
        self.workspace = ws
        if let wsId = ws.id {
            if let _frc = self.localdb.updateFetchResultsController(self.frc as! NSFetchedResultsController<NSFetchRequestResult>, predicate: NSPredicate(format: "workspace.id == %@", wsId)) as? NSFetchedResultsController<EProject> {
                self.frc = _frc
                self.frc.delegate = self
                self.reloadData()
                self.tableView.reloadData()
            }
        }
    }
    
    func addSettingsBarButton() -> UIBarButtonItem {
        if #available(iOS 13.0, *) {
            return UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(self.settingsButtonDidTap(_:)))
        }
        return UIBarButtonItem(image: UIImage(), style: .plain, target: self, action: #selector(self.settingsButtonDidTap(_:)))
    }
    
    @objc func workspaceDidSync(_ notif: Notification) {
        self.workspace = self.app.getSelectedWorkspace()
        self.updateWorkspaceTitle(self.workspace.name ?? "")
    }
    
    @objc func settingsButtonDidTap(_ sender: Any) {
        Log.debug("settings btn did tap")
        UI.pushScreen(self.navigationController!, storyboard: self.storyboard!, storyboardId: StoryboardId.settingsVC.rawValue)
    }
    
    @objc func keyboardWillShow(notif: Notification) {
        if let userInfo = notif.userInfo, let keyboardSize = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue {
            AppState.keyboardHeight = keyboardSize.cgRectValue.height
            if self.view.frame.origin.y == 0 {
                // We need to offset in this case because the popup is contrained to the bottom of the view
                self.view.frame.origin.y -=  AppState.keyboardHeight
            }
        }
    }
    
    @objc func keyboardWillHide(notif: Notification) {
        self.view.frame.origin.y = 0
    }
    
    @objc func workspaceDidTap() {
        Log.debug("workspace did tap")
    }
    
    func addProject(name: String, desc: String) {
        if let ctx = self.workspace.managedObjectContext {
            if let proj = self.localdb.createProject(id: self.localdb.projectId(), name: name, desc: desc, ws: self.workspace, ctx: ctx) {
                proj.workspace = self.workspace
                self.localdb.saveBackgroundContext()
                self.db.saveProjectToCloud(proj)
            }
        }
    }
    
    @objc func addBtnDidTap(_ sender: Any) {
        Log.debug("add button did tap")
        self.viewAlert(vc: self, storyboard: self.storyboard!)
    }
    
    @IBAction func workspaceDidTap(_ sender: Any) {
        Log.debug("workspace did tap")
    }
    
    @IBSegueAction func workspaceSegue(_ coder: NSCoder) -> WorkspaceListViewController? {
        let ws = WorkspaceListViewController(coder: coder)
        ws?.delegate = self
        return ws
    }
    
    func viewPopup() {
        self.app.viewPopupScreen(self, model: PopupModel(title: "New Project", doneHandler: { model in
            Log.debug("model value: \(model.name) - \(model.desc)")
            AppState.setCurrentScreen(.projectList)
            self.addProject(name: model.name, desc: model.desc)
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
}

extension ProjectListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.frc == nil { return 0 }
        return self.frc.numberOfRows(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseId, for: indexPath) as! ProjectCell
        let proj = self.frc.object(at: indexPath)
        cell.nameLbl.text = proj.name
        cell.descLbl.text = proj.desc
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        AppState.currentProject = self.frc.object(at: indexPath)
        UI.pushScreen(self.navigationController!, storyboardId: StoryboardId.requestListVC.rawValue)
    }
}

extension ProjectListViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("projects list frc did change")
        if AppState.currentScreen != .projectList { return }
        DispatchQueue.main.async {
            if self.navigationController?.topViewController == self {
                switch type {
                case .delete:
                    self.tableView.deleteRows(at: [indexPath!], with: .automatic)
                case .insert:
                    self.tableView.beginUpdates()
                    self.tableView.insertRows(at: [newIndexPath!], with: .none)
                    self.tableView.endUpdates()
                    self.tableView.layoutIfNeeded()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.tableView.scrollToBottom(section: 0) }
                case .update:
                    self.tableView.reloadRows(at: [indexPath!], with: .none)
                default:
                    break
                }
            }
        }
    }
}

extension ProjectListViewController: WorkspaceVCDelegate {
    func workspaceDidChange(ws: EWorkspace) {
        self.updateWorkspaceTitle(ws.name ?? "")
        self.updateListingWorkspace(ws)
    }
}
