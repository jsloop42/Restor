//
//  WorkspaceListViewController.swift
//  Restor
//
//  Created by jsloop on 02/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import UIKit
import CoreData

protocol WorkspaceVCDelegate: class {
    func workspaceDidChange(ws: EWorkspace)
}

class WorkspaceListViewController: UIViewController {
    static weak var shared: WorkspaceListViewController?
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addBtn: UIBarButtonItem!
    private var popupBottomContraints: NSLayoutConstraint?
    private var isKeyboardActive = false
    private var keyboardHeight: CGFloat = 0.0
    private let utils = EAUtils.shared
    private let app: App = App.shared
    weak var delegate: WorkspaceVCDelegate?
    private let nc = NotificationCenter.default
    private let localdb = CoreDataService.shared
    private var frc: NSFetchedResultsController<EWorkspace>!
    private let db = PersistenceService.shared
    private var wsSelected: EWorkspace!
    
    deinit {
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
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.reloadData()
        // TODO: test
        //self.createNewWorkspace(name: "Test workspace", desc: "Test workspace desc")
        // end test
    }
    
    func initEvents() {
        //let tap = UITapGestureRecognizer(target: self, action: #selector(viewDidTap(_:)))
        //self.view.addGestureRecognizer(tap)
        self.nc.addObserver(self, selector: #selector(self.keyboardWillShow(notif:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        self.nc.addObserver(self, selector: #selector(self.keyboardWillHide(notif:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    func initData() {
        if self.frc == nil {
            if let _frc = self.localdb.getFetchResultsController(obj: EWorkspace.self) as? NSFetchedResultsController<EWorkspace> {
                self.frc = _frc
                self.frc.delegate = self
            }
        }
        self.reloadData()
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
    
    @objc func viewDidTap(_ recognizer: UITapGestureRecognizer) {
        Log.debug("view did tap")
        self.view.endEditing(true)
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
    
    @IBAction func addBtnDidTap(_ sender: Any) {
        Log.debug("add btn did tap")
        self.viewAlert(vc: self, storyboard: self.storyboard!)
    }
    
    @objc func settingsBtnDidTap(_ sender: Any) {
        Log.debug("settings button did tap")
    }
    
    func viewPopup() {
        self.app.viewPopupScreen(self, model: PopupModel(title: "New Project", iCloudSyncFieldEnabled: true, doneHandler: { model in
            Log.debug("model value: \(model.name) - \(model.desc)")
            self.addWorkspace(name: model.name, desc: model.desc, isSyncEnabled: model.iCloudSyncFieldEnabled)
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
        if let ws = self.localdb.createWorkspace(id: self.localdb.workspaceId(), index: AppState.totalworkspaces, name: name, desc: desc, isSyncEnabled: isSyncEnabled) {
            self.localdb.saveBackgroundContext()
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
        let wsSelected = self.app.getSelectedWorkspace()
        if ws.id != wsSelected.id {
            self.app.setSelectedWorkspace(ws)
            self.delegate?.workspaceDidChange(ws: ws)
        }
        self.dismiss(animated: true, completion: nil)
    }
}

extension WorkspaceListViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("workspace list frc did change: \(anObject)")
        if AppState.currentScreen != .workspaceList { return }
        DispatchQueue.main.async {
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
