//
//  Project.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation

class Project {
    var name: String
    var desc: String = ""
    weak var workspace: Workspace?
    var requests: [Request] = []
    
    init(name: String, desc: String, workspace: Workspace) {
        self.name = name
        self.desc = desc
        self.workspace = workspace
    }
}
