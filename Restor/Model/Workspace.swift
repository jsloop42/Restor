//
//  Workspace.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation

class Workspace {
    var name: String
    var desc: String
    var projects: [Project] = []
    
    init(name: String, desc: String) {
        self.name = name
        self.desc = desc
    }
    
    convenience init(name: String) {
        self.init(name: name, desc: "")
    }
}
