//
//  EditRequestCoordinator.swift
//  Restor
//
//  Created by jsloop on 14/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class EANavigationController: UINavigationController {
    weak var docPickerVC: UIDocumentPickerViewController?
    
    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        if let vc = viewControllerToPresent as? UIDocumentPickerViewController {
            self.docPickerVC = vc
        }
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if self.docPickerVC == nil {
            super.dismiss(animated: flag, completion: completion)
        } else {
            
        }
    }
}

class EditRequestCoordinator: EACoordinator {
    let presenter: UINavigationController
    private let nc = NotificationCenter.default
    let request: ERequest
    private var navVC: EANavigationController!
    
    deinit {
        self.nc.removeObserver(self)
    }
    
    init(presenter: UINavigationController, request: ERequest) {
        self.presenter = presenter
        self.request = request
        if let vc = UIStoryboard.editRequestVC {
            self.navVC = EANavigationController(rootViewController: vc)
        }
        self.initEvents()
    }
    
    func initEvents() {
        
    }
    
    func start() {
        DispatchQueue.main.async {
            if let navVC = self.navVC {
                AppState.editRequest = self.request  // TODO: change global state
                // self.presenter.pushViewController(vc, animated: true)
                navVC.setNavigationBarHidden(true, animated: false)
                self.presenter.present(navVC, animated: true, completion: nil)
            }
        }
    }
}
