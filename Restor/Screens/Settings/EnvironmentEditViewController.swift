//
//  EnvironmentEditViewController.swift
//  Restor
//
//  Created by jsloop on 15/06/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

extension Notification.Name {
    static let envEditCellTextDidChange = Notification.Name("env-edit-cell-text-did-change")
    static let envEditCellGetVCMode = Notification.Name("env-edit-cell-get-vc-mode")
    static let envEditVCMode = Notification.Name("env-edit-vc-mode")
}

class EnvEditCell: UITableViewCell, UITextFieldDelegate {
    @IBOutlet weak var textField: EATextField!
    private let nc = NotificationCenter.default
    var mode: EnvironmentEditViewController.Mode = .addEnv
    var cellType: CellType = .name

    enum CellType: Int {
        case name
        case value
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.initUI()
        self.initEvents()
    }
    
    func initUI() {
        self.textField.isColor = false
        self.textField.delegate = self
    }
    
    func initEvents() {
        self.textField.addTarget(self, action: #selector(EnvEditCell.textFieldDidChange(_:)), for: .editingChanged)
    }
    
    func updateUI() {
        switch self.mode {
        case .addEnv, .addEnvVar:
            self.textField.isUserInteractionEnabled = true
        case .editEnv, .editEnvVar:
            self.textField.isUserInteractionEnabled = true
        case .viewEnv, .viewEnvVar:
            self.textField.isUserInteractionEnabled = false
        }
    }
    
    @objc func textFieldDidChange(_ sender: Any) {
        Log.debug("text field did change")
        self.nc.post(name: .envEditCellTextDidChange, object: self, userInfo: ["text": self.textField.text ?? "", "type": self.cellType])
    }
}

class EnvironmentEditViewController: UITableViewController, UITextFieldDelegate {
    @IBOutlet weak var nameCell: EnvEditCell!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var valueCell: EnvEditCell!
    @IBOutlet weak var doneBtn: UIButton!
    @IBOutlet weak var cancelBtn: UIButton!
    var mode: Mode = .addEnv
    private lazy var localDB = { CoreDataService.shared }()
    private lazy var db = { PersistenceService.shared }()
    private lazy var app = { App.shared }()
    private let nc = NotificationCenter.default
    var name = ""
    var value = ""
    var backBtnItem: UIBarButtonItem?
    var env: EEnv?
    var envVar: EEnvVar?
    var addok = false
    var editok = false
    
    deinit {
        Log.debug("deinit EnvironmentEditViewController")
        self.nc.removeObserver(self)
    }
    
    enum Mode {
        case addEnv
        case editEnv
        case viewEnv
        case addEnvVar
        case editEnvVar
        case viewEnvVar
    }
    
    enum CellId: Int {
        case navViewCell
        case nameTitleCell
        case nameCell
        case valueTitleCell
        case valueCell
        case spacerCell
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateUI()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("env edit vc")
        self.initUI()
        self.initEvents()
    }
    
    func initUI() {
        if #available(iOS 13.0, *) {
            self.isModalInPresentation = true
        }
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.app.updateViewBackground(self.view)
        self.view.backgroundColor = App.Color.tableViewBg
        self.nameCell.cellType = .name
        self.valueCell.cellType = .value
        switch self.mode {
        case .addEnv:
            self.titleLabel.text = "Add Environment"
            self.nameCell.textField.returnKeyType = .default
        case .editEnv:
            self.titleLabel.text = "Edit Environment"
            self.nameCell.textField.returnKeyType = .default
            self.name = self.env?.name ?? ""
            self.editok = true
        case .viewEnv:
            self.titleLabel.text = ""
        case .addEnvVar:
            self.titleLabel.text = "Add Variable"
            self.nameCell.textField.placeholder = "server-url"
            self.nameCell.textField.returnKeyType = .next
            self.valueCell.textField.returnKeyType = .default
        case .editEnvVar:
            self.titleLabel.text = "Edit Variable"
            self.nameCell.textField.returnKeyType = .next
            self.valueCell.textField.returnKeyType = .default
            self.name = self.envVar?.name ?? ""
            self.value = self.envVar?.value as? String ?? ""
            self.editok = true
        case .viewEnvVar:
            self.titleLabel.text = ""
        }
        self.nameCell.textField.delegate = self
        self.valueCell.textField.delegate = self
        self.disableDoneButton()
    }
    
    func close() {
        self.dismiss(animated: true, completion: nil)
    }

    func saveEnv() {
        self.localDB.saveMainContext()
        self.db.saveEnvToCloud(self.env!)
    }

    func saveEnvVar() {
        self.localDB.saveMainContext()
        self.db.saveEnvVarToCloud(self.envVar!)
    }

    @objc func doneDidTap(_ sender: Any) {
        Log.debug("done btn did tap")
        let wsId = self.app.getSelectedWorkspace().getId()
        switch self.mode {
        case .addEnv:
            self.env = self.localDB.createEnv(name: self.name, wsId: wsId)
            self.saveEnv()
        case .editEnv:
            self.env?.name = self.name
            self.saveEnv()
        case .addEnvVar:
            self.envVar = self.localDB.createEnvVar(name: self.name, value: self.value)
            self.envVar?.env = self.env
            self.saveEnvVar()
        case .editEnvVar:
            self.envVar?.name = self.name
            self.envVar?.value = self.value as NSString
            self.saveEnvVar()
        default:
            break
        }
        self.close()
    }
    
    @objc func cancelDidTap(_ sender: Any) {
        Log.debug("cancel did tap")
        self.close()
    }
    
    func enableDoneButton() {
        UIView.animate(withDuration: 0.3) {
            self.doneBtn.setTitleColor(self.doneBtn.tintColor, for: .normal)
            self.doneBtn.isEnabled = true
        }
    }
    
    func disableDoneButton() {
        UIView.animate(withDuration: 0.3) {
            self.doneBtn.setTitleColor(App.Color.requestEditDoneBtnDisabled, for: .normal)
            self.doneBtn.isEnabled = false
        }
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.envEditCellTextDidChange(_:)), name: .envEditCellTextDidChange, object: nil)
        self.doneBtn.addTarget(self, action: #selector(self.doneDidTap(_:)), for: .touchDown)
        self.cancelBtn.addTarget(self, action: #selector(self.cancelDidTap(_:)), for: .touchDown)
    }
    
    func updateUI() {
        if self.mode == .viewEnv || self.mode == .editEnv {
            self.nameCell.textField.text = self.env != nil ? self.env!.name : self.name
        } else if self.mode == .viewEnvVar || self.mode == .editEnvVar {
            if self.envVar != nil {
                self.nameCell.textField.text = self.envVar!.name
                self.valueCell.textField.text = self.envVar!.value as? String ?? ""
            } else {
                self.nameCell.textField.text = self.name
                self.valueCell.textField.text = self.value
            }
        }
        self.nameCell.mode = self.mode
        self.valueCell.mode = self.mode
        self.nameCell.updateUI()
        if self.mode == .viewEnvVar || self.mode == .addEnvVar || self.mode == .editEnvVar {
            self.valueCell.updateUI()
        }
    }
    
    @objc func envEditCellTextDidChange(_ notif: Notification) {
        Log.debug("env edit cell text did change notification")
        if let info = notif.userInfo as? [String: Any], let text = info["text"] as? String {
            let type = info["type"] as? EnvEditCell.CellType == EnvEditCell.CellType.name ? EnvEditCell.CellType.name : EnvEditCell.CellType.value
            self.addok = false
            self.editok = false
            if text.isEmpty {
                self.disableDoneButton()
                return
            }
            switch self.mode {
            case .addEnv:
                self.name = text
                self.addok = true
            case .editEnv:
                self.name = text
                if let name = self.env?.name, name != text { self.editok = true }
            case .addEnvVar:
                type == .name ? (self.name = text) : (self.value = text)
                if !self.name.isEmpty && !self.value.isEmpty { self.addok = true }
            case .editEnvVar:
                type == .name ? (self.name = text) : (self.value = text)
                if self.envVar != nil {
                    if self.envVar!.name != self.name || self.envVar!.value as! String != self.value {
                        self.editok = true
                    }
                }
            default:
                break
            }
        }
        if (self.mode == .addEnv || self.mode == .addEnvVar) && self.addok {
            self.enableDoneButton()
        } else if (self.mode == .editEnv || self.mode == .editEnvVar) && self.editok {
            self.enableDoneButton()
        } else {
            self.disableDoneButton()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField.tag == 0 {
            self.valueCell.textField.becomeFirstResponder()
        } else if textField.tag == 1 {
            textField.resignFirstResponder()
        }
        return false  // Do not add a line break
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 6
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = indexPath.row
        if row == 5 { return 24 }
        switch self.mode {
        case .addEnv, .editEnv, .viewEnv:
            if row == 3 || row == 4 { return 0 }
            return 44
        case .addEnvVar, .editEnvVar, .viewEnvVar:
            return 44
        }
    }
}
