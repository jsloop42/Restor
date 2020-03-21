//
//  ViewController.swift
//  Restor
//
//  Created by jsloop on 02/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import UIKit

protocol WorkspaceVCDelegate: class {
    func updateWorkspaceName()
}

class WorkspaceViewController: UIViewController {
    static weak var shared: WorkspaceViewController?
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addBtn: UIBarButtonItem!
    private var popupBottomContraints: NSLayoutConstraint?
    private var isKeyboardActive = false
    private var keyboardHeight: CGFloat = 0.0
    private let utils: Utils = Utils.shared
    private let app: App = App.shared
    weak var delegate: WorkspaceVCDelegate?
    private let nc = NotificationCenter.default
    private let localdb = CoreDataService.shared
    private var workspaces: [EWorkspace] = []
    private var shouldFetchMore = true
    private var isDataLoading = false
    private var offset = Const.paginationOffset
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        WorkspaceViewController.shared = self
        AppState.activeScreen = .workspaceListing
        self.navigationItem.title = "Workspaces"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.getData()
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
        self.app.viewPopupScreen(self, model: PopupModel(title: "New Project", doneHandler: { model in
            Log.debug("model value: \(model.name) - \(model.desc)")
            self.addWorkspace(name: model.name, desc: model.desc)
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
    
    func addWorkspace(name: String, desc: String) {
        AppState.totalworkspaces = self.localdb.getWorkspaceCount()
        _ = self.localdb.createWorkspace(id: name, index: AppState.totalworkspaces, name: name, desc: desc)
        self.tableView.reloadData()
    }
    
    func getData() {
//        if !self.isDataLoading {
//            self.localdb.getWorkspaces(offset: self.offset, limit: Const.fetchLimit, completion: { result in
//                self.isDataLoading = false
//                switch result {
//                case .success(let wxs):
//                    self.workspaces
//                    self.workspaces = wxs
//                    self.offset += Const.fetchLimit
//                    self.tableView.reloadData()
//                case .failure(let error):
//                    self.app.viewError(error, vc: self)
//                }
//            })
//            self.isDataLoading = true
//        }
    }
}

extension WorkspaceViewController: PopupViewDelegate {
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
        self.displayAddButton()
        if let popup = self.app.addItemPopupView {
            popup.animateSlideOut {
                popup.nameTextField.text = ""
                popup.removeFromSuperview()
            }
        }
    }

    func doneDidTap(name: String, desc: String) -> Bool {
        Log.debug("done did tap")
        if let popup = self.app.addItemPopupView {
            if !name.isEmpty {
                //self.createNewWorkspace(name: name, desc: desc)
                popup.animateSlideOut {
                    popup.nameTextField.text = ""
                    popup.removeFromSuperview()
                    self.displayAddButton()
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

class WorkspaceCell: UITableViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var descLbl: UILabel!
}

extension WorkspaceViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AppState.workspaces.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableCellId.workspaceCell.rawValue, for: indexPath) as! WorkspaceCell
        let row = indexPath.row
        cell.nameLbl.text = ""
        cell.descLbl.text = ""
        
        
        if let workspace = AppState.workspace(forIndex: row) {
            cell.nameLbl.text = workspace.name
            cell.descLbl.text = workspace.desc
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("workspace cell did select \(indexPath.row)")
        AppState.selectedWorkspace = indexPath.row
        self.delegate?.updateWorkspaceName()
        self.dismiss(animated: true, completion: nil)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
//        self.getData()
    }
}
