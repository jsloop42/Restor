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
    private let utils: Utils = Utils.shared
    private let app: App = App.shared
    private let localdb = CoreDataService.shared
    private var frc: NSFetchedResultsController<ERequest>!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.activeScreen = .requestListing
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
            if let _frc = self.localdb.getFetchResultsController(obj: ERequest.self, predicate: predicate) as? NSFetchedResultsController<ERequest> {
                self.frc = _frc
                self.frc.delegate = self
            }
        }
        self.reloadData()
        self.tableView.reloadData()
    }
    
    func reloadData() {
        if self.frc == nil { return }
        do {
            try self.frc.performFetch()
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
                let (name, idx) = self.app.getNewRequestNameWithIndex()
                if let ctx = AppState.currentProject?.managedObjectContext,
                    let req = self.localdb.createRequest(id: self.utils.genRandomString(), index: idx, name: name, ctx: ctx) {
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

extension NSFetchedResultsController {
    @objc func numberOfSections() -> Int {
        return self.sections?.count ?? 0
    }
    
    @objc func numberOfRows(in section: Int) -> Int {
        if let xs = self.sections, xs.count > section { return xs[section].numberOfObjects }
        return 0
    }
}

extension RequestListViewController: UITableViewDelegate, UITableViewDataSource, NSFetchedResultsControllerDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.frc.numberOfRows(in: section)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TableCellId.requestCell.rawValue, for: indexPath) as! RequestCell
        let req = self.frc.object(at: indexPath)
        cell.nameLbl.text = req.name
        cell.descLbl.text = req.desc
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.viewEditRequestVC(true, indexPath: indexPath)
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        Log.debug("requests list frc did change")    
        switch type {
        case .delete:
            DispatchQueue.main.async { self.tableView.deleteRows(at: [indexPath!], with: .automatic) }
        case .insert:
            DispatchQueue.main.async {
                self.tableView.beginUpdates()
                self.tableView.insertRows(at: [newIndexPath!], with: .none)
                self.tableView.endUpdates()
                self.tableView.layoutIfNeeded()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { self.tableView.scrollToBottom(section: 0) }
            }
        case .update:
            DispatchQueue.main.async { self.tableView.reloadRows(at: [indexPath!], with: .none) }
        default:
            break
        }
    }
}
