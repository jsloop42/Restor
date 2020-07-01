//
//  EnvironmentPickerViewController.swift
//  Restor
//
//  Created by jsloop on 20/06/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import CoreData

extension Notification.Name {
    static let envDidSelect = Notification.Name(rawValue: "env-did-select")
}

class EnvPickerCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
}

class EnvironmentPickerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var navView: UIView!
    @IBOutlet weak var navTitleLabel: UILabel!
    @IBOutlet weak var doneBtn: UIButton!
    @IBOutlet weak var cancelBtn: UIButton!
    private lazy var localDB = { CoreDataService.shared }()
    private lazy var app = { App.shared }()
    var frc: NSFetchedResultsController<EEnv>!
    var selectedIndex: Int = -1
    var nc = NotificationCenter.default
    var env: EEnv?
    var ws: EWorkspace?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initUI()
        self.initData()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        if #available(iOS 13.0, *) {
            self.isModalInPresentation = true
        }
        self.view.backgroundColor = App.Color.tableViewBg
        self.navView.backgroundColor = App.Color.navBarBg
        self.navTitleLabel.backgroundColor = App.Color.navBarBg
        self.doneBtn.backgroundColor = App.Color.navBarBg
        self.cancelBtn.backgroundColor = App.Color.navBarBg
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 44
        self.tableView.delegate = self
        self.tableView.dataSource = self
    }

    func initData() {
        self.ws = self.app.getSelectedWorkspace()
        if let frc = self.localDB.getFetchResultsController(obj: EEnv.self, predicate: NSPredicate(format: "wsId == %@", self.ws!.getId())) as? NSFetchedResultsController<EEnv> {
            self.frc = frc
            self.frc.delegate = self
            try? self.frc.performFetch()
            self.tableView.reloadData()
        }
    }

    func updateData() {
        if self.frc == nil { return }
        self.frc.delegate = nil
        try? self.frc.performFetch()
        self.frc.delegate = self
        self.tableView.reloadData()
    }
    
    func close() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func doneDidTap(_ sender: Any) {
        Log.debug("done did tap")
        let env = self.selectedIndex >= 0 ? self.frc.object(at: IndexPath(row: self.selectedIndex, section: 0)) : nil
        self.nc.post(name: .envDidSelect, object: self, userInfo: ["index": self.selectedIndex, "env": env as Any])
        self.close()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let frc = self.frc else { return 0 }
        return frc.numberOfRows(in: section)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "envPickerCell", for: indexPath) as! EnvPickerCell
        let elem = self.frc.object(at: indexPath)
        cell.titleLabel.text = elem.getName()
        cell.accessoryType = .none
        let row = indexPath.row
        if self.selectedIndex >= 0 && row == self.selectedIndex {
            cell.accessoryType = .checkmark
        } else if self.env != nil {
            if elem.id == self.env!.getId() {
                cell.accessoryType = .checkmark
                self.selectedIndex = row
                self.env = nil
            }
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.selectedIndex == indexPath.row {
            self.selectedIndex = -1  // de-select
        } else {
            self.selectedIndex = indexPath.row
        }
        self.tableView.reloadData()
    }
}

extension EnvironmentPickerViewController: NSFetchedResultsControllerDelegate {
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("env picker list frc did change")
        DispatchQueue.main.async {
            if self.navigationController?.topViewController == self {
                self.tableView.reloadData()
                switch type {
                case .insert:
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.tableView.scrollToBottom(section: 0) }
                default:
                    break
                }
            }
        }
    }
}
