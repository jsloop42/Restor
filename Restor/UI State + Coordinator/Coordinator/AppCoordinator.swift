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
    var window: UIWindow?
    let rootVC: UINavigationController
    let fsm: EAUIStateMachine
    let nc = NotificationCenter.default
    let app = App.shared
    var isInitEvents = false
    
    init() {
        self.rootVC = UINavigationController()
        self.fsm = EAUIStateMachine(presenter: self.rootVC, states: [ProjectListState(), WorkspaceListState(), RequestListState(), RequestState(),
                                                                     EditRequestState()])
    }
    
    init(window: UIWindow) {
        self.window = window
        self.rootVC = UINavigationController()
        self.fsm = EAUIStateMachine(presenter: self.rootVC, states: [ProjectListState(), WorkspaceListState(), RequestListState(), RequestState(),
                                                                     EditRequestState()])
        self.initUI()
        self.initEvents()
    }
    
    func initUI() {
        self.app.updateViewBackground(self.rootVC.view)
        self.app.updateNavigationControllerBackground(self.rootVC)
        self.window?.rootViewController?.modalPresentationStyle = .overCurrentContext
    }
    
    func start() {
        self.fsm.enter(ProjectListState.self)
        self.window?.rootViewController = self.rootVC
        //self.window?.makeKeyAndVisible()
        self.initEvents()
    }
    
    func initEvents() {
        if !self.isInitEvents {
            self.nc.addObserver(self, selector: #selector(self.workspaceVCShouldPresent(_:)), name: .workspaceVCShouldPresent, object: nil)
            self.nc.addObserver(self, selector: #selector(self.requestListVCShouldPresent(_:)), name: .requestListVCShouldPresent, object: nil)
            self.nc.addObserver(self, selector: #selector(self.requestVCShouldPresent(_:)), name: .requestVCShouldPresent, object: nil)
            self.nc.addObserver(self, selector: #selector(self.editRequestVCShouldPresent(_:)), name: .editRequestVCShouldPresent, object: nil)
            self.nc.addObserver(self, selector: #selector(self.didNavigateBackToProjectListVC(_:)), name: .workspaceWillClose, object: nil)
            self.nc.addObserver(self, selector: #selector(self.didNavigateBackToProjectListVC(_:)), name: Notification.Name("did-navigate-back-to-ProjectListViewController"), object: nil)
            self.nc.addObserver(self, selector: #selector(self.didNavigateBackToRequestListVC(_:)), name: Notification.Name("did-navigate-back-to-RequestListViewController"), object: nil)
            self.nc.addObserver(self, selector: #selector(self.didNavigateBackToRequestVC(_:)), name: Notification.Name("did-navigate-back-to-RequestTableViewController"), object: nil)
            self.isInitEvents = true
        }
    }
    
    @objc func workspaceVCShouldPresent(_ notif: Notification) {
        Log.debug("workspace vc should present")
        self.fsm.enter(WorkspaceListState.self)
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

    func editRequestVCShouldPresent(request: ERequest) {
        DispatchQueue.main.async {
            guard let state = self.fsm.state(forClass: EditRequestState.self) else { return }
            state.request = request
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
