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
    private var workspace: Workspace?
    private weak var addItemPopupView: PopupView?
    private var popupBottomContraints: NSLayoutConstraint?
    private var isKeyboardActive = false
    private var keyboardHeight: CGFloat = 0.0
    private let utils: Utils = Utils.shared
    private let app: App = App.shared
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationItem.title = "Projects"
        self.navigationItem.leftBarButtonItem = self.app.addSettingsBarButton()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addBtnDidTap(_:)))
        self.updateUIState()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("project view did load")
        self.initUI()
        self.app.initDefaultWorspace()
        if let ws = AppState.currentWorkspace() {
            self.workspace = ws
            self.updateWorkspaceName()
        }
        // test
        self.addProject(name: "Test Project", desc: "My awesome project")
        // end test
    }
    
    func initUI() {
        Log.debug("init UI")
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.reloadData()
        // Fixes appearance of a translucent black background on the right during transition
        if #available(iOS 13.0, *) {
            self.navigationController?.view.backgroundColor = UIColor.systemBackground
        } else {
            self.navigationController?.view.backgroundColor = UIColor.white
        }
        // TODO: test
        self.addProject(name: "Test project", desc: "My awesome project")
        // end test
    }
    
    func updateUIState() {
        
    }
    
    @objc func workspaceDidTap() {
        Log.debug("workspace did tap")
    }
    
    func addProject(name: String, desc: String) {
        if let aWorkspace = self.workspace {
            let proj = Project(name: name, desc: desc, workspace: aWorkspace)
            aWorkspace.projects.append(proj)
            self.tableView.reloadData()
        }
    }
    
    func project(_ index: Int) -> Project? {
        if let aWorkspace = self.workspace, index < aWorkspace.projects.count {
            return aWorkspace.projects[index]
        }
        return nil
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
                popup.setNamePlaceholder("App server")
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
    
    func viewAlert(vc: UIViewController, storyboard: UIStoryboard, message: String? = nil, title: String? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "New Project", style: .default, handler: { action in
            Log.debug("new project did tap")
            self.viewPopup(type: .project)
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
        guard let popup = self.addItemPopupView else { return false }
        guard let text = text else {
            popup.viewValidationError("Please enter a name")
            return false
        }
        if text.isEmpty {
            popup.viewValidationError("Please enter a name")
            return false
        }
        if text.trimmingCharacters(in: .whitespaces) == "" {
            popup.viewValidationError("Please enter a valid name")
            return false
        }
        return true
    }
    
    func cancelDidTap(_ sender: Any) {
        Log.debug("cancel did tap")
        if let popup = self.addItemPopupView {
            popup.animateSlideOut {
                popup.nameTextField.text = ""
                popup.delegate = nil
                self.addItemPopupView = nil
                popup.removeFromSuperview()
            }
        }
    }

    func doneDidTap(_ sender: Any) -> Bool {
        Log.debug("done did tap")
        if let popup = self.addItemPopupView {
            if let name = popup.nameTextField.text {
                let desc = popup.descTextField.text
                self.addProject(name: name, desc: desc ?? "")
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
}


class ProjectCell: UITableViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var descLbl: UILabel!
}

extension ProjectViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let selectedIndex = AppState.selectedWorkspace, let aWorkspace = AppState.workspace(forIndex: selectedIndex) {
            self.workspace = aWorkspace
            return aWorkspace.projects.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableCellId.projectCell.rawValue, for: indexPath) as! ProjectCell
        cell.nameLbl.text = ""
        cell.descLbl.text = ""
        let row = indexPath.row
        if let project = self.project(row) {
            cell.nameLbl.text = project.name
            cell.descLbl.text = project.desc
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Log.debug("project cell did select \(indexPath.row)")
        UI.pushScreen(self.navigationController!, storyboardId: StoryboardId.requestListVC.rawValue)
    }
}

extension ProjectViewController: WorkspaceVCDelegate {
    func updateWorkspaceName() {
        self.workspaceBtn.setTitle(AppState.currentWorkspaceName(), for: .normal)
    }
}
