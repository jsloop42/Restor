//
//  EAUIStateMachine.swift
//  Restor
//
//  Created by jsloop on 13/05/20.
//  Copyright © 2020 EstoApps OÜ. All rights reserved.
//

import Foundation
import GameplayKit

class EAUIStateMachine: GKStateMachine {
    let presenter: UINavigationController
    
    init(presenter: UINavigationController, states: [GKState]) {
        self.presenter = presenter
        super.init(states: states)
    }
    
    override var debugDescription: String {
        return
            """
            \(type(of: self)) \(Unmanaged.passUnretained(self).toOpaque())
            current state: \(String(describing: self.currentState))
            """
    }
}
