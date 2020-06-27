//
//  Project.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation

class Project: CustomDebugStringConvertible {
    var created: Int64
    var desc: String = ""
    var id: String
    var name: String
    var modified: Int64
    weak var workspace: Workspace?
    var requests: [Request] = []
    var version: Int64
    var requestMethods: [RequestMethodData] = []
    
    init(name: String, desc: String, workspace: Workspace) {
        self.name = name
        self.desc = desc
        self.id = Utils.shared.genRandomString()
        self.workspace = workspace
        self.created = Date().currentTimeMillis()
        self.modified = self.created
        self.version = 0
    }
    
    var debugDescription: String {
        return
            """
            \(type(of: self)) \(Unmanaged.passUnretained(self).toOpaque())
            name: \(name)
            desc: \(desc)
            id: \(id)
            workspace name: \(self.workspace?.name ?? "")
            requests count: \(requests.count)
            """
    }
}
