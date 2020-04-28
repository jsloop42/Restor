//
//  RequestListViewController.swift
//  Restor
//
//  Created by jsloop on 09/12/19.
//  Copyright © 2019 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class RequestListViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var filterBtn: UIBarButtonItem!
    @IBOutlet weak var windowBtn: UIBarButtonItem!
    @IBOutlet weak var addBtn: UIBarButtonItem!
    private let utils = EAUtils.shared
    private let app: App = App.shared
    private let localdb = CoreDataService.shared
    private var frc: NSFetchedResultsController<ERequest>!
    private let cellReuseId = "requestCell"
    private let db = PersistenceService.shared
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.setCurrentScreen(.requestList)
        self.navigationItem.title = "Requests"
        self.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initUI()
        self.initData()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addBtnDidTap(_:)))
    }
    
    func initData() {
        if self.frc == nil, let projId = AppState.currentProject?.id {
            let predicate = NSPredicate(format: "project.id == %@", projId)
            if let _frc = self.localdb.getFetchResultsController(obj: ERequest.self, predicate: predicate, ctx: self.localdb.mainMOC) as? NSFetchedResultsController<ERequest> {
                self.frc = _frc
                self.frc.delegate = self
            }
        }
        self.reloadData()
    }
    
    func reloadData() {
        if self.frc == nil { return }
        do {
            try self.frc.performFetch()
            self.tableView.reloadData()
        } catch let error {
            Log.error("Error fetching: \(error)")
        }
    }
    
    @objc func addBtnDidTap(_ sender: Any) {
        Log.debug("add btn did tap")
        self.viewEditRequestVC(false)
    }
    
    func viewEditRequestVC(_ isUpdate: Bool, indexPath: IndexPath? = nil) {
        Log.debug("view edit request vc")
        var isDisplay = true
        if isUpdate, let idxPath = indexPath {
            AppState.editRequest = self.frc.object(at: idxPath)
        } else {
            if AppState.editRequest == nil {
                let name = self.app.getNewRequestName()
                if let proj = AppState.currentProject, let wsId = proj.workspace?.getId(),
                    let req = self.localdb.createRequest(id: self.localdb.requestId(), wsId: wsId, name: name, ctx: self.localdb.mainMOC) {
                    AppState.editRequest = req
                    AppState.currentProject?.addToRequests(req)
                } else {
                    isDisplay = false
                }
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
        return self.frc.numberOfRows(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: self.cellReuseId, for: indexPath) as! RequestCell
        let req = self.frc.object(at: indexPath)
        cell.nameLbl.text = req.name
        cell.descLbl.text = req.desc
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.viewEditRequestVC(true, indexPath: indexPath)
    }
}

extension RequestListViewController: NSFetchedResultsControllerDelegate {
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("requests list frc did change: \(anObject)")
        if AppState.currentScreen != .requestList { return }
        DispatchQueue.main.async {
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
