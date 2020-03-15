//
//  RequestListViewController.swift
//  Restor
//
//  Created by jsloop on 09/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class RequestListViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var filterBtn: UIBarButtonItem!
    @IBOutlet weak var windowBtn: UIBarButtonItem!
    @IBOutlet weak var addBtn: UIBarButtonItem!
    private var requests: [ERequest] = []
    private let utils: Utils = Utils.shared
    private let app: App = App.shared
    private let localdb = CoreDataService.shared
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.activeScreen = .requestListing
        self.navigationItem.title = "Requests"
        self.updateData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initUI()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addBtnDidTap(_:)))
    }
    
    func updateData() {
        if let ws = AppState.currentWorkspace, let ctx = ws.managedObjectContext, let proj = AppState.currentProject, let projId = proj.id {
            self.requests = self.localdb.getRequests(projectId: projId, ctx: ctx)
        }
        self.tableView.reloadData()
    }
    
    @objc func addBtnDidTap(_ sender: Any) {
        Log.debug("add btn did tap")
        self.viewEditRequestVC(false)
    }
    
    func viewEditRequestVC(_ isUpdate: Bool, index: Int? = 0) {
        Log.debug("view edit request vc")
        var isDisplay = false
        if isUpdate {
            if let idx = index { AppState.editRequest = self.requests[idx]; isDisplay = true }
        } else {
            if AppState.editRequest == nil {
                let (name, idx) = self.app.getNewRequestNameWithIndex()
                AppState.editRequest = self.localdb.createRequest(id: self.utils.genRandomString(), index: idx, name: name)
                isDisplay = true
            }
        }
        if isDisplay {
            UI.pushScreen(self.navigationController!, storyboardId: StoryboardId.editRequestVC.rawValue)
        } else {
            // TODO: display error alert
        }
    }
}

class RequestCell: UITableViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var descLbl: UILabel!
}

extension RequestListViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.requests.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableCellId.requestCell.rawValue, for: indexPath) as! RequestCell
        let row = indexPath.row
        cell.nameLbl.text = ""
        cell.descLbl.text = ""
        if row < self.requests.count {
            let req = self.requests[row]
            cell.nameLbl.text = req.name
            cell.descLbl.text = req.desc
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.viewEditRequestVC(true, index: indexPath.row)
    }
}
