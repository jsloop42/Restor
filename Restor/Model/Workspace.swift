//
//  Workspace.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation

class Workspace {
    var created: Int64
    var desc: String
    var id: String
    var name: String
    var modified: Int64
    var projects: [Project] = []
    var version: Int64
    
    init(name: String, desc: String) {
        self.name = name
        self.desc = desc
        self.created = Date().currentTimeMillis()
        self.id = Utils.shared.genRandomString()
        self.modified = self.created
        self.version = 0
    }
    
    convenience init(name: String) {
        self.init(name: name, desc: "")
    }
}
