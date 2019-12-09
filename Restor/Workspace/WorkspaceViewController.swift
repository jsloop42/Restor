//
//  ViewController.swift
//  Restor
//
//  Created by jsloop on 02/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import UIKit

class WorkspaceViewController: UIViewController {
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var tableView: UITableView!
    private var addItemPopupView: PopupView?
    private var popupBottomContraints: NSLayoutConstraint?
    private var isKeyboardActive = false
    private var keyboardHeight: CGFloat = 0.0
    private let utils: Utils = Utils.shared
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        State.selectedWorkspace = nil
        self.navigationItem.title = "Workspaces"
        self.navigationItem.rightBarButtonItem = self.utils.addSettingsBarButton()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initUI()
        self.initEvents()
    }

    func initUI() {
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.reloadData()
        // TODO: test
        self.createNewWorkspace(name: "Test workspace", desc: "Test workspace desc")
        // end test
    }
    
    func initEvents() {
        //let tap = UITapGestureRecognizer(target: self, action: #selector(viewDidTap(_:)))
        //self.view.addGestureRecognizer(tap)
    }
    
    @objc func viewDidTap(_ recognizer: UITapGestureRecognizer) {
        Log.debug("view did tap")
        self.view.endEditing(true)
    }
    
    @IBAction func addBtnDidTap(_ sender: Any) {
        Log.debug("add btn did tap")
        self.viewAlert(vc: self, storyboard: self.storyboard!)
    }
    
    @objc func settingsBtnDidTap(_ sender: Any) {
        Log.debug("settings button did tap")
    }
    
    func viewAlert(vc: UIViewController, storyboard: UIStoryboard, message: String? = nil, title: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "New Workspace", style: .default, handler: { action in
            Log.debug("new workspace did tap")
            self.viewPopup(type: .workspace)
        }))
        alert.modalPresentationStyle = .popover
        if let popoverPresentationController = alert.popoverPresentationController {
            popoverPresentationController.sourceView = vc.view
            popoverPresentationController.sourceRect = vc.view.bounds
            popoverPresentationController.permittedArrowDirections = []
        }
        vc.present(alert, animated: true, completion: nil)
    }
    
    func updateConstraints() {
        let bottom: CGFloat = 0
        if let popup = self.addItemPopupView {
            self.popupBottomContraints?.isActive = false
            if self.isKeyboardActive {
                self.popupBottomContraints = popup.bottomAnchor.constraint(equalTo: self.toolbar.topAnchor,
                                                                           constant: -self.keyboardHeight+bottom)
            } else {
                self.popupBottomContraints = popup.bottomAnchor.constraint(equalTo: self.toolbar.topAnchor, constant: bottom)
            }
            self.popupBottomContraints?.isActive = true
        }
    }
    
    func viewPopup(type: PopupType) {
        if self.addItemPopupView == nil, let popup = PopupView.initFromNib(owner: self) as? PopupView {
            popup.delegate = self
            popup.nameTextField.delegate = popup
            popup.type = type
            popup.alpha = 0.0
            self.view.addSubview(popup)
            popup.animateSlideIn()
            if type == .workspace {
                popup.setTitle("New Workspace")
                popup.setNamePlaceholder("My personal workspace")
                popup.setDescriptionPlaceholder("API tests for my personal projects")
            } else if type == .project {
                popup.setTitle("New Project")
                popup.setNamePlaceholder("API server")
                popup.setDescriptionPlaceholder("APIs for my app server")
            }
            popup.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                popup.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor, constant: 0),
                popup.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: 0),
                popup.heightAnchor.constraint(equalToConstant: 207)
            ])
            self.addItemPopupView = popup
            self.updateConstraints()
        }
    }
    
    func createNewWorkspace(name: String, desc: String) {
        let ws = Workspace(name: name, desc: desc)
        State.workspaces.append(ws)
        self.tableView.reloadData()
    }
}

extension WorkspaceViewController: PopupViewDelegate {
    func cancelDidTap(_ sender: Any) {
        Log.debug("cancel did tap")
        if let popup = self.addItemPopupView {
            popup.animateSlideOut {
                popup.nameTextField.text = ""
                popup.removeFromSuperview()
                self.addItemPopupView = nil
            }
        }
    }

    func doneDidTap(_ sender: Any) -> Bool {
        Log.debug("done did tap")
        if let popup = self.addItemPopupView {
            if let name = popup.nameTextField.text {
                if name.isEmpty {
                    popup.viewValidationError("Please enter a name")
                    return false
                }
                if name.trimmingCharacters(in: .whitespaces) == "" {
                    popup.viewValidationError("Please enter a valid name")
                    return false
                }
                let name = popup.nameTextField.text
                let desc = popup.descTextField.text
                self.createNewWorkspace(name: name!, desc: desc ?? "")
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
}

class WorkspaceCell: UITableViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var descLbl: UILabel!
}

extension WorkspaceViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return State.workspaces.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableCellId.workspaceCell.rawValue, for: indexPath) as! WorkspaceCell
        let row = indexPath.row
        cell.nameLbl.text = ""
        cell.descLbl.text = ""
        if let workspace = State.workspace(forIndex: row) {
            cell.nameLbl.text = workspace.name
            cell.descLbl.text = workspace.desc
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("workspace cell did select \(indexPath.row)")
        State.selectedWorkspace = indexPath.row
        UI.pushScreen(self.navigationController!, storyboardId: StoryboardId.projectVC.rawValue)
    }
}
