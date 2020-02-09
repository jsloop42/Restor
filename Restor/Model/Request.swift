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
    var headers: [RequestData] = []
    var body: Data?
    weak var project: Project?
}

protocol RequestDataProtocol {
    func getKey() -> String
    func getValue() -> String
}

class RequestData: RequestDataProtocol, Codable {
    var key: String
    var value: String
    
    init() {
        key = ""
        value = ""
    }
    
    init(key: String, value: String) {
        self.key = key
        self.value = value
    }
    
    func getKey() -> String {
        return key
    }
    
    func getValue() -> String {
        return value
    }
}

class RequestBodyData: Codable {
    var json: String?
    var xml: String?
    var raw: String?
    var form: [RequestData] = []
    var multipart: [RequestData] = []
    var binary: String?
    var selected: Int = 0
}
