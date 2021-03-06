//
//  EnvironmentVariableTableViewController.swift
//  Restor
//
//  Created by jsloop on 16/06/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class EnvVarCell: UITableViewCell {
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var valueLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
}

class EnvironmentVariableTableViewController: UITableViewController {
    private let app = App.shared
    private lazy var localDB = { CoreDataService.shared }()
    private lazy var db = { PersistenceService.shared }()
    var env: EEnv?
    var frc: NSFetchedResultsController<EEnvVar>!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.setCurrentScreen(.envVar)
        self.updateData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("env var table view controller - view did load")
        self.initUI()
        self.initData()
    }
    
    func initUI() {
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.app.updateViewBackground(self.view)
        self.view.backgroundColor = App.Color.tableViewBg
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.navigationItem.title = "Variables"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addBtnDidTap(_:)))
    }
    
    func initData() {
        guard self.frc == nil, let envId = self.env?.getId() else { return }
        if let _frc = self.localDB.getFetchResultsController(obj: EEnvVar.self, predicate: NSPredicate(format: "env.id == %@ AND markForDelete == %hhd", envId, false), ctx: self.localDB.mainMOC) as? NSFetchedResultsController<EEnvVar> {
            self.frc = _frc
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
    
    @objc func addBtnDidTap(_ sender: Any) {
        Log.debug("add button did tap")
        if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.envEditVC.rawValue) as? EnvironmentEditViewController {
            vc.mode = .addEnvVar
            vc.env = self.env
            self.present(vc, animated: true, completion: nil)
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if self.frc == nil { return 0 }
        return self.frc.numberOfRows(in: 0)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "envVarCell", for: indexPath) as! EnvVarCell
        let envVar = self.frc.object(at: indexPath)
        cell.nameLabel.text = envVar.name
        cell.valueLabel.text = envVar.value as? String
        return cell
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let edit = UIContextualAction(style: .normal, title: "Edit") { action, view, completion in
            Log.debug("edit row: \(indexPath)")
            let envVar = self.frc.object(at: indexPath)
            if let vc = self.storyboard?.instantiateViewController(withIdentifier: StoryboardId.envEditVC.rawValue) as? EnvironmentEditViewController {
                vc.envVar = envVar
                vc.mode = .editEnvVar
                self.navigationController?.present(vc, animated: true, completion: nil)
                completion(true)
            } else {
                completion(false)
            }
        }
        edit.backgroundColor = App.Color.lightPurple
        let delete = UIContextualAction(style: .destructive, title: "Delete") { action, view, completion in
            Log.debug("delete row: \(indexPath)")
            let envVar = self.frc.object(at: indexPath)
            envVar.markForDelete = true
            self.localDB.saveMainContext()
            self.db.deleteDataMarkedForDelete(envVar, ctx: self.localDB.mainMOC)
            self.updateData()
            completion(true)
        }
        let swipeActionConfig = UISwipeActionsConfiguration(actions: [delete, edit])
        swipeActionConfig.performsFirstActionWithFullSwipe = false
        return swipeActionConfig
    }
}

extension EnvironmentVariableTableViewController: NSFetchedResultsControllerDelegate {
    public func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("env var list frc did change")
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
