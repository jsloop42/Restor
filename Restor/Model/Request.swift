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
    var selectedMethodIndex = 0
    var methods: [RequestMethodData] = []
    var headers: [RequestData] = []
    var params: [RequestData] = []
    var body: RequestBodyData?
    weak var project: Project?
    // Method names are case sensitive RFC 7230, 7231
    private let reqMethods = ["GET", "POST", "PUT", "OPTION", "DELETE"]
    
    init() {
        for i in self.reqMethods {
            self.methods.append(RequestMethodData(name: i, isCustom: false, project: self.project))
        }
    }
}

protocol RequestDataProtocol {
    func getKey() -> String
    func getValue() -> String
    func getFieldType() -> RequestBodyFormFieldType
    func setFieldType(_ type: RequestBodyFormFieldType)
}

class RequestData: RequestDataProtocol, Codable {
    var key: String
    var value: String
    var type: RequestBodyFormFieldType = .text
    var isEditing: Bool = false
    
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
    
    func getFieldType() -> RequestBodyFormFieldType {
        return self.type
    }
    
    func setFieldType(_ type: RequestBodyFormFieldType) {
        self.type = type
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

/// Form fields under request body
enum RequestBodyFormFieldType: Int, Codable {
    case text
    case file

    static var allCases: [String] {
        return ["Text", "File"]
    }
}

struct RequestMethodData: Codable {
    var name: String
    var isCustom = false
    weak var project: Project?
}
