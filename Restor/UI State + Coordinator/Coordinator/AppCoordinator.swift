//
//  AppCoordinator.swift
//  Restor
//
//  Created by jsloop on 13/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import UIKit

class AppCoordinator: EACoordinator {
    let window: UIWindow
    let rootVC: UINavigationController
    let fsm: EAUIStateMachine
    let nc = NotificationCenter.default
    
    init(window: UIWindow) {
        self.window = window
        //self.rootVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: StoryboardId.rootNav.rawValue) as! UINavigationController
        self.rootVC = UINavigationController()
        self.fsm = EAUIStateMachine(presenter: self.rootVC, states: [ProjectListState(), WorkspaceListState(), RequestListState(), RequestState(),
                                                                     EditRequestState()])
        self.initEvents()
    }
    
    func start() {
        self.fsm.enter(ProjectListState.self)
        self.window.rootViewController = self.rootVC
        self.window.makeKeyAndVisible()
        self.initEvents()
    }
    
    func initEvents() {
        self.nc.addObserver(self, selector: #selector(self.requestListVCShouldPresent(_:)), name: .requestListVCShouldPresent, object: nil)
        self.nc.addObserver(self, selector: #selector(self.requestVCShouldPresent(_:)), name: .requestVCShouldPresent, object: nil)
        self.nc.addObserver(self, selector: #selector(self.editRequestVCShouldPresent(_:)), name: .editRequestVCShouldPresent, object: nil)
        // TODO: move notif name to enum
        self.nc.addObserver(self, selector: #selector(self.didNavigateBackToProjectListVC(_:)), name: Notification.Name("did-navigate-back-to-ProjectListViewController"), object: nil)
        self.nc.addObserver(self, selector: #selector(self.didNavigateBackToRequestListVC(_:)), name: Notification.Name("did-navigate-back-to-RequestListViewController"), object: nil)
        self.nc.addObserver(self, selector: #selector(self.didNavigateBackToRequestVC(_:)), name: Notification.Name("did-navigate-back-to-RequestTableViewController"), object: nil)
    }
        
    @objc func requestListVCShouldPresent(_ notif: Notification) {
        Log.debug("request list vc should present notif")
        if let info = notif.userInfo, let proj = info["project"] as? EProject {
            guard let state = self.fsm.state(forClass: RequestListState.self) else { return }
            state.project = proj
            self.fsm.enter(RequestListState.self)
        }
    }
    
    @objc func requestVCShouldPresent(_ notif: Notification) {
        Log.debug("request vc should present notif")
        if let info = notif.userInfo, let req = info["request"] as? ERequest {
            guard let state = self.fsm.state(forClass: RequestState.self) else { return }
            state.request = req
            self.fsm.enter(RequestState.self)
        }
    }
    
    @objc func editRequestVCShouldPresent(_ notif: Notification) {
        Log.debug("edit request vc should present notif")
        if let info = notif.userInfo, let req = info["request"] as? ERequest {
            guard let state = self.fsm.state(forClass: EditRequestState.self) else { return }
            state.request = req
            self.fsm.enter(EditRequestState.self)
        }
    }
    
    @objc func didNavigateBackToProjectListVC(_ notif: Notification) {
        Log.debug("did navigated to project list vc")
        self.fsm.enter(ProjectListState.self)
    }
    
    @objc func didNavigateBackToRequestListVC(_ notif: Notification) {
        Log.debug("did navigated to request list vc")
        self.fsm.enter(RequestListState.self)
    }
    
    @objc func didNavigateBackToRequestVC(_ notif: Notification) {
        Log.debug("did navigated to request vc")
        self.fsm.enter(RequestState.self)
    }
}
