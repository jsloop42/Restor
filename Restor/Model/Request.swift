//
//  Request.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation

class Request: Codable {
    var name: String
    var desc: String
    var tags: [String] = []
    var url: String
    var method: String
    var headers: [String: String] = [:]
    var body: Data?
    weak var project: Project?
}
