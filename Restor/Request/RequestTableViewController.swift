//
//  RequestTableViewController.swift
//  Restor
//
//  Created by jsloop on 04/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class RequestTableViewController: UITableViewController {
    private let app = App.shared
    private let localdb = CoreDataService.shared
    private let utils = EAUtils.shared
    var request: ERequest?
    private var tabbarController: RequestTabBarController { self.tabBarController as! RequestTabBarController }
    @IBOutlet var headerKVTableViewManager: KVTableViewManager!
    @IBOutlet var paramsKVTableViewManager: KVTableViewManager!
    @IBOutlet var bodyKVTableViewManager: KVTableViewManager!
    @IBOutlet weak var headersTableView: UITableView!
    @IBOutlet weak var paramsTableView: UITableView!
    @IBOutlet weak var bodyTableView: UITableView!
    @IBOutlet weak var methodView: UIView!
    @IBOutlet weak var methodLabel: UILabel!
    @IBOutlet weak var urlLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var descLabel: UILabel!
    @IBOutlet weak var urlCell: UITableViewCell!
    @IBOutlet weak var nameCell: UITableViewCell!
    @IBOutlet weak var headerCell: UITableViewCell!
    @IBOutlet weak var paramCell: UITableViewCell!
    @IBOutlet weak var bodyCell: UITableViewCell!
    
    enum CellId: Int {
        case spaceAfterTop = 0
        case url = 1
        case spacerAfterUrl = 2
        case name = 3
        case headerTitle = 4
        case header = 5
        case paramTitle = 6
        case params = 7
        case bodyTitle = 8
        case body = 9
        case spacerAfterBody = 10
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.setCurrentScreen(.request)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Log.debug("request vc - did load")
        self.request = self.tabbarController.request
        self.initUI()
        self.updateData()
        self.reloadAllTableViews()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.view)
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.view.backgroundColor = App.Color.tableViewBg
        self.initHeadersTableViewManager()
        self.initParamsTableViewManager()
        self.initBodyTableViewManager()
        self.tableView.estimatedRowHeight = 44
        self.tableView.rowHeight = UITableView.automaticDimension
        self.addNavigationBarEditButton()
        // clear storyboard debug helpers
        [self.urlCell, self.nameCell, self.headerCell, self.paramCell, self.bodyCell].forEach { $0.borderColor = .clear }
        self.renderTheme()
    }
    
    /// Display Edit button in navigation bar
    func addNavigationBarEditButton() {
        self.tabbarController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .edit, target: self, action: #selector(self.editButtonDidTap(_:)))
    }
    
    func initHeadersTableViewManager() {
        self.headerKVTableViewManager.request = self.request
        self.headerKVTableViewManager.kvTableView = self.headersTableView
        //self.headerKVTableViewManager.delegate = self
        self.headerKVTableViewManager.tableViewType = .header
        self.headerKVTableViewManager.bootstrap()
        self.headerKVTableViewManager.reloadData()
    }
    
    func initParamsTableViewManager() {
        self.paramsKVTableViewManager.request = self.request
        self.paramsKVTableViewManager.kvTableView = self.paramsTableView
        //self.paramsKVTableViewManager.delegate = self
        self.paramsKVTableViewManager.tableViewType = .params
        self.paramsKVTableViewManager.bootstrap()
        self.paramsKVTableViewManager.reloadData()
    }
    
    func initBodyTableViewManager() {
        self.bodyKVTableViewManager.request = self.request
        self.bodyKVTableViewManager.kvTableView = self.bodyTableView
        //self.bodyKVTableViewManager.delegate = self
        self.bodyKVTableViewManager.tableViewType = .body
        self.bodyKVTableViewManager.bootstrap()
        self.bodyKVTableViewManager.reloadData()
    }
    
    func renderTheme() {
        self.methodView.backgroundColor = App.Color.requestMethodBg
    }
    
    func reloadAllTableViews() {
        self.tableView.reloadData()
    }
    
    @objc func editButtonDidTap(_ sender: Any) {
        Log.debug("edit button did tap")
    }
    
    func updateData() {
        Log.debug("request vc - \(String(describing: self.request))")
        guard let req = self.request, let proj = req.project else { return }
        if let method = self.localdb.getRequestMethodData(at: req.selectedMethodIndex.toInt(), projId: proj.getId()) {
            self.methodLabel.text = method.name
        } else {
            self.methodLabel.text = "GET"
        }
        self.urlLabel.text = req.url
        self.urlLabel.text = "https://example.com/api/image/2458C0A7-538A-4A4B-9788-971BD38934BD/olive/imCJHoKQhHRWStsT3MkGiPbg.jpg"
        self.nameLabel.text = req.name
        self.nameLabel.sizeToFit()
        self.descLabel.text = req.desc
        self.descLabel.text =
        """
        There's a place in my mind
        No one knows where it hides
        And my fantasy is flying
        It's a castle in the sky
        
        It's a world of our past
        Where the legend still lasts
        And the king wears the crown
        But the magic spell is law
        
        Take your sword and your shield
        There's a battle on the field
        You're a knight and you're right
        So with dragons now you'll fight
        
        And my fancy is flying
        It's a castle in the sky
        Or there's nothing out there
        These are castles in the air
        
        Fairytales live in me
        Fables coming from my memory
        Fantasy is not a crime
        Find your castle in the sky
        
        You've got the key
        Of the kingdom of the clouds
        Open the door
        Leaving back your doubts
        
        You've got the power
        To live another childhood
        So ride the wind
        That leads you to the moon 'cause...
        """
        self.descLabel.text = ""
        self.descLabel.sizeToFit()
//        self.urlTextField.text = req.url
//        self.nameTextField.text = req.name
//        if let x = req.desc, !x.isEmpty {
//            self.descTextView.text = x
//        } else {
//            self.descTextView.isHidden = true
//            self.descBorderView.isHidden = true
//        }
    }
}

// MARK: - Tableview delegates
extension RequestTableViewController {
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat!
        if indexPath.row == CellId.spaceAfterTop.rawValue {
            height = 12
        } else if indexPath.row == CellId.url.rawValue {
            height = 54
        } else if indexPath.row == CellId.spacerAfterUrl.rawValue {
            height = 12
        } else if indexPath.row == CellId.name.rawValue {
            let h = self.nameLabel.frame.size.height + self.descLabel.frame.size.height + 93.5
            height = h > 167 ? h : 167  // 167
//        } else if indexPath.row == CellId.spacerAfterName.rawValue {
//            height = 16
        } else if indexPath.row == CellId.headerTitle.rawValue {
            height = 44
        } else if indexPath.row == CellId.header.rawValue && indexPath.section == 0 {
            height = self.headerKVTableViewManager.getHeight()
//        } else if indexPath.row == CellId.spacerAfterHeader.rawValue {
//            height = 12
        } else if indexPath.row == CellId.paramTitle.rawValue {
            height = 44
        } else if indexPath.row == CellId.params.rawValue && indexPath.section == 0 {
            height = self.paramsKVTableViewManager.getHeight()
//        } else if indexPath.row == CellId.spacerAfterParams.rawValue {
//            height = 12
        } else if indexPath.row == CellId.bodyTitle.rawValue {
            height = 44
        } else if indexPath.row == CellId.body.rawValue && indexPath.section == 0 {
            if let body = AppState.editRequest?.body, !body.markForDelete, (body.selected == RequestBodyType.form.rawValue || body.selected == RequestBodyType.multipart.rawValue) {
                return RequestVC.bodyFormCellHeight()
            }
            if let body = AppState.editRequest?.body, !body.markForDelete, body.selected == RequestBodyType.binary.rawValue {
                return 60  // Only this one gets called.
            }
            height = self.bodyKVTableViewManager.getHeight()
        } else if indexPath.row == CellId.spacerAfterBody.rawValue {
            height = 12
        } else {
            height = UITableView.automaticDimension
        }
//        Log.debug("height: \(height) for index: \(indexPath)")
        return height
    }
}

class KVHeaderCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
}

class KVContentCell: UITableViewCell, KVContentCellType {
    
}

protocol KVContentCellType: class {
    
}

class KVBodyContentCell: UITableViewCell, KVContentCellType, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return UICollectionViewCell(frame: .zero)
    }
}

class KVBodyFieldTableViewCell: UITableViewCell, UITextFieldDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return UICollectionViewCell(frame: .zero)
    }
}

class KVBodyFieldTableView: UITableView, UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell(frame: .zero)
    }
}

// MARK: - Table view manager

class KVTableViewManager: NSObject, UITableViewDelegate, UITableViewDataSource {
    weak var kvTableView: UITableView?
    var tableViewType: KVTableViewType = .header
    weak var request: ERequest?
    
    func bootstrap() {
        
    }
    
    func getHeight() -> CGFloat {
        let height: CGFloat = 44
        return height
    }
    
    func reloadData() {
        self.kvTableView?.reloadData()
    }
    
    // MARK: - Table view delegate
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch self.tableViewType {
        case .header:
            return self.request?.headers?.count ?? 0
        case .params:
            return 0
            //return self.request?.params?.count ?? 0
        case .body:
            return 0
            //return self.request?.body == nil ? 0 : 1
        }
    }
    
    func getContentCellId() -> String {
        switch self.tableViewType {
        case .header:
            return "kvHeaderContentCell"
        case .params:
            return "kvParamsContentCell"
        case .body:
            return "bodyContentCell"
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell(frame: .zero)
    }
}
