//
//  RequestStates.swift
//  Restor
//
//  Created by jsloop on 16/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import GameplayKit

/// User has tapped the Go button and the request is being processed for sending.
class RequestPrepareState: GKState {
    unowned var request: ERequest
    
    init(_ request: ERequest) {
        self.request = request
        super.init()
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass == RequestSendState.self || stateClass == RequestCancelState.self
    }
    
    override func didEnter(from previousState: GKState?) {
        Log.debug("[state] did enter - request prepare")
        guard let fsm = self.stateMachine as? RequestStateMachine, let man = fsm.manager else { return }
        man.prepareRequest()
    }
}

/// The request has be constructed and has been send to the server, and waiting for response.
class RequestSendState: GKState {
    unowned var request: ERequest
    var urlReq: URLRequest?
    
    init(_ request: ERequest) {
        self.request = request
        super.init()
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass == RequestResponseState.self || stateClass == RequestCancelState.self
    }
    
    override func didEnter(from previousState: GKState?) {
        Log.debug("[state] did enter - request send")
        guard let fsm = self.stateMachine as? RequestStateMachine, let man = fsm.manager, let urlReq = self.urlReq else { return }
        man.sendRequest(urlReq)
    }
}

/// The response has been obtained.
class RequestResponseState: GKState {
    unowned var request: ERequest
    var data: Data?
    var response: HTTPURLResponse?
    var error: Error?
    let nc = NotificationCenter.default
    var result: Result<(Data, HTTPURLResponse), Error>?
    var success: Bool = false
    
    init(_ request: ERequest) {
        self.request = request
        super.init()
    }
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return false
    }
    
    override func didEnter(from previousState: GKState?) {
        Log.debug("[state] did enter - request response")
        guard let fsm = self.stateMachine as? RequestStateMachine, let man = fsm.manager, let result = self.result else { return }
        man.responseDidObtain(result)
    }
}

class RequestCancelState: GKState {
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return false
    }
    
    override func didEnter(from previousState: GKState?) {
        Log.debug("[req-state] did enter - request cancel state")
        guard let fsm = self.stateMachine as? RequestStateMachine, let man = fsm.manager else { return }
        man.requestDidCancel()
    }
}
