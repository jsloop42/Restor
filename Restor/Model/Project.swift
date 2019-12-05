//
//  Project.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation

class Project: Codable {
    var name: String
    weak var workspace: Workspace?
    var requests: [Request] = []
}
