//
//  RequestListCoordinator.swift
//  Restor
//
//  Created by jsloop on 13/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class RequestListCoordinator: EACoordinator {
    let presenter: UINavigationController
    private let nc = NotificationCenter.default
    let project: EProject
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    init(presenter: UINavigationController, project: EProject) {
        self.presenter = presenter
        self.project = project
        self.initEvents()
    }
    
    func initEvents() {
        
    }
    
    func start() {
        DispatchQueue.main.async {
            if let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: StoryboardId.requestListVC.rawValue) as? RequestListViewController {
                vc.project = self.project
                self.presenter.pushViewController(vc, animated: true)
            }
        }
    }
}
