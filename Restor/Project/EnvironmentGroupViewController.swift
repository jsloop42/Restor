//
//  EnvironmentGroupViewController.swift
//  Restor
//
//  Created by jsloop on 19/03/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class EnvironmentGroupViewController: UIViewController {
    private let app = App.shared
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AppState.setCurrentScreen(.envGroup)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.initUI()
    }
    
    func initUI() {
        self.app.updateNavigationControllerBackground(self.navigationController)
        self.app.updateViewBackground(self.view)
        self.view.backgroundColor = App.Color.tableViewBg
        self.navigationItem.title = "Environment Group"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(self.addBtnDidTap(_:)))
    }
    
    @objc func addBtnDidTap(_ sender: Any) {
        Log.debug("add button did tap")
    }
}
