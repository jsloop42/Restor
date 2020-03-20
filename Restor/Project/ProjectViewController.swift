//
//  ProjectViewController.swift
//  Restor
//
//  Created by jsloop on 09/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class ProjectViewController: UIViewController {
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var workspaceBtn: UIButton!
    private var workspace: EWorkspace?
    private weak var addItemPopupView: PopupView?
    private var popupBottomContraints: NSLayoutConstraint?
    private var isKeyboardActive = false
    private var keyboardHeight: CGFloat = 0.0
    private let utils: Utils = Utils.shared
    private let app: App = App.shared
    private let nc = NotificationCenter.default
    private let localdb = CoreDataService.shared
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.activeScreen = .projectListing
        self.navigationItem.title = "Projects"
        self.navigationItem.leftBarButtonItem = self.addSettingsBarButton()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addBtnDidTap(_:)))
        self.updateUIState()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("project view did load")
        if !isRunningTests {
            self.app.bootstrap()
            self.initUI()
            self.initEvent()
            self.workspace = AppState.getCurrentWorkspace()
            self.updateWorkspaceName()
            self.tableView.reloadData()
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
    }
    
    func updateUIState() {
        
    }
    
    func addSettingsBarButton() -> UIBarButtonItem {
        if #available(iOS 13.0, *) {
            return UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(self.settingsButtonDidTap(_:)))
        }
        return UIBarButtonItem(image: UIImage(), style: .plain, target: self, action: #selector(self.settingsButtonDidTap(_:)))
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
        if let ws = self.workspace, let ctx = ws.managedObjectContext {
            let projCount = ws.projects?.count ?? 0
            if let proj = self.localdb.createProject(id: self.utils.genRandomString(), index: projCount, name: name, desc: desc, ws: ws, ctx: ctx) {
                proj.workspace = ws
                self.localdb.saveBackgroundContext()
            }
            self.tableView.reloadData()
        }
    }
    
    func getProject(at index: Int) -> EProject? {
        if let ws = self.workspace, let wsId = ws.id, let ctx = ws.managedObjectContext {
            return self.localdb.getProject(at: index, wsId: wsId, ctx: ctx)
        }
        return nil
    }
    
    @objc func addBtnDidTap(_ sender: Any) {
        Log.debug("add button did tap")
        self.viewAlert(vc: self, storyboard: self.storyboard!)
    }
    
    @IBAction func workspaceDidTap(_ sender: Any) {
        Log.debug("workspace did tap")
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "workspaceSegue" {
            if let vc = segue.destination as? WorkspaceViewController {
                vc.delegate = self
            }
        }
    }
    
    func viewPopup() {
        self.app.viewPopupScreen(self, model: PopupModel(title: "New Project", doneHandler: { model in
            Log.debug("model value: \(model.name) - \(model.desc)")
        }))
    }
    
    func viewAlert(vc: UIViewController, storyboard: UIStoryboard, message: String? = nil, title: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "New Project", style: .default, handler: { action in
            Log.debug("new project did tap")
            alert.dismiss(animated: true) { self.viewPopup() }
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

extension ProjectViewController: PopupViewDelegate {
    func validateText(_ text: String?) -> Bool {
        guard let text = text else {
            self.app.addItemPopupView?.viewValidationError("Please enter a name")
            self.app.addItemPopupView?.updatePopupConstraints(self.view, isErrorMode: true)
            return false
        }
        if text.isEmpty {
            self.app.addItemPopupView?.viewValidationError("Please enter a name")
            self.app.addItemPopupView?.updatePopupConstraints(self.view, isErrorMode: true)
            return false
        }
        if text.trimmingCharacters(in: .whitespaces) == "" {
            self.app.addItemPopupView?.viewValidationError("Please enter a valid name")
            self.app.addItemPopupView?.updatePopupConstraints(self.view, isErrorMode: true)
            return false
        }
        self.app.addItemPopupView?.updatePopupConstraints(self.view, isErrorMode: false)
        return true
    }
    
    func cancelDidTap(_ sender: Any) {
        Log.debug("cancel did tap")
        if let popup = self.app.addItemPopupView {
            popup.animateSlideOut {
                popup.nameTextField.text = ""
                popup.delegate = nil
                self.addItemPopupView = nil
                popup.removeFromSuperview()
            }
        }
    }

    func doneDidTap(name: String, desc: String) -> Bool {
        Log.debug("done did tap")
        if let popup = self.app.addItemPopupView {
            if !name.isEmpty {
                self.addProject(name: name, desc: desc)
                self.tableView.reloadData()
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
    
    func popupStateDidChange(isErrorMode: Bool) {
        self.app.addItemPopupView?.updatePopupConstraints(self.view, isErrorMode: isErrorMode)
    }
}


class ProjectCell: UITableViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var descLbl: UILabel!
}

extension ProjectViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let aWorkspace = AppState.workspace(forIndex: AppState.selectedWorkspace) {
            self.workspace = aWorkspace
            return aWorkspace.projects?.count ?? 0
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableCellId.projectCell.rawValue, for: indexPath) as! ProjectCell
        cell.nameLbl.text = ""
        cell.descLbl.text = ""
        let row = indexPath.row
        if let project = self.getProject(at: row) {
            cell.nameLbl.text = project.name
            cell.descLbl.text = project.desc
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("project cell did select \(indexPath.row)")
        if let ws = AppState.currentWorkspace, let wsId = ws.id, let ctx = ws.managedObjectContext {
            AppState.currentProject = self.localdb.getProject(at: indexPath.row, wsId: wsId, ctx: ctx)
        }
        UI.pushScreen(self.navigationController!, storyboardId: StoryboardId.requestListVC.rawValue)
    }
}

extension ProjectViewController: WorkspaceVCDelegate {
    func updateWorkspaceName() {
        self.workspaceBtn.setTitle(AppState.currentWorkspaceName(), for: .normal)
        self.tableView.reloadData()
    }
}
