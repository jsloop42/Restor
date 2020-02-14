//
//  Request.swift
//  Restor
//
//  Created by jsloop on 05/12/19.
//  Copyright © 2019 EstoApps. All rights reserved.
//

import Foundation

class Request: Codable {
    var name: String = ""
    var desc: String = ""
    var tags: [String] = []
    var url: String = ""
    var method: String = RequestMethod.get.rawValue
    var headers: [RequestData] = []
    var params: [RequestData] = []
    var body: RequestBodyData?
    weak var project: Project?
    
    init() {}
}

enum RequestMethod: String, Codable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case option = "OPTION"
    case delete = "DELETE"
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
    var selected: Int = RequestBodyType.json.rawValue
}

enum RequestBodyType: Int, Codable {
    case json
    case xml
    case raw
    case form
    case multipart
    case binary
}
