//
//  RequestViewController.swift
//  Restor
//
//  Created by jsloop on 09/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation
import UIKit

class RequestViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var filterBtn: UIBarButtonItem!
    @IBOutlet weak var windowBtn: UIBarButtonItem!
    @IBOutlet weak var addBtn: UIBarButtonItem!
    private var requests: [Request] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initUI()
    }
    
    func initUI() {
        if let idx = State.selectedProject, let projects = State.project(forIndex: idx) {
            self.requests = projects.requests
        }
        self.tableView.reloadData()
    }
}

class RequestCell: UITableViewCell {
    @IBOutlet weak var nameLbl: UILabel!
    @IBOutlet weak var descLbl: UILabel!
}

extension RequestViewController: UITableViewDelegate, UITableViewDataSource {
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
}
