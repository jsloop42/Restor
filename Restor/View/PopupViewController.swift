//
//  PopupViewController.swift
//  Restor
//
//  Created by jsloop on 20/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

/// The model for the popup view controller
struct PopupModel {
    var title: String
    var name = ""
    var desc = ""
    /// Display description field
    var descFieldEnabled = true
    /// Display iCloud sync switch field
    var iCloudSyncFieldEnabled = false
    /// Will be invoked with the updated model values from the popup
    var doneHandler: (PopupModel) -> Void
}

class PopupCell: UITableViewCell {
    @IBOutlet weak var nameView: UIView!
    @IBOutlet weak var descView: UIView!
    @IBOutlet weak var syncView: UIView!
    @IBOutlet weak var nameTextField: UITextField!  // Name
    @IBOutlet weak var descTextField: UITextField!  // Description
    @IBOutlet weak var iCloudSyncSwitch: UISwitch!  // iCloud Sync
}

/// Popup screen for getting user input values
class PopupViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var navbarView: UIView!
    @IBOutlet weak var doneBtn: UIButton!
    @IBOutlet weak var cancelBtn: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var tableView: UITableView!
    var model: PopupModel?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initUI()
        self.initEvent()
    }
    
    func initUI() {
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        if #available(iOS 13.0, *) { self.isModalInPresentation = true }  // Prevent dismissing popup by swiping down
        self.doneBtn.isEnabled = false
        self.titleLabel.text = self.model?.title
    }
    
    func initEvent() {
        // End editing on view tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.endEditing))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
    }
    
    func close() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func endEditing() {
        UI.endEditing()
    }
    
    @IBAction func cancelButtonDidTap(_ sender: Any) {
        self.close()
    }
    
    @IBAction func doneButtonDidTap(_ sender: Any) {
        if var model = self.model, let cell = self.tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? PopupCell {
            model.name = cell.nameTextField.text ?? ""
            model.desc = cell.descTextField.text ?? ""
            model.doneHandler(model)
        }
        self.close()
    }
    
    func updateCellUI(_ cell: PopupCell) {
        guard let model = self.model else { return }
        cell.descView.isHidden = !model.descFieldEnabled
        cell.syncView.isHidden = !model.iCloudSyncFieldEnabled
    }
    
    func initCellEvents(_ cell: PopupCell) {
        cell.nameTextField.addTarget(self, action: #selector(self.textFieldDidChange(_:)), for: .editingChanged)
    }
        
    @objc func textFieldDidChange(_ textField: UITextField) {
        let text = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.doneBtn.isEnabled = !text.isEmpty
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "popupCell", for: indexPath) as! PopupCell
        self.updateCellUI(cell)
        self.initCellEvents(cell)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 206
        guard let model = self.model else { return height }
        if !model.iCloudSyncFieldEnabled { height -= 50 }
        if !model.descFieldEnabled { height -= 50 }
        return height
    }
}
