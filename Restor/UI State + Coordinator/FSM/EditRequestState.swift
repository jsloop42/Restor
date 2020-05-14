//
//  EditRequestState.swift
//  Restor
//
//  Created by jsloop on 14/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import GameplayKit

class EditRequestState: GKState {
    var coord: EditRequestCoordinator?
    var request: ERequest?
    
    override func isValidNextState(_ stateClass: AnyClass) -> Bool {
        return stateClass == RequestState.self
    }
    
    override func didEnter(from previousState: GKState?) {
        Log.debug("[state] did enter - request")
        if previousState?.classForCoder == RequestState.self {
            guard let fsm = self.stateMachine as? EAUIStateMachine else { return }
            guard let req = self.request else { return }
            self.coord = EditRequestCoordinator(presenter: fsm.presenter, request: req)
            self.coord?.start()
        }
    }
    
    override func willExit(to nextState: GKState) {
        Log.debug("[state] will exit - request")
    }
}
